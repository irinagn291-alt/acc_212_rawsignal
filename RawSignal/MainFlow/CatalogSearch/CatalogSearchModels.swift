import Foundation

enum CatalogSearchModels {
    enum FetchShelf {
        struct Request {}
        struct Response {
            var shelf: [CatalogMerchandiseRecord]
            var preferences: PreferenceConfigurationSnapshot
        }
        struct ViewModel {
            var shelf: [CatalogMerchandiseRecord]
            var preferences: PreferenceConfigurationSnapshot
        }
    }

    enum SearchRemote {
        struct Request { var query: String }
        struct Response { var results: [CatalogMerchandiseRecord]; var failureCaption: String? }
        struct ViewModel { var results: [CatalogMerchandiseRecord]; var statusCaption: String }
    }

    enum SelectMerchandise {
        struct Request { var merchandise: CatalogMerchandiseRecord }
        struct Response {}
        struct ViewModel {}
    }
}
