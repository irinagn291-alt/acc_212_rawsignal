import SwiftUI
import UIKit

enum ConsumedLogModels {
    enum FetchLog {
        struct Request {}
        struct Row: Equatable {
            var identifier: String
            var title: String
            var laneLabel: String
            var magnitude: String
        }
        struct Response {
            var entries: [DailyConsumptionEntry]
            var preferences: PreferenceConfigurationSnapshot
        }
        struct ViewModel {
            var rows: [Row]
            var isEmpty: Bool
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum DeleteEntry {
        struct Request { var identifier: String }
        struct Response {
            var entries: [DailyConsumptionEntry]
            var preferences: PreferenceConfigurationSnapshot
        }
    }
}

@MainActor
protocol ConsumedLogBusinessLogic {
    func fetchLog(request: ConsumedLogModels.FetchLog.Request)
    func deleteEntry(request: ConsumedLogModels.DeleteEntry.Request)
}

@MainActor
protocol ConsumedLogPresentationLogic: AnyObject {
    func presentLog(response: ConsumedLogModels.FetchLog.Response)
}

final class ConsumedLogInteractor: ConsumedLogBusinessLogic {
    var presenter: ConsumedLogPresentationLogic?
    var vault: SignalVaultPersisting
    var calendar: Calendar
    var now: () -> Date

    init(vault: SignalVaultPersisting, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.vault = vault
        self.calendar = calendar
        self.now = now
    }

    func fetchLog(request: ConsumedLogModels.FetchLog.Request) {
        emit()
    }

    func deleteEntry(request: ConsumedLogModels.DeleteEntry.Request) {
        var envelope = vault.loadEnvelope()
        envelope.consumptionLog.removeAll { $0.identifier == request.identifier }
        vault.persistEnvelope(envelope)
        emit()
    }

    private func emit() {
        let envelope = vault.loadEnvelope()
        let today = calendar.startOfDay(for: now())
        let entries = envelope.consumptionLog.filter { calendar.isDate($0.calendarDay, inSameDayAs: today) }
        presenter?.presentLog(response: .init(entries: entries, preferences: envelope.preferences))
    }
}

final class ConsumedLogPresenter: ConsumedLogPresentationLogic {
    weak var display: ConsumedLogDisplayLogic?

    func presentLog(response: ConsumedLogModels.FetchLog.Response) {
        let rows = response.entries.map { entry in
            ConsumedLogModels.FetchLog.Row(
                identifier: entry.identifier,
                title: entry.merchandise.displayTitle,
                laneLabel: response.preferences.resolvedLabel(for: entry.laneKind),
                magnitude: String(format: "%.0f KCAL / %.0f G", entry.computedMagnitudes.kilocalories, entry.servingGrams)
            )
        }
        display?.displayLog(
            viewModel: .init(rows: rows, isEmpty: rows.isEmpty, preferences: response.preferences)
        )
    }
}

@MainActor
protocol ConsumedLogDisplayLogic: AnyObject {
    func displayLog(viewModel: ConsumedLogModels.FetchLog.ViewModel)
}

@MainActor
final class ConsumedLogObservableStore: ObservableObject, ConsumedLogDisplayLogic {
    @Published var viewModel: ConsumedLogModels.FetchLog.ViewModel?
    var interactor: ConsumedLogBusinessLogic?
    var router: SignalFlowRouting?

    func displayLog(viewModel: ConsumedLogModels.FetchLog.ViewModel) {
        self.viewModel = viewModel
    }
}

struct ConsumedLogView: View {
    @ObservedObject var store: ConsumedLogObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        let preferences = store.viewModel?.preferences ?? .factoryDefault()
        BrutalistScreenScaffold(title: "EATEN LOG", backTitle: "BACK", onBack: {
            store.router?.route(to: .dailyIntake)
        }) {
            if let viewModel = store.viewModel {
                if viewModel.isEmpty {
                    BrutalistEmptyState(assetName: "EmptyTodayGrid", caption: "NOTHING EATEN IN THIS GRID")
                } else {
                    List {
                        ForEach(viewModel.rows, id: \.identifier) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.plexMono(density.bodySize, weight: .bold))
                                Text("\(row.laneLabel)  \(row.magnitude)")
                                    .font(.plexMono(density.captionSize))
                            }
                            .foregroundStyle(theme.ink)
                            .listRowBackground(theme.panel)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.interactor?.deleteEntry(request: .init(identifier: viewModel.rows[index].identifier))
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
            store.interactor?.fetchLog(request: .init())
        }
    }
}

final class ConsumedLogScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let store = ConsumedLogObservableStore()
        let interactor = ConsumedLogInteractor(vault: SignalDependencyFactory.shared.vault)
        let presenter = ConsumedLogPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: ConsumedLogView(store: store))
    }
}
