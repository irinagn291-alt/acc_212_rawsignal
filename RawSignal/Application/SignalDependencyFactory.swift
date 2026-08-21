import Foundation

enum SignalFlowDestination: Equatable {
    case onboarding
    case dailyIntake
    case catalogSearch
    case barcodeCapture
    case productDetail
    case slotAssignment
    case consumedLog
    case wishLedger
    case signalPlan
    case preferenceConfiguration
    case goalRevision
}

@MainActor
final class SignalSessionPipeline {
    var pendingMerchandise: CatalogMerchandiseRecord?
    var pendingServingGrams: Double = 100
    var assignmentReturnsToPlan = false
}

@MainActor
final class SignalDependencyFactory {
    static let shared = SignalDependencyFactory()

    let vault: SignalVaultPersisting
    let catalog: CatalogMerchandiseFetching
    let pipeline = SignalSessionPipeline()

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = documents.appendingPathComponent("rawsignal.archive")
        vault = SignalArchiveBinaryStore(fileURL: fileURL)
        catalog = OpenFoodFactsCatalogGateway()
    }

    func prepareVaultIfNeeded() {
        SimulatorShelfSeeder.applyIfNeeded(vault: vault)
    }
}
