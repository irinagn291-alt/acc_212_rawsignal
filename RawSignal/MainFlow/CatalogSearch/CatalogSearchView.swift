import SwiftUI

@MainActor
final class CatalogSearchObservableStore: ObservableObject, CatalogSearchDisplayLogic {
    @Published var query = ""
    @Published var shelf: [CatalogMerchandiseRecord] = []
    @Published var remote: [CatalogMerchandiseRecord] = []
    @Published var statusCaption = "LOCAL SHELF"
    @Published var preferences = PreferenceConfigurationSnapshot.factoryDefault()
    var interactor: CatalogSearchBusinessLogic?
    var router: SignalFlowRouting?

    func displayShelf(viewModel: CatalogSearchModels.FetchShelf.ViewModel) {
        shelf = viewModel.shelf
        preferences = viewModel.preferences
    }

    func displayRemote(viewModel: CatalogSearchModels.SearchRemote.ViewModel) {
        remote = viewModel.results
        statusCaption = viewModel.statusCaption
    }

    func displaySelection(viewModel: CatalogSearchModels.SelectMerchandise.ViewModel) {
        router?.route(to: .productDetail)
    }
}

struct CatalogSearchView: View {
    @ObservedObject var store: CatalogSearchObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
            BrutalistScreenScaffold(title: "CATALOG SEARCH", backTitle: "BACK", onBack: {
            store.router?.route(to: .dailyIntake)
        }) {
            BrutalistField(placeholder: "NAME PULSE", text: $store.query)
            BrutalistPanelButton(title: "FIRE LOOKUP", emphasized: true) {
                store.interactor?.searchRemote(request: .init(query: store.query))
            }
            Text(store.statusCaption)
                .font(.plexMono(density.captionSize))
                .foregroundStyle(theme.muted)
            ScrollView {
                VStack(alignment: .leading, spacing: density.stackSpacing) {
                    Text("SHELF")
                        .font(.plexMono(density.captionSize, weight: .bold))
                        .foregroundStyle(theme.accent)
                    ForEach(store.shelf) { item in
                        merchandiseRow(item)
                    }
                    if !store.remote.isEmpty {
                        Text("REMOTE")
                            .font(.plexMono(density.captionSize, weight: .bold))
                            .foregroundStyle(theme.accent)
                        ForEach(store.remote) { item in
                            merchandiseRow(item)
                        }
                    }
                }
            }
        }
        .applyingVaultAppearance(store.preferences)
        .onAppear {
            store.interactor?.fetchShelf(request: .init())
        }
    }

    private func merchandiseRow(_ item: CatalogMerchandiseRecord) -> some View {
        Button {
            store.interactor?.selectMerchandise(request: .init(merchandise: item))
        } label: {
            HStack(spacing: 10) {
                artwork(for: item)
                    .frame(width: 52, height: 52)
                    .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.plexMono(density.bodySize, weight: .bold))
                    Text(String(format: "%.0f KCAL / 100g  %@", item.energyPerHundredGrams, item.brandLine))
                        .font(.plexMono(density.captionSize))
                        .foregroundStyle(theme.muted)
                }
                Spacer()
            }
            .foregroundStyle(theme.ink)
            .padding(8)
            .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artwork(for item: CatalogMerchandiseRecord) -> some View {
        if let name = item.artworkAssetName {
            Image(name).resizable().scaledToFill().clipped()
        } else {
            Image("ChromeRawFrame").resizable().scaledToFill().clipped()
        }
    }
}
