import SwiftUI
import UIKit

enum SlotAssignmentModels {
    enum FetchOptions {
        struct Request {}
        struct Response {
            var preferences: PreferenceConfigurationSnapshot
            var returnsToPlan: Bool
            var hasMerchandise: Bool
        }
        struct ViewModel {
            var lanes: [PulseLaneKind]
            var labels: [PulseLaneKind: String]
            var horizonDays: Int
            var returnsToPlan: Bool
            var missing: Bool
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum CommitAssignment {
        struct Request {
            var laneKind: PulseLaneKind
            var dayOffset: Int
            var destination: Destination
        }
        enum Destination { case todayEaten; case horizonPlan }
        enum Failure: Equatable { case missingMerchandise; case noiseOnHorizon }
        struct Response { var failure: Failure? }
        struct ViewModel { var statusCaption: String; var shouldLeave: Bool }
    }
}

@MainActor
protocol SlotAssignmentBusinessLogic {
    func fetchOptions(request: SlotAssignmentModels.FetchOptions.Request)
    func commitAssignment(request: SlotAssignmentModels.CommitAssignment.Request)
}

@MainActor
protocol SlotAssignmentPresentationLogic: AnyObject {
    func presentOptions(response: SlotAssignmentModels.FetchOptions.Response)
    func presentCommit(response: SlotAssignmentModels.CommitAssignment.Response)
}

@MainActor
final class SlotAssignmentInteractor: SlotAssignmentBusinessLogic {
    var presenter: SlotAssignmentPresentationLogic?
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

    func fetchOptions(request: SlotAssignmentModels.FetchOptions.Request) {
        presenter?.presentOptions(
            response: .init(
                preferences: vault.loadEnvelope().preferences,
                returnsToPlan: pipeline.assignmentReturnsToPlan,
                hasMerchandise: pipeline.pendingMerchandise != nil
            )
        )
    }

    func commitAssignment(request: SlotAssignmentModels.CommitAssignment.Request) {
        guard let merchandise = pipeline.pendingMerchandise else {
            presenter?.presentCommit(response: .init(failure: .missingMerchandise))
            return
        }
        if request.destination == .horizonPlan, !request.laneKind.isHorizonEligible {
            presenter?.presentCommit(response: .init(failure: .noiseOnHorizon))
            return
        }
        let grams = pipeline.pendingServingGrams
        let magnitudes = NutrientPortionCalculator.scaledEnvelope(
            perHundredGrams: merchandise.perHundredEnvelope,
            servingGrams: grams
        )
        let day = calendar.date(byAdding: .day, value: request.dayOffset, to: calendar.startOfDay(for: now()))
            ?? calendar.startOfDay(for: now())
        var envelope = vault.loadEnvelope()
        switch request.destination {
        case .todayEaten:
            envelope.consumptionLog.append(
                DailyConsumptionEntry(
                    identifier: UUID().uuidString,
                    calendarDay: calendar.startOfDay(for: now()),
                    laneKind: request.laneKind,
                    merchandise: merchandise,
                    servingGrams: grams,
                    computedMagnitudes: magnitudes
                )
            )
        case .horizonPlan:
            envelope.horizonPlans.append(
                HorizonPlanEntry(
                    identifier: UUID().uuidString,
                    calendarDay: day,
                    laneKind: request.laneKind,
                    merchandise: merchandise,
                    servingGrams: grams,
                    computedMagnitudes: magnitudes
                )
            )
        }
        vault.persistEnvelope(envelope)
        presenter?.presentCommit(response: .init(failure: nil))
    }
}

final class SlotAssignmentPresenter: SlotAssignmentPresentationLogic {
    weak var display: SlotAssignmentDisplayLogic?

    func presentOptions(response: SlotAssignmentModels.FetchOptions.Response) {
        let lanes: [PulseLaneKind] = response.returnsToPlan
            ? PulseLaneKind.allCases.filter(\.isHorizonEligible)
            : PulseLaneKind.allCases
        var labels: [PulseLaneKind: String] = [:]
        for lane in PulseLaneKind.allCases {
            labels[lane] = response.preferences.resolvedLabel(for: lane)
        }
        display?.displayOptions(
            viewModel: .init(
                lanes: lanes,
                labels: labels,
                horizonDays: response.preferences.sanitizedHorizonDays(),
                returnsToPlan: response.returnsToPlan,
                missing: !response.hasMerchandise,
                preferences: response.preferences
            )
        )
    }

