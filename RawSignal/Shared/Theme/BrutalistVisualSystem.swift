import SwiftUI
import UIKit

enum BrutalistTypefaceRegistrar {
    static func confirmRegistration() {
        _ = UIFont(name: "IBMPlexMono-Regular", size: 14)
    }
}

extension Font {
    static func plexMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black:
            return .custom("IBMPlexMono-Bold", size: size)
        case .medium, .semibold:
            return .custom("IBMPlexMono-Medium", size: size)
        default:
            return .custom("IBMPlexMono-Regular", size: size)
        }
    }
}

struct BrutalistThemePalette: Equatable {
    var canvas: Color
    var ink: Color
    var accent: Color
    var muted: Color
    var panel: Color
    var uiCanvas: UIColor
    var uiInk: UIColor
    var uiAccent: UIColor

    static let voidGrid = BrutalistThemePalette(
        canvas: Color(red: 0.02, green: 0.02, blue: 0.02),
        ink: Color.white,
        accent: Color(red: 0.82, green: 0.09, blue: 0.15),
        muted: Color(white: 0.62),
        panel: Color(white: 0.07),
        uiCanvas: UIColor(white: 0.02, alpha: 1),
        uiInk: .white,
        uiAccent: UIColor(red: 0.82, green: 0.09, blue: 0.15, alpha: 1)
    )

    static let chalkBleed = BrutalistThemePalette(
        canvas: Color(white: 0.96),
        ink: Color(white: 0.04),
        accent: Color(red: 0.82, green: 0.09, blue: 0.15),
        muted: Color(white: 0.32),
        panel: Color.white,
        uiCanvas: UIColor(white: 0.96, alpha: 1),
        uiInk: UIColor(white: 0.04, alpha: 1),
        uiAccent: UIColor(red: 0.82, green: 0.09, blue: 0.15, alpha: 1)
    )

    static let crimsonField = BrutalistThemePalette(
        canvas: Color(red: 0.10, green: 0.00, blue: 0.00),
        ink: Color(red: 1.00, green: 0.91, blue: 0.91),
        accent: Color(red: 1.00, green: 0.12, blue: 0.16),
        muted: Color(red: 0.72, green: 0.42, blue: 0.42),
        panel: Color(red: 0.18, green: 0.02, blue: 0.02),
        uiCanvas: UIColor(red: 0.10, green: 0.00, blue: 0.00, alpha: 1),
        uiInk: UIColor(red: 1.00, green: 0.91, blue: 0.91, alpha: 1),
        uiAccent: UIColor(red: 1.00, green: 0.12, blue: 0.16, alpha: 1)
    )

    static func palette(for identifier: BrutalistThemeIdentifier) -> BrutalistThemePalette {
        switch identifier {
        case .voidGrid: return .voidGrid
        case .chalkBleed: return .chalkBleed
        case .crimsonField: return .crimsonField
        }
    }
}

struct LayoutDensityProfile: Equatable {
    var stackSpacing: CGFloat
    var inset: CGFloat
    var captionSize: CGFloat
    var bodySize: CGFloat
    var titleSize: CGFloat
    var readoutSize: CGFloat

    static func profile(for identifier: LayoutDensityIdentifier) -> LayoutDensityProfile {
        switch identifier {
        case .compressed:
            return LayoutDensityProfile(stackSpacing: 6, inset: 10, captionSize: 11, bodySize: 13, titleSize: 18, readoutSize: 28)
        case .standard:
            return LayoutDensityProfile(stackSpacing: 12, inset: 14, captionSize: 12, bodySize: 14, titleSize: 22, readoutSize: 36)
        case .expanded:
            return LayoutDensityProfile(stackSpacing: 18, inset: 18, captionSize: 14, bodySize: 16, titleSize: 26, readoutSize: 42)
        }
    }
}

private struct BrutalistThemeKey: EnvironmentKey {
    static let defaultValue = BrutalistThemePalette.voidGrid
}

private struct LayoutDensityKey: EnvironmentKey {
    static let defaultValue = LayoutDensityProfile.profile(for: .standard)
}

extension EnvironmentValues {
    var brutalistTheme: BrutalistThemePalette {
        get { self[BrutalistThemeKey.self] }
        set { self[BrutalistThemeKey.self] = newValue }
    }

    var layoutDensity: LayoutDensityProfile {
        get { self[LayoutDensityKey.self] }
        set { self[LayoutDensityKey.self] = newValue }
    }
}
