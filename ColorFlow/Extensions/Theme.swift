import SwiftUI
import UIKit

enum AccentVariant: String, CaseIterable {
    case sage = "sage"
    case coral = "coral"
}

enum AppTheme {

    // MARK: - Brand

    enum Brand {
        static var accent: Color {
            AdaptiveAccent.accentColor
        }
        static var accentPressed: Color {
            AdaptiveAccent.accentPressedColor
        }
        static var accentHover: Color {
            AdaptiveAccent.accentHoverColor
        }
        static var accentSubtle: Color {
            AdaptiveAccent.accentSubtleColor
        }
        static var accentWash: Color {
            AdaptiveAccent.accentWashColor
        }
        static var onAccent: Color {
            AdaptiveAccent.onAccentColor
        }
    }

    // MARK: - Surface

    enum Surface {
        static let background = Color.adaptive(light: "#FFFFFF", dark: "#151210")
        static let canvas     = Color.adaptive(light: "#FAFAF7", dark: "#1E1A17")
        static let sheet      = Color.adaptive(light: "#FFFFFF", dark: "#1C1915")
        static let elevated   = Color.adaptive(light: "#F2F2F7", dark: "#2A2520")
        static let scrim      = Color.adaptiveOpacity(light: "#00000026", dark: "#00000066")
    }

    // MARK: - Ink

    enum Ink {
        static let primary   = Color.adaptive(light: "#1A1A1A", dark: "#F5EFE6")
        static let secondary = Color.adaptive(light: "#6B625A", dark: "#B8AFA3")
        static let tertiary  = Color.adaptive(light: "#9A9187", dark: "#7A7268")
        static let lineArt   = Color.adaptive(light: "#1A1A1A", dark: "#F5EFE6")
    }

    // MARK: - Stroke

    enum Stroke {
        static let hairline       = Color.adaptiveOpacity(light: "#1A1A1A1F", dark: "#F5EFE61F")
        static let swatchBorder   = Color.adaptiveOpacity(light: "#00000040", dark: "#FFFFFF2E")
        static let previewBorder  = Color.adaptiveOpacity(light: "#00000033", dark: "#FFFFFF26")
    }

    // MARK: - State

    enum State {
        static let success = Color(hex: "#6DB33F")
        static let warning = Color(hex: "#FFBF00")
        static let danger  = Color(hex: "#E63946")
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 6
        static let md: CGFloat  = 8
        static let lg: CGFloat  = 12
        static let xl: CGFloat  = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
    }

    // MARK: - Size

    enum Size {
        static let touchTarget: CGFloat    = 44
        static let toolButton: CGFloat     = 40
        static let colorWell: CGFloat      = 32
        static let swatchCell: CGFloat     = 44
        static let dotIndicator: CGFloat   = 8
        static let brushPreviewMax: CGFloat = 24
        static let emptyStateIcon: CGFloat = 64
        static let onboardingIconBox: CGFloat = 120
    }

    // MARK: - Motion

    enum Motion {
        static let fast: Animation    = .easeInOut(duration: 0.15)
        static let standard: Animation = .easeInOut(duration: 0.22)
        static let slow: Animation     = .easeInOut(duration: 0.35)
        static let emphasis: Animation = .spring(response: 0.35, dampingFraction: 0.8)

        static let quickSpring:    Animation = .spring(response: 0.35, dampingFraction: 0.75)
        static let bloomSpring:    Animation = .spring(response: 0.55, dampingFraction: 0.62)
        static let pageTransition: Animation = .spring(response: 0.45, dampingFraction: 0.85)
        static let staggerBase:    Double    = 0.025
    }

    // MARK: - Typography

    enum Typography {
        static let heroTitle     = Font.cfDisplayHero
        static let heroBody      = Font.body
        static let capsuleLabel  = Font.system(size: 13, weight: .semibold, design: .rounded)
    }

    // MARK: - Backwards-compat shims

    static var accent: Color { Brand.accent }
    static var background: Color { Surface.background }
    static var surface: Color { Surface.elevated }
    static var cardFace: Color { Surface.elevated }
    static var textPrimary: Color { Ink.primary }
    static var textSecondary: Color { Ink.secondary }
    static var cardCornerRadius: CGFloat { Radius.md }
    static var screenPadding: CGFloat { Spacing.xl }
    static var minTapTarget: CGFloat { Size.touchTarget }
}

// MARK: - Adaptive Accent Resolution

private enum AdaptiveAccent {
    private static var currentVariant: AccentVariant {
        AccentVariant(rawValue: UserDefaults.standard.string(forKey: "accentVariant") ?? "") ?? .sage
    }

    private static let sageLight    = "#6E9E7A"
    private static let sageDark     = "#7AB887"
    private static let sagePressedL = "#547A60"
    private static let sagePressedD = "#5E9469"
    private static let sageHoverL   = "#89B994"
    private static let sageHoverD    = "#96C9A2"
    private static let sageSubtleL  = "#6E9E7A26"
    private static let sageSubtleD   = "#7AB8872E"
    private static let sageWashL    = "#6E9E7A0D"
    private static let sageWashD     = "#7AB88714"
    private static let sageOnAccentL = "#FFFFFF"
    private static let sageOnAccentD = "#0F1F13"

    private static let coralLight    = "#E86A4A"
    private static let coralDark     = "#F07A5C"
    private static let coralPressedL = "#C75537"
    private static let coralPressedD = "#D8614A"
    private static let coralHoverL   = "#EE8366"
    private static let coralHoverD    = "#F59076"
    private static let coralSubtleL  = "#E86A4A26"
    private static let coralSubtleD   = "#F07A5C2E"
    private static let coralWashL    = "#E86A4A0D"
    private static let coralWashD     = "#F07A5C14"
    private static let coralOnAccentL = "#FFFFFF"
    private static let coralOnAccentD = "#1A1613"

    static var accentColor: Color {
        currentVariant == .coral
            ? Color.adaptive(light: coralLight, dark: coralDark)
            : Color.adaptive(light: sageLight, dark: sageDark)
    }

    static var accentPressedColor: Color {
        currentVariant == .coral
            ? Color.adaptive(light: coralPressedL, dark: coralPressedD)
            : Color.adaptive(light: sagePressedL, dark: sagePressedD)
    }

    static var accentHoverColor: Color {
        currentVariant == .coral
            ? Color.adaptive(light: coralHoverL, dark: coralHoverD)
            : Color.adaptive(light: sageHoverL, dark: sageHoverD)
    }

    static var accentSubtleColor: Color {
        currentVariant == .coral
            ? Color.adaptiveOpacity(light: coralSubtleL, dark: coralSubtleD)
            : Color.adaptiveOpacity(light: sageSubtleL, dark: sageSubtleD)
    }

    static var accentWashColor: Color {
        currentVariant == .coral
            ? Color.adaptiveOpacity(light: coralWashL, dark: coralWashD)
            : Color.adaptiveOpacity(light: sageWashL, dark: sageWashD)
    }

    static var onAccentColor: Color {
        currentVariant == .coral
            ? Color.adaptive(light: coralOnAccentL, dark: coralOnAccentD)
            : Color.adaptive(light: sageOnAccentL, dark: sageOnAccentD)
    }
}

// MARK: - Glow Modifier

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                content
                    .blur(radius: radius)
                    .opacity(0.85)
            )
            .compositingGroup()
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 12) -> some View {
        self.modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Appearance Preference

enum AppearancePreference: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}