import SwiftUI
import UIKit

final class DailyIntakeDisplayScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let store = DailyIntakeDisplayObservableStore()
        let interactor = DailyIntakeDisplayInteractor(vault: SignalDependencyFactory.shared.vault)
        let presenter = DailyIntakeDisplayPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: DailyIntakeDisplayView(store: store))
    }
}
