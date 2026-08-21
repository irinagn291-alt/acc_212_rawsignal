import Foundation

@MainActor
protocol DailyIntakeDisplayBusinessLogic {
    func fetchDashboard(request: DailyIntakeDisplayModels.FetchDashboard.Request)
}

@MainActor
protocol DailyIntakeDisplayPresentationLogic: AnyObject {
    func presentDashboard(response: DailyIntakeDisplayModels.FetchDashboard.Response)
}

final class DailyIntakeDisplayInteractor: DailyIntakeDisplayBusinessLogic {
    var presenter: DailyIntakeDisplayPresentationLogic?
    var vault: SignalVaultPersisting
    var calendar: Calendar
    var now: () -> Date

    init(
        vault: SignalVaultPersisting,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.vault = vault
        self.calendar = calendar
        self.now = now
    }

    func fetchDashboard(request: DailyIntakeDisplayModels.FetchDashboard.Request) {
        let envelope = vault.loadEnvelope()
        let today = calendar.startOfDay(for: now())
        let todays = envelope.consumptionLog.filter { calendar.isDate($0.calendarDay, inSameDayAs: today) }
        let totals = todays.reduce(NutrientMagnitudeEnvelope.zero) { $0.adding($1.computedMagnitudes) }
        presenter?.presentDashboard(
            response: .init(
                preferences: envelope.preferences,
                totals: totals,
                entries: todays
            )
        )
    }
}
