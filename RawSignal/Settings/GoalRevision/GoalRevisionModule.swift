import SwiftUI
import UIKit

enum GoalRevisionModels {
    enum FetchGoals {
        struct Request {}
        struct Response { var preferences: PreferenceConfigurationSnapshot }
        struct ViewModel {
            var energy: String
            var protein: String
            var carbohydrate: String
            var lipid: String
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum PersistGoals {
        struct Request {
            var energy: String
            var protein: String
            var carbohydrate: String
            var lipid: String
        }
        struct Response { var preferences: PreferenceConfigurationSnapshot; var rejected: Bool }
        struct ViewModel { var caption: String; var preferences: PreferenceConfigurationSnapshot }
    }
}

@MainActor
protocol GoalRevisionBusinessLogic {
    func fetchGoals(request: GoalRevisionModels.FetchGoals.Request)
    func persistGoals(request: GoalRevisionModels.PersistGoals.Request)
}

@MainActor
protocol GoalRevisionPresentationLogic: AnyObject {
    func presentGoals(response: GoalRevisionModels.FetchGoals.Response)
    func presentPersist(response: GoalRevisionModels.PersistGoals.Response)
}

final class GoalRevisionInteractor: GoalRevisionBusinessLogic {
    var presenter: GoalRevisionPresentationLogic?
    var vault: SignalVaultPersisting

    init(vault: SignalVaultPersisting) {
        self.vault = vault
    }

    func fetchGoals(request: GoalRevisionModels.FetchGoals.Request) {
        presenter?.presentGoals(response: .init(preferences: vault.loadEnvelope().preferences))
    }

    func persistGoals(request: GoalRevisionModels.PersistGoals.Request) {
        guard let energy = Double(request.energy), energy > 0,
              let protein = Double(request.protein), protein >= 0,
              let carbs = Double(request.carbohydrate), carbs >= 0,
              let fat = Double(request.lipid), fat >= 0 else {
            presenter?.presentPersist(response: .init(preferences: vault.loadEnvelope().preferences, rejected: true))
            return
        }
        var envelope = vault.loadEnvelope()
        envelope.preferences.dailyTargets = NutrientMagnitudeEnvelope(
            kilocalories: energy,
            proteinGrams: protein,
            carbohydrateGrams: carbs,
            lipidGrams: fat
        )
        vault.persistEnvelope(envelope)
        presenter?.presentPersist(response: .init(preferences: envelope.preferences, rejected: false))
    }
}

final class GoalRevisionPresenter: GoalRevisionPresentationLogic {
    weak var display: GoalRevisionDisplayLogic?

    func presentGoals(response: GoalRevisionModels.FetchGoals.Response) {
        let targets = response.preferences.dailyTargets
        display?.displayGoals(
            viewModel: .init(
                energy: String(format: "%.0f", targets.kilocalories),
                protein: String(format: "%.0f", targets.proteinGrams),
                carbohydrate: String(format: "%.0f", targets.carbohydrateGrams),
                lipid: String(format: "%.0f", targets.lipidGrams),
                preferences: response.preferences
            )
        )
    }

    func presentPersist(response: GoalRevisionModels.PersistGoals.Response) {
        let targets = response.preferences.dailyTargets
        display?.displayPersist(
            viewModel: .init(
                caption: response.rejected ? "REJECTED INPUT" : "TARGETS WRITTEN",
                preferences: response.preferences
            )
        )
        if !response.rejected {
            display?.displayGoals(
                viewModel: .init(
                    energy: String(format: "%.0f", targets.kilocalories),
                    protein: String(format: "%.0f", targets.proteinGrams),
                    carbohydrate: String(format: "%.0f", targets.carbohydrateGrams),
                    lipid: String(format: "%.0f", targets.lipidGrams),
                    preferences: response.preferences
                )
            )
        }
    }
}

@MainActor
protocol GoalRevisionDisplayLogic: AnyObject {
    func displayGoals(viewModel: GoalRevisionModels.FetchGoals.ViewModel)
    func displayPersist(viewModel: GoalRevisionModels.PersistGoals.ViewModel)
}

@MainActor
final class GoalRevisionObservableStore: ObservableObject, GoalRevisionDisplayLogic {
    @Published var energy = ""
    @Published var protein = ""
    @Published var carbohydrate = ""
    @Published var lipid = ""
    @Published var caption = ""
    @Published var preferences = PreferenceConfigurationSnapshot.factoryDefault()
    var interactor: GoalRevisionBusinessLogic?
    var router: SignalFlowRouting?

    func displayGoals(viewModel: GoalRevisionModels.FetchGoals.ViewModel) {
        energy = viewModel.energy
        protein = viewModel.protein
        carbohydrate = viewModel.carbohydrate
        lipid = viewModel.lipid
        preferences = viewModel.preferences
    }

    func displayPersist(viewModel: GoalRevisionModels.PersistGoals.ViewModel) {
        caption = viewModel.caption
        preferences = viewModel.preferences
    }
}

struct GoalRevisionView: View {
    @ObservedObject var store: GoalRevisionObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        BrutalistScreenScaffold(title: "GOAL REVISION", backTitle: "BACK", onBack: {
            store.router?.route(to: .dailyIntake)
        }) {
            BrutalistField(placeholder: "KCAL", text: $store.energy)
                .keyboardType(.decimalPad)
            BrutalistField(placeholder: "PROTEIN G", text: $store.protein)
                .keyboardType(.decimalPad)
            BrutalistField(placeholder: "CARB G", text: $store.carbohydrate)
                .keyboardType(.decimalPad)
            BrutalistField(placeholder: "FAT G", text: $store.lipid)
                .keyboardType(.decimalPad)
            if !store.caption.isEmpty {
                Text(store.caption)
                    .font(.plexMono(density.captionSize, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            BrutalistPanelButton(title: "WRITE TARGETS", emphasized: true) {
                store.interactor?.persistGoals(
                    request: .init(
                        energy: store.energy,
                        protein: store.protein,
                        carbohydrate: store.carbohydrate,
                        lipid: store.lipid
                    )
                )
            }
            Spacer()
        }
        .applyingVaultAppearance(store.preferences)
        .onAppear {
            store.interactor?.fetchGoals(request: .init())
        }
    }
}

final class GoalRevisionScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let store = GoalRevisionObservableStore()
        let interactor = GoalRevisionInteractor(vault: SignalDependencyFactory.shared.vault)
        let presenter = GoalRevisionPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: GoalRevisionView(store: store))
    }
}
