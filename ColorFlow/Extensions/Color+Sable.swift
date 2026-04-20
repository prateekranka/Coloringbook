import SwiftUI
import UIKit

extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    static func adaptive(light: String, dark: String) -> Color {
        adaptive(light: Color(hex: light), dark: Color(hex: dark))
    }

    static func adaptiveOpacity(light: String, dark: String) -> Color {
        let lightColor = Color(hex: light)
        let darkColor = Color(hex: dark)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(darkColor) : UIColor(lightColor)
        })
    }
}

extension UIColor {
    convenience init(hexWithAlpha: String) {
        let hex = hexWithAlpha.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: CGFloat
        switch hex.count {
        case 8:
            r = CGFloat((int >> 16) & 0xFF) / 255
            g = CGFloat((int >> 8) & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
            a = CGFloat((int >> 24) & 0xFF) / 255
        case 6:
            r = CGFloat((int >> 16) & 0xFF) / 255
            g = CGFloat((int >> 8) & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
            a = 1.0
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}