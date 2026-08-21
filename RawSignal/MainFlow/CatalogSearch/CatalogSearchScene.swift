import SwiftUI
import UIKit

final class CatalogSearchScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let factory = SignalDependencyFactory.shared
        let store = CatalogSearchObservableStore()
        let interactor = CatalogSearchInteractor(
            vault: factory.vault,
            catalog: factory.catalog,
            pipeline: factory.pipeline
        )
        let presenter = CatalogSearchPresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        return UIHostingController(rootView: CatalogSearchView(store: store))
    }
}
