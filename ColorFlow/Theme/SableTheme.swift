import SwiftUI

enum SableTheme {
    static let creamHex = "#F5F0EB"
    static let crimsonHex = "#D4213D"
    static let progressPinkHex = "#FF2D78"

    static let cream = Color(hex: creamHex)
    static let crimson = Color(hex: crimsonHex)
    static let progressPink = Color(hex: progressPinkHex)
    static let ink = Color(hex: "#080808")
    static let softInk = Color(hex: "#2A2523")
    static let mutedInk = Color(hex: "#6F6660")
    static let cardBlack = Color(hex: "#090909")
    static let paper = Color(hex: "#FFFDF8")
    static let hairline = Color.black.opacity(0.14)

    enum Radius {
        static let card: CGFloat = 8
        static let pill: CGFloat = 999
        static let tabBar: CGFloat = 30
    }

    enum Spacing {
        static let pageInset: CGFloat = 28
        static let section: CGFloat = 18
        static let cardGap: CGFloat = 12
    }

    enum Font {
        static let hero = SwiftUI.Font.system(size: 86, weight: .black)
        static let heroSubtitle = SwiftUI.Font.system(size: 23, weight: .black)
        static let badge = SwiftUI.Font.system(size: 18, weight: .black)
        static let cardTitle = SwiftUI.Font.system(size: 16, weight: .bold)
        static let pill = SwiftUI.Font.system(size: 12, weight: .black)
    }

    static let cardShadow = Color.black.opacity(0.24)
}
