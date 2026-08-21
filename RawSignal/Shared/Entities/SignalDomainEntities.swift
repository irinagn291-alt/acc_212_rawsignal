import Foundation

enum PulseLaneKind: String, Codable, CaseIterable, Sendable {
    case pulseA
    case pulseB
    case pulseC
    case noise

    var defaultSignalLabel: String {
        switch self {
        case .pulseA: return "PULSE-A"
        case .pulseB: return "PULSE-B"
        case .pulseC: return "PULSE-C"
        case .noise: return "NOISE"
        }
    }

    var isHorizonEligible: Bool { self != .noise }

    var artworkAssetName: String {
        switch self {
        case .pulseA: return "SlotPulseA"
        case .pulseB: return "SlotPulseB"
        case .pulseC: return "SlotPulseC"
        case .noise: return "SlotNoise"
        }
    }
}

enum BrutalistThemeIdentifier: String, Codable, CaseIterable, Sendable {
    case voidGrid
    case chalkBleed
    case crimsonField
}

enum LayoutDensityIdentifier: String, Codable, CaseIterable, Sendable {
    case compressed
    case standard
    case expanded
}

struct NutrientMagnitudeEnvelope: Codable, Equatable, Sendable {
    var kilocalories: Double
    var proteinGrams: Double
    var carbohydrateGrams: Double
    var lipidGrams: Double

    static let zero = NutrientMagnitudeEnvelope(
        kilocalories: 0,
        proteinGrams: 0,
        carbohydrateGrams: 0,
        lipidGrams: 0
    )

    static let factoryDailyTargets = NutrientMagnitudeEnvelope(
        kilocalories: 2150,
        proteinGrams: 110,
        carbohydrateGrams: 240,
        lipidGrams: 70
    )

    func adding(_ other: NutrientMagnitudeEnvelope) -> NutrientMagnitudeEnvelope {
        NutrientMagnitudeEnvelope(
            kilocalories: kilocalories + other.kilocalories,
            proteinGrams: proteinGrams + other.proteinGrams,
            carbohydrateGrams: carbohydrateGrams + other.carbohydrateGrams,
            lipidGrams: lipidGrams + other.lipidGrams
        )
    }
}

struct CatalogMerchandiseRecord: Codable, Equatable, Identifiable, Sendable {
    var identifier: String
    var stockKeepingUnit: String
    var displayTitle: String
    var brandLine: String
    var energyPerHundredGrams: Double
    var proteinPerHundredGrams: Double
    var carbohydratePerHundredGrams: Double
    var lipidPerHundredGrams: Double
    var defaultServingGrams: Double
    var artworkAssetName: String?

    var id: String { identifier }

    var perHundredEnvelope: NutrientMagnitudeEnvelope {
        NutrientMagnitudeEnvelope(
            kilocalories: energyPerHundredGrams,
            proteinGrams: proteinPerHundredGrams,
            carbohydrateGrams: carbohydratePerHundredGrams,
            lipidGrams: lipidPerHundredGrams
        )
    }
}

struct DailyConsumptionEntry: Codable, Equatable, Identifiable, Sendable {
    var identifier: String
    var calendarDay: Date
    var laneKind: PulseLaneKind
    var merchandise: CatalogMerchandiseRecord
    var servingGrams: Double
    var computedMagnitudes: NutrientMagnitudeEnvelope

    var id: String { identifier }
}

struct HorizonPlanEntry: Codable, Equatable, Identifiable, Sendable {
    var identifier: String
    var calendarDay: Date
    var laneKind: PulseLaneKind
    var merchandise: CatalogMerchandiseRecord
    var servingGrams: Double
    var computedMagnitudes: NutrientMagnitudeEnvelope

    var id: String { identifier }
}

struct WishLedgerItem: Codable, Equatable, Identifiable, Sendable {
    var identifier: String
    var stockKeepingUnit: String
    var merchandise: CatalogMerchandiseRecord

    var id: String { identifier }
}

struct PreferenceConfigurationSnapshot: Codable, Equatable, Sendable {
    var themeIdentifier: BrutalistThemeIdentifier
    var layoutDensity: LayoutDensityIdentifier
    var customLaneLabels: [String: String]
    var planHorizonDays: Int
    var dailyTargets: NutrientMagnitudeEnvelope

    static func factoryDefault() -> PreferenceConfigurationSnapshot {
        PreferenceConfigurationSnapshot(
            themeIdentifier: .voidGrid,
            layoutDensity: .standard,
            customLaneLabels: [
                PulseLaneKind.pulseA.rawValue: PulseLaneKind.pulseA.defaultSignalLabel,
                PulseLaneKind.pulseB.rawValue: PulseLaneKind.pulseB.defaultSignalLabel,
                PulseLaneKind.pulseC.rawValue: PulseLaneKind.pulseC.defaultSignalLabel,
                PulseLaneKind.noise.rawValue: PulseLaneKind.noise.defaultSignalLabel
            ],
            planHorizonDays: 7,
            dailyTargets: .factoryDailyTargets
        )
    }

    func resolvedLabel(for lane: PulseLaneKind) -> String {
        customLaneLabels[lane.rawValue] ?? lane.defaultSignalLabel
    }

    func sanitizedHorizonDays() -> Int {
        switch planHorizonDays {
        case 14: return 14
        case 30: return 30
        default: return 7
        }
    }
}

struct SignalVaultEnvelope: Codable, Equatable, Sendable {
    var onboardingCompleted: Bool
    var preferences: PreferenceConfigurationSnapshot
    var consumptionLog: [DailyConsumptionEntry]
    var horizonPlans: [HorizonPlanEntry]
    var wishLedger: [WishLedgerItem]
    var localShelf: [CatalogMerchandiseRecord]
    var seedApplied: Bool

    static func emptyFactory() -> SignalVaultEnvelope {
        SignalVaultEnvelope(
            onboardingCompleted: false,
            preferences: .factoryDefault(),
            consumptionLog: [],
            horizonPlans: [],
            wishLedger: [],
            localShelf: [],
            seedApplied: false
        )
    }
}
