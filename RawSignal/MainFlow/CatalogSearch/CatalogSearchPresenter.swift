import Foundation

@MainActor
protocol CatalogSearchDisplayLogic: AnyObject {
    func displayShelf(viewModel: CatalogSearchModels.FetchShelf.ViewModel)
    func displayRemote(viewModel: CatalogSearchModels.SearchRemote.ViewModel)
    func displaySelection(viewModel: CatalogSearchModels.SelectMerchandise.ViewModel)
}

final class CatalogSearchPresenter: CatalogSearchPresentationLogic {
    weak var display: CatalogSearchDisplayLogic?

    func presentShelf(response: CatalogSearchModels.FetchShelf.Response) {
        display?.displayShelf(viewModel: .init(shelf: response.shelf, preferences: response.preferences))
    }

    func presentRemote(response: CatalogSearchModels.SearchRemote.Response) {
        display?.displayRemote(
            viewModel: .init(
                results: response.results,
                statusCaption: response.failureCaption ?? "\(response.results.count) HITS"
            )
        )
    }

    func presentSelection(response: CatalogSearchModels.SelectMerchandise.Response) {
        display?.displaySelection(viewModel: .init())
    }
}
