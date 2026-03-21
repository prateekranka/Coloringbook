import SwiftUI

/// Central design token system for ColorFlow.
/// All views should pull colours and metrics from here — never hardcode.
enum AppTheme {

    // MARK: - Background layers

    /// The deepest background (#1C1C1E — iOS system "grouped background" in dark).
    static let background       = Color("CFBackground")

    /// Elevated surface used for cards, sheets, sidebar (#2C2C2E).
    static let surface          = Color("CFSurface")

    /// Pure white — used as the card face for template/artwork thumbnails.
    static let cardFace         = Color.white

    // MARK: - Brand accent

    /// Primary purple (#7B5FE8).  Used for active tab, buttons, selection indicators.
    static let accent           = Color("CFAccent")

    // MARK: - Text

    static let textPrimary      = Color.white
    static let textSecondary    = Color(white: 0.65)

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 14
    static let screenPadding:    CGFloat = 16
}
