import SwiftUI

@MainActor
final class OnboardingSequenceObservableStore: ObservableObject, OnboardingSequenceDisplayLogic {
    @Published var pages: [OnboardingSequenceModels.FetchPages.PageDescriptor] = []
    @Published var pageIndex = 0
    var interactor: OnboardingSequenceBusinessLogic?
    var router: SignalFlowRouting?

    func displayPages(viewModel: OnboardingSequenceModels.FetchPages.ViewModel) {
        pages = viewModel.pages
    }

    func displayCompletion(viewModel: OnboardingSequenceModels.CompleteSequence.ViewModel) {
        router?.route(to: .dailyIntake)
    }
}

struct OnboardingSequenceView: View {
    @ObservedObject var store: OnboardingSequenceObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        BrutalistScreenScaffold(title: "SIGNAL BOOT") {
            if store.pages.indices.contains(store.pageIndex) {
                let page = store.pages[store.pageIndex]
                GeometryReader { geo in
                    VStack(alignment: .leading, spacing: 12) {
                        Image(page.artworkAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: 168)
                            .clipped()
                            .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
                        Text(page.headline)
                            .font(.plexMono(20, weight: .bold))
                            .foregroundStyle(theme.accent)
                            .frame(width: geo.size.width, alignment: .leading)
                        Text(page.bodyCopy)
                            .font(.plexMono(14))
                            .foregroundStyle(theme.ink)
                            .frame(width: geo.size.width, alignment: .leading)
                        Spacer(minLength: 8)
                        Text("\(store.pageIndex + 1) / \(store.pages.count)")
                            .font(.plexMono(12, weight: .medium))
                            .foregroundStyle(theme.muted)
                        BrutalistPanelButton(title: store.pageIndex + 1 == store.pages.count ? "LOCK IN" : "NEXT PULSE", emphasized: true) {
                            if store.pageIndex + 1 == store.pages.count {
                                store.interactor?.completeSequence(request: .init())
                            } else {
                                store.pageIndex += 1
                            }
                        }
                        .frame(width: geo.size.width)
                    }
                }
            }
        }
        .onAppear {
            store.interactor?.fetchPages(request: .init())
        }
    }
}
