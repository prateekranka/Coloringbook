import SwiftUI

/// Central design token system for ColorFlow.
/// All views should pull colours and metrics from here — never hardcode.
enum AppTheme {

    // MARK: - Background layers

    /// The deepest background (#1C1C1E).
    static let background       = Color(red: 0.110, green: 0.110, blue: 0.118)

    /// Elevated surface used for cards, sheets, sidebar (#2C2C2E).
    static let surface          = Color(red: 0.173, green: 0.173, blue: 0.180)

    /// Pure white — used as the card face for template/artwork thumbnails.
    static let cardFace         = Color.white

    // MARK: - Brand accent

    /// Primary purple (#7B5FE8).  Used for active tab, buttons, selection indicators.
    static let accent           = Color(red: 0.482, green: 0.373, blue: 0.910)

    // MARK: - Text

    static let textPrimary      = Color.white
    static let textSecondary    = Color(white: 0.65)

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 14
    static let screenPadding:    CGFloat = 16

    /// Minimum hit-target edge per Apple HIG.
    /// Icon-only controls must frame to at least this size.
    static let minTapTarget:     CGFloat = 44

    // MARK: - Motion

    enum Motion {
        static let quickSpring:    Animation = .spring(response: 0.35, dampingFraction: 0.75)
        static let bloomSpring:    Animation = .spring(response: 0.55, dampingFraction: 0.62)
        static let pageTransition: Animation = .spring(response: 0.45, dampingFraction: 0.85)
        static let staggerBase:    Double    = 0.025
    }

    // MARK: - Typography

    enum Typography {
        static let heroTitle     = Font.system(size: 34, weight: .bold,     design: .rounded)
        static let heroBody      = Font.system(size: 17, weight: .regular)
        static let capsuleLabel  = Font.system(size: 13, weight: .semibold, design: .rounded)
    }
}

// MARK: - Glow modifier

/// A soft, colored outer bloom rendered behind the modified view.
/// Used by swatches, page dots, and onboarding hero elements.
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
    /// Adds a soft colored glow behind the view.
    /// - Parameters:
    ///   - color: The glow tint. Defaults to the view's own colors when used on filled shapes.
    ///   - radius: Blur radius in points. 8–14 suits most glyph/swatch bloom.
    func glow(color: Color, radius: CGFloat = 12) -> some View {
        self.modifier(GlowModifier(color: color, radius: radius))
    }
}
