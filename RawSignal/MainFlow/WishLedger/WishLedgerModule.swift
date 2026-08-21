import SwiftUI
import UIKit

enum WishLedgerModels {
    enum FetchLedger {
        struct Request {}
        struct Row: Equatable {
            var identifier: String
            var title: String
            var sku: String
        }
        struct Response {
            var items: [WishLedgerItem]
            var preferences: PreferenceConfigurationSnapshot
        }
        struct ViewModel {
            var rows: [Row]
            var isEmpty: Bool
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum DeleteItem {
        struct Request { var identifier: String }
    }

    enum OpenItem {
        struct Request { var identifier: String }
        struct Response { var opened: Bool }
        struct ViewModel { var shouldOpenDetail: Bool }
    }
}

@MainActor
protocol WishLedgerBusinessLogic {
    func fetchLedger(request: WishLedgerModels.FetchLedger.Request)
    func deleteItem(request: WishLedgerModels.DeleteItem.Request)
    func openItem(request: WishLedgerModels.OpenItem.Request)
}

@MainActor
protocol WishLedgerPresentationLogic: AnyObject {
    func presentLedger(response: WishLedgerModels.FetchLedger.Response)
    func presentOpen(response: WishLedgerModels.OpenItem.Response)
}

@MainActor
final class WishLedgerInteractor: WishLedgerBusinessLogic {
    var presenter: WishLedgerPresentationLogic?
    var vault: SignalVaultPersisting
    var pipeline: SignalSessionPipeline

    init(vault: SignalVaultPersisting, pipeline: SignalSessionPipeline) {
        self.vault = vault
        self.pipeline = pipeline
    }

    func fetchLedger(request: WishLedgerModels.FetchLedger.Request) {
        let envelope = vault.loadEnvelope()
        presenter?.presentLedger(response: .init(items: envelope.wishLedger, preferences: envelope.preferences))
    }

    func deleteItem(request: WishLedgerModels.DeleteItem.Request) {
        var envelope = vault.loadEnvelope()
        envelope.wishLedger.removeAll { $0.identifier == request.identifier }
        vault.persistEnvelope(envelope)
        presenter?.presentLedger(response: .init(items: envelope.wishLedger, preferences: envelope.preferences))
    }

    func openItem(request: WishLedgerModels.OpenItem.Request) {
        let envelope = vault.loadEnvelope()
        guard let item = envelope.wishLedger.first(where: { $0.identifier == request.identifier }) else {
            presenter?.presentOpen(response: .init(opened: false))
            return
        }
        pipeline.pendingMerchandise = item.merchandise
        pipeline.pendingServingGrams = item.merchandise.defaultServingGrams
        presenter?.presentOpen(response: .init(opened: true))
    }
}

final class WishLedgerPresenter: WishLedgerPresentationLogic {
    weak var display: WishLedgerDisplayLogic?

    func presentLedger(response: WishLedgerModels.FetchLedger.Response) {
        let rows = response.items.map {
            WishLedgerModels.FetchLedger.Row(identifier: $0.identifier, title: $0.merchandise.displayTitle, sku: $0.stockKeepingUnit)
        }
        display?.displayLedger(viewModel: .init(rows: rows, isEmpty: rows.isEmpty, preferences: response.preferences))
    }

    func presentOpen(response: WishLedgerModels.OpenItem.Response) {
        display?.displayOpen(viewModel: .init(shouldOpenDetail: response.opened))
    }
}

@MainActor
protocol WishLedgerDisplayLogic: AnyObject {
    func displayLedger(viewModel: WishLedgerModels.FetchLedger.ViewModel)
    func displayOpen(viewModel: WishLedgerModels.OpenItem.ViewModel)
}

@MainActor
final class WishLedgerObservableStore: ObservableObject, WishLedgerDisplayLogic {
    @Published var viewModel: WishLedgerModels.FetchLedger.ViewModel?
    var interactor: WishLedgerBusinessLogic?
    var router: SignalFlowRouting?

    func displayLedger(viewModel: WishLedgerModels.FetchLedger.ViewModel) {
        self.viewModel = viewModel
    }

    func displayOpen(viewModel: WishLedgerModels.OpenItem.ViewModel) {
        if viewModel.shouldOpenDetail {
            router?.route(to: .productDetail)
        }
    }
}

struct WishLedgerView: View {
    @ObservedObject var store: WishLedgerObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        let preferences = store.viewModel?.preferences ?? .factoryDefault()
        BrutalistScreenScaffold(title: "WISH LEDGER", backTitle: "BACK", onBack: {
            store.router?.route(to: .dailyIntake)
        }) {
            if let viewModel = store.viewModel {
                if viewModel.isEmpty {
                    BrutalistEmptyState(assetName: "EmptyWishLedger", caption: "WISH LEDGER IS BLANK")
                } else {
                    List {
                        ForEach(viewModel.rows, id: \.identifier) { row in
                            Button {
                                store.interactor?.openItem(request: .init(identifier: row.identifier))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.title)
                                        .font(.plexMono(density.bodySize, weight: .bold))
                                    Text(row.sku)
                                        .font(.plexMono(density.captionSize))
                                }
                                .foregroundStyle(theme.ink)
                            }
                            .listRowBackground(theme.panel)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.interactor?.deleteItem(request: .init(identifier: viewModel.rows[index].identifier))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .applyingVaultAppearance(preferences)
        .onAppear {
            store.interactor?.fetchLedger(request: .init())
        }
    }
}

final class WishLedgerScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let factory = SignalDependencyFactory.shared
        let store = WishLedgerObservableStore()
        let interactor = WishLedgerInteractor(vault: factory.vault, pipeline: factory.pipeline)
        let presenter = WishLedgerPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: WishLedgerView(store: store))
    }
}
