import Foundation

enum DailyIntakeDisplayModels {
    enum FetchDashboard {
        struct Request {}
        struct LaneReadout: Equatable {
            var laneKind: PulseLaneKind
            var label: String
            var energyText: String
            var artworkAssetName: String
        }
        struct Response {
            var preferences: PreferenceConfigurationSnapshot
            var totals: NutrientMagnitudeEnvelope
            var entries: [DailyConsumptionEntry]
        }
        struct ViewModel {
            var headline: String
            var energyReadout: String
            var proteinReadout: String
            var carbohydrateReadout: String
            var lipidReadout: String
            var remainingCaption: String
            var lanes: [LaneReadout]
            var isEmpty: Bool
            var preferences: PreferenceConfigurationSnapshot
        }
    }
}
