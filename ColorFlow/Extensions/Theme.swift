import SwiftUI

/// Central design token system for ColorFlow.
/// All views should pull colours and metrics from here — never hardcode.
enum AppTheme {

    // MARK: - Background layers

    /// The deepest background — dark: #1C1C1E, light: systemGroupedBackground.
    static let background = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
            : UIColor.systemGroupedBackground
    })

    /// Elevated surface — dark: #2C2C2E, light: secondarySystemGroupedBackground.
    static let surface = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1)
            : UIColor.secondarySystemGroupedBackground
    })

    /// Pure white — used as the card face for template/artwork thumbnails.
    static let cardFace = Color.white

    // MARK: - Brand accent

    /// Primary purple (#7B5FE8).  Used for active tab, buttons, selection indicators.
    static let accent = Color(red: 0.482, green: 0.373, blue: 0.910)

    // MARK: - Text

    static let textPrimary   = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)

    // MARK: - Spacing scale

    static let spacingXS:  CGFloat =  4
    static let spacingSM:  CGFloat =  8
    static let spacingMD:  CGFloat = 12
    static let spacingLG:  CGFloat = 16   // == screenPadding
    static let spacingXL:  CGFloat = 24
    static let spacing2XL: CGFloat = 32

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 14
    static let screenPadding:    CGFloat = 16
}

// MARK: - Shadow view modifiers

extension View {
    /// Subtle card shadow: black 12% opacity, radius 4, y-offset 2.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    /// Heavier artwork card shadow: black 25% opacity, radius 4, y-offset 2.
    func heavyShadow() -> some View {
        shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}
