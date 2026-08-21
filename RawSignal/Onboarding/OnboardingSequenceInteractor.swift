import Foundation

@MainActor
protocol OnboardingSequenceBusinessLogic {
    func fetchPages(request: OnboardingSequenceModels.FetchPages.Request)
    func completeSequence(request: OnboardingSequenceModels.CompleteSequence.Request)
}

@MainActor
protocol OnboardingSequencePresentationLogic: AnyObject {
    func presentPages(response: OnboardingSequenceModels.FetchPages.Response)
    func presentCompletion(response: OnboardingSequenceModels.CompleteSequence.Response)
}

final class OnboardingSequenceInteractor: OnboardingSequenceBusinessLogic {
    var presenter: OnboardingSequencePresentationLogic?
    var vault: SignalVaultPersisting

    init(vault: SignalVaultPersisting) {
        self.vault = vault
    }

    func fetchPages(request: OnboardingSequenceModels.FetchPages.Request) {
        let pages = [
            OnboardingSequenceModels.FetchPages.PageDescriptor(
                artworkAssetName: "OnboardingPulseGrid",
                headline: "RAW SIGNAL GRID",
                bodyCopy: "Lock intake against a brutal daily target. No account. Local vault only."
            ),
            OnboardingSequenceModels.FetchPages.PageDescriptor(
                artworkAssetName: "OnboardingLaneMap",
                headline: "FOUR PULSE LANES",
                bodyCopy: "PULSE-A / PULSE-B / PULSE-C carry the horizon. NOISE is eaten-only static."
            ),
            OnboardingSequenceModels.FetchPages.PageDescriptor(
                artworkAssetName: "OnboardingScanLock",
                headline: "SEARCH OR SCAN",
                bodyCopy: "Name lookup on Open Food Facts, camera pulse, or raw EAN digits."
            ),
            OnboardingSequenceModels.FetchPages.PageDescriptor(
                artworkAssetName: "OnboardingHorizon",
                headline: "7 / 14 / 30",
                bodyCopy: "Choose a plan horizon. Rename lanes. Compress or expand the grid."
            )
        ]
        presenter?.presentPages(response: .init(pages: pages))
    }

    func completeSequence(request: OnboardingSequenceModels.CompleteSequence.Request) {
        var envelope = vault.loadEnvelope()
        envelope.onboardingCompleted = true
        vault.persistEnvelope(envelope)
        presenter?.presentCompletion(response: .init())
    }
}
