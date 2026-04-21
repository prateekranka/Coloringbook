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

