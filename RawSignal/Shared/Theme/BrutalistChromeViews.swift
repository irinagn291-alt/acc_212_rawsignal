import SwiftUI

struct BrutalistPanelButton: View {
    let title: String
    var emphasized: Bool = false
    var action: () -> Void

    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.plexMono(density.bodySize, weight: .bold))
                .foregroundStyle(emphasized ? theme.canvas : theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(emphasized ? theme.accent : theme.panel)
                .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

struct BrutalistScreenScaffold<Content: View>: View {
    let title: String
    var backTitle: String?
    var onBack: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        ZStack {
            theme.canvas
                .ignoresSafeArea()
                .overlay {
                    Image("TextureWireMesh")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.08)
                        .allowsHitTesting(false)
                }
                .clipped()
            VStack(alignment: .leading, spacing: density.stackSpacing) {
                HStack(alignment: .top, spacing: 10) {
                    if let backTitle, let onBack {
                        Button(backTitle, action: onBack)
                            .font(.plexMono(density.captionSize, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                    Text(title)
                        .font(.plexMono(density.titleSize, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .textCase(.uppercase)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.accent)
                        .frame(height: 3)
                        .offset(y: 6)
                }
                .padding(.bottom, 8)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(density.inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct BrutalistEmptyState: View {
    let assetName: String
    let caption: String

    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        VStack(spacing: density.stackSpacing) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
            Text(caption)
                .font(.plexMono(density.captionSize, weight: .medium))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BrutalistField: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.plexMono(density.bodySize))
            .foregroundStyle(theme.ink)
            .tint(theme.accent)
            .padding(density.stackSpacing)
            .background(theme.panel)
            .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
    }
}

extension View {
    func applyingVaultAppearance(_ preferences: PreferenceConfigurationSnapshot) -> some View {
        let theme = BrutalistThemePalette.palette(for: preferences.themeIdentifier)
        let density = LayoutDensityProfile.profile(for: preferences.layoutDensity)
        return environment(\.brutalistTheme, theme)
            .environment(\.layoutDensity, density)
            .preferredColorScheme(preferences.themeIdentifier == .chalkBleed ? .light : .dark)
    }
}
