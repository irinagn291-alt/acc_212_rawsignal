import Foundation

@MainActor
protocol OnboardingSequenceDisplayLogic: AnyObject {
    func displayPages(viewModel: OnboardingSequenceModels.FetchPages.ViewModel)
    func displayCompletion(viewModel: OnboardingSequenceModels.CompleteSequence.ViewModel)
}

final class OnboardingSequencePresenter: OnboardingSequencePresentationLogic {
    weak var display: OnboardingSequenceDisplayLogic?

    func presentPages(response: OnboardingSequenceModels.FetchPages.Response) {
        display?.displayPages(viewModel: .init(pages: response.pages))
    }

    func presentCompletion(response: OnboardingSequenceModels.CompleteSequence.Response) {
        display?.displayCompletion(viewModel: .init())
    }
}
