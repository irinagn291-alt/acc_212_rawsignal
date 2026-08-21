import Foundation

enum OnboardingSequenceModels {
    enum FetchPages {
        struct Request {}
        struct Response {
            var pages: [PageDescriptor]
        }
        struct ViewModel {
            var pages: [PageDescriptor]
        }
        struct PageDescriptor: Equatable {
            var artworkAssetName: String
            var headline: String
            var bodyCopy: String
        }
    }

    enum CompleteSequence {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }
}
