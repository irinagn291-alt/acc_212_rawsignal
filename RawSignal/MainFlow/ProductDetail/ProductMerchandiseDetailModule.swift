import SwiftUI
import UIKit

enum ProductMerchandiseDetailModels {
    enum FetchPending {
        struct Request {}
        struct Response {
            var merchandise: CatalogMerchandiseRecord?
            var servingGrams: Double
            var preferences: PreferenceConfigurationSnapshot
        }
        struct ViewModel {
            var title: String
            var brand: String
            var sku: String
            var perHundred: String
            var portion: String
            var servingText: String
            var artworkAssetName: String
            var servingGrams: Double
            var preferences: PreferenceConfigurationSnapshot
            var missing: Bool
        }
    }

    enum AdjustServing {
        struct Request { var servingGrams: Double }
        struct Response {
            var merchandise: CatalogMerchandiseRecord
            var servingGrams: Double
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum QueueWish {
        struct Request {}
        struct Response { var alreadyPresent: Bool }
        struct ViewModel { var caption: String }
    }
}

@MainActor
protocol ProductMerchandiseDetailBusinessLogic {
    func fetchPending(request: ProductMerchandiseDetailModels.FetchPending.Request)
    func adjustServing(request: ProductMerchandiseDetailModels.AdjustServing.Request)
    func queueWish(request: ProductMerchandiseDetailModels.QueueWish.Request)
}

@MainActor
protocol ProductMerchandiseDetailPresentationLogic: AnyObject {
    func presentPending(response: ProductMerchandiseDetailModels.FetchPending.Response)
    func presentAdjusted(response: ProductMerchandiseDetailModels.AdjustServing.Response)
    func presentWish(response: ProductMerchandiseDetailModels.QueueWish.Response)
}

@MainActor
final class ProductMerchandiseDetailInteractor: ProductMerchandiseDetailBusinessLogic {
    var presenter: ProductMerchandiseDetailPresentationLogic?
    var vault: SignalVaultPersisting
    var pipeline: SignalSessionPipeline

    init(vault: SignalVaultPersisting, pipeline: SignalSessionPipeline) {
        self.vault = vault
        self.pipeline = pipeline
    }

    func fetchPending(request: ProductMerchandiseDetailModels.FetchPending.Request) {
        presenter?.presentPending(
            response: .init(
                merchandise: pipeline.pendingMerchandise,
                servingGrams: pipeline.pendingServingGrams,
                preferences: vault.loadEnvelope().preferences
            )
        )
    }

    func adjustServing(request: ProductMerchandiseDetailModels.AdjustServing.Request) {
        guard let merchandise = pipeline.pendingMerchandise else { return }
        pipeline.pendingServingGrams = max(1, request.servingGrams)
        presenter?.presentAdjusted(
            response: .init(
                merchandise: merchandise,
                servingGrams: pipeline.pendingServingGrams,
                preferences: vault.loadEnvelope().preferences
            )
        )
    }

    func queueWish(request: ProductMerchandiseDetailModels.QueueWish.Request) {
        guard let merchandise = pipeline.pendingMerchandise else { return }
        var envelope = vault.loadEnvelope()
        if envelope.wishLedger.contains(where: { $0.stockKeepingUnit == merchandise.stockKeepingUnit }) {
            presenter?.presentWish(response: .init(alreadyPresent: true))
            return
        }
        envelope.wishLedger.append(
            WishLedgerItem(
                identifier: UUID().uuidString,
                stockKeepingUnit: merchandise.stockKeepingUnit,
                merchandise: merchandise
            )
        )
        vault.persistEnvelope(envelope)
        presenter?.presentWish(response: .init(alreadyPresent: false))
    }
}

final class ProductMerchandiseDetailPresenter: ProductMerchandiseDetailPresentationLogic {
    weak var display: ProductMerchandiseDetailDisplayLogic?

    func presentPending(response: ProductMerchandiseDetailModels.FetchPending.Response) {
        display?.displayPending(viewModel: map(merchandise: response.merchandise, grams: response.servingGrams, preferences: response.preferences))
    }

    func presentAdjusted(response: ProductMerchandiseDetailModels.AdjustServing.Response) {
        display?.displayPending(viewModel: map(merchandise: response.merchandise, grams: response.servingGrams, preferences: response.preferences))
    }

    func presentWish(response: ProductMerchandiseDetailModels.QueueWish.Response) {
        display?.displayWish(viewModel: .init(caption: response.alreadyPresent ? "SKU ALREADY IN WISH" : "WISH LOCKED"))
    }

