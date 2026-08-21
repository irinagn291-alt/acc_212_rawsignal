import Foundation

@MainActor
protocol CatalogSearchBusinessLogic {
    func fetchShelf(request: CatalogSearchModels.FetchShelf.Request)
    func searchRemote(request: CatalogSearchModels.SearchRemote.Request)
    func selectMerchandise(request: CatalogSearchModels.SelectMerchandise.Request)
}

@MainActor
protocol CatalogSearchPresentationLogic: AnyObject {
    func presentShelf(response: CatalogSearchModels.FetchShelf.Response)
    func presentRemote(response: CatalogSearchModels.SearchRemote.Response)
    func presentSelection(response: CatalogSearchModels.SelectMerchandise.Response)
}

@MainActor
final class CatalogSearchInteractor: CatalogSearchBusinessLogic {
    var presenter: CatalogSearchPresentationLogic?
    var vault: SignalVaultPersisting
    var catalog: CatalogMerchandiseFetching
    var pipeline: SignalSessionPipeline

    init(vault: SignalVaultPersisting, catalog: CatalogMerchandiseFetching, pipeline: SignalSessionPipeline) {
        self.vault = vault
        self.catalog = catalog
        self.pipeline = pipeline
    }

    func fetchShelf(request: CatalogSearchModels.FetchShelf.Request) {
        let envelope = vault.loadEnvelope()
        presenter?.presentShelf(response: .init(shelf: envelope.localShelf, preferences: envelope.preferences))
    }

    func searchRemote(request: CatalogSearchModels.SearchRemote.Request) {
        Task {
            do {
                let results = try await catalog.searchMerchandise(matching: request.query)
                presenter?.presentRemote(response: .init(results: results, failureCaption: results.isEmpty ? "NO HITS" : nil))
            } catch {
                presenter?.presentRemote(response: .init(results: [], failureCaption: "LOOKUP FAILED"))
            }
        }
    }

    func selectMerchandise(request: CatalogSearchModels.SelectMerchandise.Request) {
        pipeline.pendingMerchandise = request.merchandise
        pipeline.pendingServingGrams = request.merchandise.defaultServingGrams
        presenter?.presentSelection(response: .init())
    }
}
