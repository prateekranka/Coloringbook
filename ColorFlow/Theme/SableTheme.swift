import SwiftUI

enum SableTheme {
    static let creamHex = "#F5F0EB"
    static let charcoalHex = "#171615"
    static let crimsonHex = "#D4213D"
    static let progressPinkHex = "#FF2D78"
    static let gouachePaperHex = "#F6EFE3"
    static let gouacheInkHex = "#2C2A27"
    static let gouacheNightHex = "#101211"

    static let cream = Color(hex: creamHex)
    static let crimson = Color(hex: crimsonHex)
    static let progressPink = Color(hex: progressPinkHex)
    static let ink = Color(hex: "#080808")
    static let softInk = Color(hex: "#2A2523")
    static let mutedInk = Color(hex: "#6F6660")
    static let cardBlack = Color(hex: "#090909")
    static let paper = Color(hex: "#FFFDF8")
    static let peach = Color(hex: "#F5B177")
    static let blush = Color(hex: "#F4A39A")
    static let sage = Color(hex: "#DCE5D2")
    static let butter = Color(hex: "#F6CF85")
    static let lavender = Color(hex: "#D8CAD9")
    static let mist = Color(hex: "#C9D1D4")
    static let hairline = Color.black.opacity(0.14)

    enum Radius {
        static let card: CGFloat = 8
        static let pill: CGFloat = 999
        static let tabBar: CGFloat = 30
    }

    enum Spacing {
        static let pageInset: CGFloat = 40
        static let section: CGFloat = 12
        static let cardGap: CGFloat = 18
    }

    enum Font {
        static let brand = SwiftUI.Font.custom("Fraunces", size: 38).weight(.black)
        static let hero = SwiftUI.Font.custom("Fraunces", size: 88).weight(.black)
        static let sectionTitle = SwiftUI.Font.custom("Fraunces", size: 27).weight(.black)
        static let cardSerif = SwiftUI.Font.custom("Fraunces", size: 20).weight(.semibold)
        static let badge = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let cardTitle = SwiftUI.Font.system(size: 16, weight: .medium)
        static let pill = SwiftUI.Font.system(size: 12, weight: .semibold)
    }

    static let cardShadow = Color.black.opacity(0.12)

    static func appBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: charcoalHex) : cream
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#24211F") : Color.white.opacity(0.82)
    }

    static func elevatedSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#302B28") : Color.white.opacity(0.9)
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#FFF8F0") : ink
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#C8BDB2") : mutedInk
    }

    static func hairline(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : hairline
    }

    static func gouacheBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: gouacheNightHex) : Color(hex: gouachePaperHex)
    }

    static func gouachePrimaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#EFE3D2") : Color(hex: gouacheInkHex)
    }

    static func gouacheSecondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#B5AA9A") : Color(hex: "#6D655E")
    }

    static func gouachePanel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#191A18") : Color(hex: "#FFF9EF")
    }

    static func gouacheHairline(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.12)
    }

    static func gouacheCardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.42) : Color.black.opacity(0.12)
    }

    static func warmPaper(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#151614") : Color(hex: gouachePaperHex)
    }

    static func canvasBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#0F1110") : Color(hex: "#F4ECDF")
    }

    static func canvasChrome(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#1D1E1B").opacity(0.92) : Color(hex: "#FFF8ED").opacity(0.94)
    }

    static func cardSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#20211E") : Color(hex: "#FFF9F0")
    }

    static func divider(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.12)
    }

    static func selectedSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#EFE1D0") : Color(hex: "#2C2A27")
    }

    static func selectedText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#171615") : Color.white
    }

    static func disabledText(for colorScheme: ColorScheme) -> Color {
        secondaryText(for: colorScheme).opacity(0.48)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.14)
    }

    static func fraunces(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
        SwiftUI.Font.custom("Fraunces", size: size).weight(weight)
    }
}