    private func map(
        merchandise: CatalogMerchandiseRecord?,
        grams: Double,
        preferences: PreferenceConfigurationSnapshot
    ) -> ProductMerchandiseDetailModels.FetchPending.ViewModel {
        guard let merchandise else {
            return .init(
                title: "NO SIGNAL",
                brand: "",
                sku: "",
                perHundred: "",
                portion: "",
                servingText: "",
                artworkAssetName: "ChromeRawFrame",
                servingGrams: 100,
                preferences: preferences,
                missing: true
            )
        }
        let portion = NutrientPortionCalculator.scaledEnvelope(
            perHundredGrams: merchandise.perHundredEnvelope,
            servingGrams: grams
        )
        return .init(
            title: merchandise.displayTitle,
            brand: merchandise.brandLine,
            sku: merchandise.stockKeepingUnit,
            perHundred: String(
                format: "100g  %.0f KCAL  P%.1f C%.1f F%.1f",
                merchandise.energyPerHundredGrams,
                merchandise.proteinPerHundredGrams,
                merchandise.carbohydratePerHundredGrams,
                merchandise.lipidPerHundredGrams
            ),
            portion: String(
                format: "PORTION  %.0f KCAL  P%.1f C%.1f F%.1f",
                portion.kilocalories,
                portion.proteinGrams,
                portion.carbohydrateGrams,
                portion.lipidGrams
            ),
            servingText: String(format: "%.0f G", grams),
            artworkAssetName: merchandise.artworkAssetName ?? "ChromeRawFrame",
            servingGrams: grams,
            preferences: preferences,
            missing: false
        )
    }
}

@MainActor
protocol ProductMerchandiseDetailDisplayLogic: AnyObject {
    func displayPending(viewModel: ProductMerchandiseDetailModels.FetchPending.ViewModel)
    func displayWish(viewModel: ProductMerchandiseDetailModels.QueueWish.ViewModel)
}

@MainActor
final class ProductMerchandiseDetailObservableStore: ObservableObject, ProductMerchandiseDetailDisplayLogic {
    @Published var viewModel: ProductMerchandiseDetailModels.FetchPending.ViewModel?
    @Published var wishCaption = ""
    var interactor: ProductMerchandiseDetailBusinessLogic?
    var router: SignalFlowRouting?

    func displayPending(viewModel: ProductMerchandiseDetailModels.FetchPending.ViewModel) {
        self.viewModel = viewModel
    }

    func displayWish(viewModel: ProductMerchandiseDetailModels.QueueWish.ViewModel) {
        wishCaption = viewModel.caption
    }
}

struct ProductMerchandiseDetailView: View {
    @ObservedObject var store: ProductMerchandiseDetailObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        let preferences = store.viewModel?.preferences ?? .factoryDefault()
        BrutalistScreenScaffold(title: "MERCH CARD", backTitle: "BACK", onBack: {
            store.router?.route(to: .catalogSearch)
        }) {
            if let viewModel = store.viewModel {
                Image(viewModel.artworkAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
                Text(viewModel.title)
                    .font(.plexMono(density.titleSize, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(viewModel.brand)
                    .font(.plexMono(density.captionSize))
                    .foregroundStyle(theme.muted)
                Text(viewModel.sku)
                    .font(.plexMono(density.captionSize, weight: .medium))
                    .foregroundStyle(theme.accent)
                Text(viewModel.perHundred)
                    .font(.plexMono(density.captionSize))
                    .foregroundStyle(theme.ink)
                Text(viewModel.portion)
                    .font(.plexMono(density.bodySize, weight: .bold))
                    .foregroundStyle(theme.accent)
                HStack {
                    BrutalistPanelButton(title: "-10G") {
                        store.interactor?.adjustServing(request: .init(servingGrams: viewModel.servingGrams - 10))
                    }
                    Text(viewModel.servingText)
                        .font(.plexMono(density.bodySize, weight: .bold))
                        .foregroundStyle(theme.ink)
                    BrutalistPanelButton(title: "+10G") {
                        store.interactor?.adjustServing(request: .init(servingGrams: viewModel.servingGrams + 10))
                    }
                }
                if !store.wishCaption.isEmpty {
                    Text(store.wishCaption)
                        .font(.plexMono(density.captionSize))
                        .foregroundStyle(theme.accent)
                }
                BrutalistPanelButton(title: "WISH SKU") {
                    store.interactor?.queueWish(request: .init())
                }
                BrutalistPanelButton(title: "ASSIGN LANE", emphasized: true) {
                    store.router?.route(to: .slotAssignment)
                }
            }
        }
        .applyingVaultAppearance(preferences)
        .onAppear {
            store.interactor?.fetchPending(request: .init())
        }
    }
}

final class ProductMerchandiseDetailScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let factory = SignalDependencyFactory.shared
        let store = ProductMerchandiseDetailObservableStore()
        let interactor = ProductMerchandiseDetailInteractor(vault: factory.vault, pipeline: factory.pipeline)
        let presenter = ProductMerchandiseDetailPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: ProductMerchandiseDetailView(store: store))
    }
}
