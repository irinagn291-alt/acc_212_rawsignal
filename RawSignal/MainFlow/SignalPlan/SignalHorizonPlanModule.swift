import SwiftUI
import UIKit

enum SignalHorizonPlanModels {
    enum FetchPlan {
        struct Request {}
        struct DayBlock: Equatable, Identifiable {
            var id: String
            var caption: String
            var rows: [Row]
        }
        struct Row: Equatable, Identifiable {
            var id: String
            var title: String
            var laneLabel: String
            var magnitude: String
        }
        struct Response {
            var preferences: PreferenceConfigurationSnapshot
            var entries: [HorizonPlanEntry]
            var referenceDay: Date
        }
        struct ViewModel {
            var days: [DayBlock]
            var isEmpty: Bool
            var horizonCaption: String
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum DeleteEntry {
        struct Request { var identifier: String }
    }
}

@MainActor
protocol SignalHorizonPlanBusinessLogic {
    func fetchPlan(request: SignalHorizonPlanModels.FetchPlan.Request)
    func deleteEntry(request: SignalHorizonPlanModels.DeleteEntry.Request)
    func beginAddFromSearch()
}

@MainActor
protocol SignalHorizonPlanPresentationLogic: AnyObject {
    func presentPlan(response: SignalHorizonPlanModels.FetchPlan.Response)
}

@MainActor
final class SignalHorizonPlanInteractor: SignalHorizonPlanBusinessLogic {
    var presenter: SignalHorizonPlanPresentationLogic?
    var vault: SignalVaultPersisting
    var pipeline: SignalSessionPipeline
    var calendar: Calendar
    var now: () -> Date

    init(
        vault: SignalVaultPersisting,
        pipeline: SignalSessionPipeline,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.vault = vault
        self.pipeline = pipeline
        self.calendar = calendar
        self.now = now
    }

    func fetchPlan(request: SignalHorizonPlanModels.FetchPlan.Request) {
        emit()
    }

    func deleteEntry(request: SignalHorizonPlanModels.DeleteEntry.Request) {
        var envelope = vault.loadEnvelope()
        envelope.horizonPlans.removeAll { $0.identifier == request.identifier }
        vault.persistEnvelope(envelope)
        emit()
    }

    func beginAddFromSearch() {
        pipeline.assignmentReturnsToPlan = true
    }

    private func emit() {
        let envelope = vault.loadEnvelope()
        presenter?.presentPlan(
            response: .init(
                preferences: envelope.preferences,
                entries: envelope.horizonPlans,
                referenceDay: calendar.startOfDay(for: now())
            )
        )
    }
}

final class SignalHorizonPlanPresenter: SignalHorizonPlanPresentationLogic {
    weak var display: SignalHorizonPlanDisplayLogic?
    private let calendar = Calendar.current

    func presentPlan(response: SignalHorizonPlanModels.FetchPlan.Response) {
        let horizon = response.preferences.sanitizedHorizonDays()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var blocks: [SignalHorizonPlanModels.FetchPlan.DayBlock] = []
        for offset in 0..<horizon {
            guard let day = calendar.date(byAdding: .day, value: offset, to: response.referenceDay) else { continue }
            let rows = response.entries
                .filter { calendar.isDate($0.calendarDay, inSameDayAs: day) }
                .map { entry in
                    SignalHorizonPlanModels.FetchPlan.Row(
                        id: entry.identifier,
                        title: entry.merchandise.displayTitle,
                        laneLabel: response.preferences.resolvedLabel(for: entry.laneKind),
                        magnitude: String(format: "%.0f KCAL", entry.computedMagnitudes.kilocalories)
                    )
                }
            blocks.append(
                .init(
                    id: "D+\(offset)",
                    caption: "D+\(offset)  \(formatter.string(from: day).uppercased())",
                    rows: rows
                )
            )
        }
        display?.displayPlan(
            viewModel: .init(
                days: blocks,
                isEmpty: response.entries.isEmpty,
                horizonCaption: "HORIZON \(horizon)",
                preferences: response.preferences
            )
        )
    }
}

@MainActor
protocol SignalHorizonPlanDisplayLogic: AnyObject {
    func displayPlan(viewModel: SignalHorizonPlanModels.FetchPlan.ViewModel)
}

@MainActor
final class SignalHorizonPlanObservableStore: ObservableObject, SignalHorizonPlanDisplayLogic {
    @Published var viewModel: SignalHorizonPlanModels.FetchPlan.ViewModel?
    var interactor: SignalHorizonPlanBusinessLogic?
    var router: SignalFlowRouting?

    func displayPlan(viewModel: SignalHorizonPlanModels.FetchPlan.ViewModel) {
        self.viewModel = viewModel
    }
}

struct SignalHorizonPlanView: View {
    @ObservedObject var store: SignalHorizonPlanObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        let preferences = store.viewModel?.preferences ?? .factoryDefault()
        BrutalistScreenScaffold(title: store.viewModel?.horizonCaption ?? "HORIZON", backTitle: "BACK", onBack: {
            store.router?.route(to: .dailyIntake)
        }) {
            BrutalistPanelButton(title: "ADD FROM SEARCH", emphasized: true) {
                store.interactor?.beginAddFromSearch()
                store.router?.route(to: .catalogSearch)
            }
            if let viewModel = store.viewModel {
                if viewModel.isEmpty {
                    BrutalistEmptyState(assetName: "EmptyHorizonPlan", caption: "HORIZON HAS NO LOCKS")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: density.stackSpacing) {
                            ForEach(viewModel.days) { day in
                                Text(day.caption)
                                    .font(.plexMono(density.captionSize, weight: .bold))
                                    .foregroundStyle(theme.accent)
                                if day.rows.isEmpty {
                                    Text("—")
                                        .font(.plexMono(density.captionSize))
                                        .foregroundStyle(theme.muted)
                                }
                                ForEach(day.rows) { row in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(row.title)
                                                .font(.plexMono(density.bodySize, weight: .bold))
                                            Text("\(row.laneLabel)  \(row.magnitude)")
                                                .font(.plexMono(density.captionSize))
                                        }
                                        Spacer()
                                        Button("X") {
                                            store.interactor?.deleteEntry(request: .init(identifier: row.id))
                                        }
                                        .font(.plexMono(density.bodySize, weight: .bold))
                                        .foregroundStyle(theme.accent)
                                    }
                                    .foregroundStyle(theme.ink)
                                    .padding(8)
                                    .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
                                }
                            }
                        }
                    }
                }
            }
        }
        .applyingVaultAppearance(preferences)
        .onAppear {
            store.interactor?.fetchPlan(request: .init())
        }
    }
}

final class SignalHorizonPlanScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let factory = SignalDependencyFactory.shared
        let store = SignalHorizonPlanObservableStore()
        let interactor = SignalHorizonPlanInteractor(vault: factory.vault, pipeline: factory.pipeline)
        let presenter = SignalHorizonPlanPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: SignalHorizonPlanView(store: store))
    }
}
