import SwiftUI
import UIKit

enum PreferenceConfigurationModels {
    enum FetchPreferences {
        struct Request {}
        struct Response { var preferences: PreferenceConfigurationSnapshot }
        struct ViewModel {
            var theme: BrutalistThemeIdentifier
            var density: LayoutDensityIdentifier
            var horizonDays: Int
            var pulseA: String
            var pulseB: String
            var pulseC: String
            var noise: String
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum PersistPreferences {
        struct Request {
            var theme: BrutalistThemeIdentifier
            var density: LayoutDensityIdentifier
            var horizonDays: Int
            var pulseA: String
            var pulseB: String
            var pulseC: String
            var noise: String
        }
        struct Response { var preferences: PreferenceConfigurationSnapshot }
    }
}

@MainActor
protocol PreferenceConfigurationBusinessLogic {
    func fetchPreferences(request: PreferenceConfigurationModels.FetchPreferences.Request)
    func persistPreferences(request: PreferenceConfigurationModels.PersistPreferences.Request)
}

@MainActor
protocol PreferenceConfigurationPresentationLogic: AnyObject {
    func presentPreferences(response: PreferenceConfigurationModels.FetchPreferences.Response)
}

final class PreferenceConfigurationInteractor: PreferenceConfigurationBusinessLogic {
    var presenter: PreferenceConfigurationPresentationLogic?
    var vault: SignalVaultPersisting

    init(vault: SignalVaultPersisting) {
        self.vault = vault
    }

    func fetchPreferences(request: PreferenceConfigurationModels.FetchPreferences.Request) {
        presenter?.presentPreferences(response: .init(preferences: vault.loadEnvelope().preferences))
    }

    func persistPreferences(request: PreferenceConfigurationModels.PersistPreferences.Request) {
        var envelope = vault.loadEnvelope()
        envelope.preferences.themeIdentifier = request.theme
        envelope.preferences.layoutDensity = request.density
        envelope.preferences.planHorizonDays = [7, 14, 30].contains(request.horizonDays) ? request.horizonDays : 7
        envelope.preferences.customLaneLabels = [
            PulseLaneKind.pulseA.rawValue: sanitized(request.pulseA, fallback: PulseLaneKind.pulseA.defaultSignalLabel),
            PulseLaneKind.pulseB.rawValue: sanitized(request.pulseB, fallback: PulseLaneKind.pulseB.defaultSignalLabel),
            PulseLaneKind.pulseC.rawValue: sanitized(request.pulseC, fallback: PulseLaneKind.pulseC.defaultSignalLabel),
            PulseLaneKind.noise.rawValue: sanitized(request.noise, fallback: PulseLaneKind.noise.defaultSignalLabel)
        ]
        vault.persistEnvelope(envelope)
        presenter?.presentPreferences(response: .init(preferences: envelope.preferences))
    }

    private func sanitized(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(18))
    }
}

final class PreferenceConfigurationPresenter: PreferenceConfigurationPresentationLogic {
    weak var display: PreferenceConfigurationDisplayLogic?

    func presentPreferences(response: PreferenceConfigurationModels.FetchPreferences.Response) {
        let prefs = response.preferences
        display?.displayPreferences(
            viewModel: .init(
                theme: prefs.themeIdentifier,
                density: prefs.layoutDensity,
                horizonDays: prefs.sanitizedHorizonDays(),
                pulseA: prefs.resolvedLabel(for: .pulseA),
                pulseB: prefs.resolvedLabel(for: .pulseB),
                pulseC: prefs.resolvedLabel(for: .pulseC),
                noise: prefs.resolvedLabel(for: .noise),
                preferences: prefs
            )
        )
    }
}

@MainActor
protocol PreferenceConfigurationDisplayLogic: AnyObject {
    func displayPreferences(viewModel: PreferenceConfigurationModels.FetchPreferences.ViewModel)
}

@MainActor
final class PreferenceConfigurationObservableStore: ObservableObject, PreferenceConfigurationDisplayLogic {
    @Published var theme: BrutalistThemeIdentifier = .voidGrid
    @Published var density: LayoutDensityIdentifier = .standard
    @Published var horizonDays = 7
    @Published var pulseA = PulseLaneKind.pulseA.defaultSignalLabel
    @Published var pulseB = PulseLaneKind.pulseB.defaultSignalLabel
    @Published var pulseC = PulseLaneKind.pulseC.defaultSignalLabel
    @Published var noise = PulseLaneKind.noise.defaultSignalLabel
    @Published var preferences = PreferenceConfigurationSnapshot.factoryDefault()
    var interactor: PreferenceConfigurationBusinessLogic?
    var router: SignalFlowRouting?

