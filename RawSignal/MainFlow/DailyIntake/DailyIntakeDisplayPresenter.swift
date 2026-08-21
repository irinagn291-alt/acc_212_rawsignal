import Foundation

@MainActor
protocol DailyIntakeDisplayDisplayLogic: AnyObject {
    func displayDashboard(viewModel: DailyIntakeDisplayModels.FetchDashboard.ViewModel)
}

final class DailyIntakeDisplayPresenter: DailyIntakeDisplayPresentationLogic {
    weak var display: DailyIntakeDisplayDisplayLogic?

    func presentDashboard(response: DailyIntakeDisplayModels.FetchDashboard.Response) {
        let targets = response.preferences.dailyTargets
        let remaining = NutrientMagnitudeEnvelope(
            kilocalories: targets.kilocalories - response.totals.kilocalories,
            proteinGrams: targets.proteinGrams - response.totals.proteinGrams,
            carbohydrateGrams: targets.carbohydrateGrams - response.totals.carbohydrateGrams,
            lipidGrams: targets.lipidGrams - response.totals.lipidGrams
        )
        let lanes = PulseLaneKind.allCases.map { lane in
            let energy = response.entries
                .filter { $0.laneKind == lane }
                .reduce(0.0) { $0 + $1.computedMagnitudes.kilocalories }
            return DailyIntakeDisplayModels.FetchDashboard.LaneReadout(
                laneKind: lane,
                label: response.preferences.resolvedLabel(for: lane),
                energyText: String(format: "%.0f KCAL", energy),
                artworkAssetName: lane.artworkAssetName
            )
        }
        display?.displayDashboard(
            viewModel: .init(
                headline: "TODAY GRID",
                energyReadout: String(format: "%.0f / %.0f KCAL", response.totals.kilocalories, targets.kilocalories),
                proteinReadout: String(format: "P %.0f / %.0f", response.totals.proteinGrams, targets.proteinGrams),
                carbohydrateReadout: String(format: "C %.0f / %.0f", response.totals.carbohydrateGrams, targets.carbohydrateGrams),
                lipidReadout: String(format: "F %.0f / %.0f", response.totals.lipidGrams, targets.lipidGrams),
                remainingCaption: String(format: "REMAIN %.0f KCAL", remaining.kilocalories),
                lanes: lanes,
                isEmpty: response.entries.isEmpty,
                preferences: response.preferences
            )
        )
    }
}
