import SwiftUI

/// Central design token system for ColorFlow.
/// All views should pull colours, type, and metrics from here — never hardcode.
enum AppTheme {

    // MARK: - Background layers

    /// The deepest background (#1C1C1E).
    static let background       = Color(red: 0.110, green: 0.110, blue: 0.118)

    /// Elevated surface used for cards, sheets, sidebar (#2C2C2E).
    static let surface          = Color(red: 0.173, green: 0.173, blue: 0.180)

    /// A second elevation level used for floating toolbars/sheets (#3A3A3C).
    static let surfaceElevated  = Color(red: 0.227, green: 0.227, blue: 0.235)

    /// Pure white — used as the card face for template/artwork thumbnails.
    static let cardFace         = Color.white

    // MARK: - Brand accent

    /// Primary purple (#7B5FE8). Used for active tab, buttons, selection indicators.
    static let accent           = Color(red: 0.482, green: 0.373, blue: 0.910)

    /// Secondary pink for gradients paired with accent (#E879F9).
    static let accentSecondary  = Color(red: 0.910, green: 0.475, blue: 0.976)

    /// Gradient used for feature heroes and primary CTAs.
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle radial glow used behind hero imagery.
    static let heroGlow = RadialGradient(
        colors: [accent.opacity(0.35), .clear],
        center: .topLeading,
        startRadius: 20,
        endRadius: 320
    )

    // MARK: - Text

    static let textPrimary      = Color.white
    static let textSecondary    = Color(white: 0.65)
    static let textTertiary     = Color(white: 0.45)

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 14
    static let heroCornerRadius: CGFloat = 22
    static let screenPadding:    CGFloat = 16

    /// Minimum hit-target edge per Apple HIG.
    /// Icon-only controls must frame to at least this size.
    static let minTapTarget:     CGFloat = 44

    // MARK: - Shadows

    /// Subtle card shadow used on thumbnails.
    static func cardShadow() -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (Color.black.opacity(0.28), 8, 0, 4)
    }

    /// Deeper shadow for floating glass toolbars.
    static func floatingShadow() -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (Color.black.opacity(0.32), 16, 0, 6)
    }

    // MARK: - Typography

    /// Serif display font for large titles and editorial headers. Uses Apple's
    /// built-in "New York" (SF Serif) so no custom font file is required.
    static func displayFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Sans body font for descriptions and labels — matches the system default but
    /// centralised so we can tune weight/width in one place later.
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - View modifiers

extension View {
    /// Applies the standard card shadow used on thumbnails.
    func cardShadow() -> some View {
        let s = AppTheme.cardShadow()
        return shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    /// Applies the heavier floating-toolbar shadow.
    func floatingShadow() -> some View {
        let s = AppTheme.floatingShadow()
        return shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}
