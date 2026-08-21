import SwiftUI
import UIKit

final class OnboardingSequenceScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let store = OnboardingSequenceObservableStore()
        let interactor = OnboardingSequenceInteractor(vault: SignalDependencyFactory.shared.vault)
        let presenter = OnboardingSequencePresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        let view = OnboardingSequenceView(store: store)
            .applyingVaultAppearance(SignalDependencyFactory.shared.vault.loadEnvelope().preferences)
        return UIHostingController(rootView: view)
    }
}