    func presentCommit(response: SlotAssignmentModels.CommitAssignment.Response) {
        switch response.failure {
        case .missingMerchandise:
            display?.displayCommit(viewModel: .init(statusCaption: "NO MERCH", shouldLeave: false))
        case .noiseOnHorizon:
            display?.displayCommit(viewModel: .init(statusCaption: "NOISE STAYS OFF PLAN", shouldLeave: false))
        case nil:
            display?.displayCommit(viewModel: .init(statusCaption: "LANE LOCKED", shouldLeave: true))
        }
    }
}

@MainActor
protocol SlotAssignmentDisplayLogic: AnyObject {
    func displayOptions(viewModel: SlotAssignmentModels.FetchOptions.ViewModel)
    func displayCommit(viewModel: SlotAssignmentModels.CommitAssignment.ViewModel)
}

@MainActor
final class SlotAssignmentObservableStore: ObservableObject, SlotAssignmentDisplayLogic {
    @Published var viewModel: SlotAssignmentModels.FetchOptions.ViewModel?
    @Published var statusCaption = ""
    @Published var dayOffset = 0
    @Published var destinationIsPlan = false
    var interactor: SlotAssignmentBusinessLogic?
    var router: SignalFlowRouting?

    func displayOptions(viewModel: SlotAssignmentModels.FetchOptions.ViewModel) {
        self.viewModel = viewModel
        destinationIsPlan = viewModel.returnsToPlan
    }

    func displayCommit(viewModel: SlotAssignmentModels.CommitAssignment.ViewModel) {
        statusCaption = viewModel.statusCaption
        if viewModel.shouldLeave {
            router?.route(to: destinationIsPlan ? .signalPlan : .dailyIntake)
        }
    }
}

struct SlotAssignmentView: View {
    @ObservedObject var store: SlotAssignmentObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        let preferences = store.viewModel?.preferences ?? .factoryDefault()
        BrutalistScreenScaffold(title: "ASSIGN LANE", backTitle: "BACK", onBack: {
            store.router?.route(to: .productDetail)
        }) {
            if let viewModel = store.viewModel {
                if viewModel.missing {
                    Text("NO MERCH IN PIPELINE")
                        .font(.plexMono(density.bodySize, weight: .bold))
                        .foregroundStyle(theme.accent)
                } else {
                    Toggle(isOn: $store.destinationIsPlan) {
                        Text("SEND TO HORIZON")
                            .font(.plexMono(density.bodySize, weight: .bold))
                            .foregroundStyle(theme.ink)
                    }
                    .tint(theme.accent)
                    if store.destinationIsPlan {
                        Picker("DAY", selection: $store.dayOffset) {
                            ForEach(0..<viewModel.horizonDays, id: \.self) { offset in
                                Text("D+\(offset)").tag(offset)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                    }
                    ForEach(viewModel.lanes, id: \.self) { lane in
                        Button {
                            store.interactor?.commitAssignment(
                                request: .init(
                                    laneKind: lane,
                                    dayOffset: store.dayOffset,
                                    destination: store.destinationIsPlan ? .horizonPlan : .todayEaten
                                )
                            )
                        } label: {
                            HStack {
                                Image(lane.artworkAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                Text(viewModel.labels[lane] ?? lane.defaultSignalLabel)
                                    .font(.plexMono(density.bodySize, weight: .bold))
                                Spacer()
                            }
                            .foregroundStyle(theme.ink)
                            .padding(8)
                            .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                    if !store.statusCaption.isEmpty {
                        Text(store.statusCaption)
                            .font(.plexMono(density.captionSize))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .applyingVaultAppearance(preferences)
        .onAppear {
            store.interactor?.fetchOptions(request: .init())
        }
    }
}

final class SlotAssignmentScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let factory = SignalDependencyFactory.shared
        let store = SlotAssignmentObservableStore()
        let interactor = SlotAssignmentInteractor(vault: factory.vault, pipeline: factory.pipeline)
        let presenter = SlotAssignmentPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: SlotAssignmentView(store: store))
    }
}