    func displayPreferences(viewModel: PreferenceConfigurationModels.FetchPreferences.ViewModel) {
        theme = viewModel.theme
        density = viewModel.density
        horizonDays = viewModel.horizonDays
        pulseA = viewModel.pulseA
        pulseB = viewModel.pulseB
        pulseC = viewModel.pulseC
        noise = viewModel.noise
        preferences = viewModel.preferences
    }

    func persist() {
        interactor?.persistPreferences(
            request: .init(
                theme: theme,
                density: density,
                horizonDays: horizonDays,
                pulseA: pulseA,
                pulseB: pulseB,
                pulseC: pulseC,
                noise: noise
            )
        )
    }
}

struct PreferenceConfigurationView: View {
    @ObservedObject var store: PreferenceConfigurationObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density
    @State private var showContact = false

    var body: some View {
        BrutalistScreenScaffold(title: "PREF GRID", backTitle: "BACK", onBack: {
            store.router?.route(to: .dailyIntake)
        }) {
            ScrollView {
                VStack(alignment: .leading, spacing: density.stackSpacing) {
                    Text("THEME")
                        .font(.plexMono(density.captionSize, weight: .bold))
                        .foregroundStyle(theme.accent)
                    Picker("THEME", selection: $store.theme) {
                        Text("VOID").tag(BrutalistThemeIdentifier.voidGrid)
                        Text("CHALK").tag(BrutalistThemeIdentifier.chalkBleed)
                        Text("CRIMSON").tag(BrutalistThemeIdentifier.crimsonField)
                    }
                    .pickerStyle(.segmented)
                    Text("DENSITY")
                        .font(.plexMono(density.captionSize, weight: .bold))
                        .foregroundStyle(theme.accent)
                    Picker("DENSITY", selection: $store.density) {
                        Text("COMPACT").tag(LayoutDensityIdentifier.compressed)
                        Text("STD").tag(LayoutDensityIdentifier.standard)
                        Text("WIDE").tag(LayoutDensityIdentifier.expanded)
                    }
                    .pickerStyle(.segmented)
                    Text("HORIZON")
                        .font(.plexMono(density.captionSize, weight: .bold))
                        .foregroundStyle(theme.accent)
                    Picker("HORIZON", selection: $store.horizonDays) {
                        Text("7").tag(7)
                        Text("14").tag(14)
                        Text("30").tag(30)
                    }
                    .pickerStyle(.segmented)
                    Text("LANE LABELS")
                        .font(.plexMono(density.captionSize, weight: .bold))
                        .foregroundStyle(theme.accent)
                    BrutalistField(placeholder: "PULSE-A", text: $store.pulseA)
                    BrutalistField(placeholder: "PULSE-B", text: $store.pulseB)
                    BrutalistField(placeholder: "PULSE-C", text: $store.pulseC)
                    BrutalistField(placeholder: "NOISE", text: $store.noise)
                    BrutalistPanelButton(title: "WRITE VAULT", emphasized: true) {
                        store.persist()
                    }
                    BrutalistPanelButton(title: "REVISE GOALS") {
                        store.router?.route(to: .goalRevision)
                    }
                    BrutalistPanelButton(title: "CONTACT US") {
                        showContact = true
                    }
                }
            }
        }
        .sheet(isPresented: $showContact) {
            PulseContactPane()
        }
        .applyingVaultAppearance(store.preferences)
        .onAppear {
            store.interactor?.fetchPreferences(request: .init())
        }
        .onChange(of: store.theme) { _, _ in store.persist() }
        .onChange(of: store.density) { _, _ in store.persist() }
        .onChange(of: store.horizonDays) { _, _ in store.persist() }
    }
}

final class PreferenceConfigurationScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let store = PreferenceConfigurationObservableStore()
        let interactor = PreferenceConfigurationInteractor(vault: SignalDependencyFactory.shared.vault)
        let presenter = PreferenceConfigurationPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: PreferenceConfigurationView(store: store))
    }
}
