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
}
