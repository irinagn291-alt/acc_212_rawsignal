import SwiftUI

@MainActor
final class DailyIntakeDisplayObservableStore: ObservableObject, DailyIntakeDisplayDisplayLogic {
    @Published var viewModel: DailyIntakeDisplayModels.FetchDashboard.ViewModel?
    var interactor: DailyIntakeDisplayBusinessLogic?
    var router: SignalFlowRouting?

    func displayDashboard(viewModel: DailyIntakeDisplayModels.FetchDashboard.ViewModel) {
        self.viewModel = viewModel
    }
}

struct DailyIntakeDisplayView: View {
    @ObservedObject var store: DailyIntakeDisplayObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        let preferences = store.viewModel?.preferences ?? .factoryDefault()
        BrutalistScreenScaffold(title: store.viewModel?.headline ?? "TODAY GRID") {
            if let viewModel = store.viewModel {
                Text(viewModel.energyReadout)
                    .font(.plexMono(density.readoutSize, weight: .bold))
                    .foregroundStyle(theme.accent)
                HStack {
                    Text(viewModel.proteinReadout)
                    Spacer()
                    Text(viewModel.carbohydrateReadout)
                    Spacer()
                    Text(viewModel.lipidReadout)
                }
                .font(.plexMono(density.captionSize, weight: .medium))
                .foregroundStyle(theme.ink)
                Text(viewModel.remainingCaption)
                    .font(.plexMono(density.captionSize))
                    .foregroundStyle(theme.muted)
                if viewModel.isEmpty {
                    BrutalistEmptyState(assetName: "EmptyTodayGrid", caption: "NO PULSES LOCKED TODAY")
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: density.stackSpacing) {
                        ForEach(viewModel.lanes, id: \.laneKind) { lane in
                            VStack(alignment: .leading, spacing: 6) {
                                Image(lane.artworkAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 72)
                                Text(lane.label)
                                    .font(.plexMono(density.captionSize, weight: .bold))
                                Text(lane.energyText)
                                    .font(.plexMono(density.captionSize))
                            }
                            .foregroundStyle(theme.ink)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
                        }
                    }
                }
                VStack(spacing: density.stackSpacing) {
                    HStack(spacing: 8) {
                        BrutalistPanelButton(title: "SEARCH") { store.router?.route(to: .catalogSearch) }
                        BrutalistPanelButton(title: "SCAN") { store.router?.route(to: .barcodeCapture) }
                    }
                    HStack(spacing: 8) {
                        BrutalistPanelButton(title: "EATEN") { store.router?.route(to: .consumedLog) }
                        BrutalistPanelButton(title: "WISH") { store.router?.route(to: .wishLedger) }
                    }
                    HStack(spacing: 8) {
                        BrutalistPanelButton(title: "PLAN") { store.router?.route(to: .signalPlan) }
                        BrutalistPanelButton(title: "GOALS") { store.router?.route(to: .goalRevision) }
                    }
                    BrutalistPanelButton(title: "PREFS", emphasized: true) {
                        store.router?.route(to: .preferenceConfiguration)
                    }
                }
            }
        }
        .applyingVaultAppearance(preferences)
        .onAppear {
            SignalDependencyFactory.shared.pipeline.assignmentReturnsToPlan = false
            store.interactor?.fetchDashboard(request: .init())
        }
    }
}
