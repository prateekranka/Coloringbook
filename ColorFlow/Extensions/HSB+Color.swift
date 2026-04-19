import SwiftUI
import UIKit

// MARK: - HSB <-> Color bridge

extension Color {
    /// Convenience init matching SwiftUI's built-in `Color(hue:saturation:brightness:)` but
    /// spelled so callers can write `.init(h:s:b:)` for compact HSB expressions.
    init(h: Double, s: Double, b: Double, opacity: Double = 1) {
        self.init(hue: h, saturation: s, brightness: b, opacity: opacity)
    }

    /// Decomposes the color into HSB components via UIColor, in sRGB.
    /// Returns (0,0,0) for colors whose space cannot produce HSB.
    var hsb: (h: Double, s: Double, b: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return (Double(h), Double(s), Double(br))
    }
}
