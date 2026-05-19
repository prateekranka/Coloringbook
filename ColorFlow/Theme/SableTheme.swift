import SwiftUI

enum SableTheme {
    // MARK: - Color Hex Constants

    static let creamHex = "#F5F0EB"
    static let charcoalHex = "#171615"
    static let crimsonHex = "#D4213D"
    static let progressPinkHex = "#FF2D78"
    static let gouachePaperHex = "#F6EFE3"
    static let gouacheInkHex = "#2C2A27"
    static let gouacheNightHex = "#101211"

    // MARK: - Static Color Properties (Existing)

    static let cream = Color(hex: creamHex)
    static let crimson = Color(hex: crimsonHex)
    static let progressPink = Color(hex: progressPinkHex)
    static let hotPink = Color(hex: "#FF2D78")
    static let ink = Color(hex: "#080808")
    static let inkBlack = Color(hex: "#080808")
    static let softInk = Color(hex: "#2A2523")
    static let mutedInk = Color(hex: "#6F6660")
    static let cardBlack = Color(hex: "#090909")
    static let paper = Color(hex: "#FFFDF8")
    static let warmCream = Color(hex: "#FFFDF8")
    static let peach = Color(hex: "#F5B177")
    static let blush = Color(hex: "#F4A39A")
    static let sage = Color(hex: "#DCE5D2")
    static let butter = Color(hex: "#F6CF85")
    static let lavender = Color(hex: "#D8CAD9")
    static let mist = Color(hex: "#C9D1D4")
    static let hairline = Color.black.opacity(0.14)
    static let cardShadow = Color.black.opacity(0.12)

    // MARK: - New Collection Card Tint Colors

    static let collectionTintSage = Color(hex: "#A8B19F")
    static let collectionTintBlush = Color(hex: "#E9BDA8")
    static let collectionTintGold = Color(hex: "#E49B3D")
    static let collectionTintTeal = Color(hex: "#B6C6C8")

    // MARK: - New Mood Wash Colors

    static let moodWashCalm1 = Color(hex: "#E3C98E")
    static let moodWashCalm2 = Color(hex: "#9EB1A8")
    static let moodWashCalm3 = Color(hex: "#EEE4C8")
    static let moodWashBold1 = Color(hex: "#082135")
    static let moodWashBold2 = Color(hex: "#F0D8AF")
    static let moodWashBold3 = Color(hex: "#D96B2A")
    static let moodWashBold4 = Color(hex: "#B4AD8C")
    static let moodWashDreamy1 = Color(hex: "#E89A9C")
    static let moodWashDreamy2 = Color(hex: "#D5B4D8")
    static let moodWashDreamy3 = Color(hex: "#F1A56F")
    static let moodWashDreamy4 = Color(hex: "#F5D59F")
    static let moodWashFocus1 = Color(hex: "#73815E")
    static let moodWashFocus2 = Color(hex: "#DBD0B4")
    static let moodWashFocus3 = Color(hex: "#EFE4C7")
    static let moodWashFocus4 = Color(hex: "#293D34")

    // MARK: - New Progress Gradient Colors

    static let progressGradientStart = Color(hex: "#F07D78")
    static let progressGradientEnd = Color(hex: "#F4A277")

    // MARK: - New Hero Colors

    static let heroTitleDark = Color(hex: "#FFF4E2")

    // MARK: - New Control Fill Colors

    static let controlFillDark = Color(hex: "#1D1D1B").opacity(0.92)
    static let controlFillLight = Color(hex: "#F8F0E7").opacity(0.92)
    static let searchFillDark = Color(hex: "#1C1C1A").opacity(0.88)
    static let searchFillLight = Color(hex: "#F8F1E8").opacity(0.86)
    static let cardFooterDark = Color(hex: "#1C1B18").opacity(0.98)
    static let cardFooterLight = Color(hex: "#FBF4EA").opacity(0.98)

    // MARK: - New Collection Panel Fills

    static let collectionPanelDark = Color(hex: "#22231F")
    static let collectionPanelSageLight = Color(hex: "#D8DDCE").opacity(0.92)
    static let collectionPanelBlushLight = Color(hex: "#F0CDBF").opacity(0.88)
    static let collectionPanelGoldLight = Color(hex: "#E8A641").opacity(0.90)
    static let collectionPanelTealLight = Color(hex: "#D6E0DE").opacity(0.90)

    // MARK: - New Chip Colors

    static let chipForegroundDark = Color(hex: "#F2E6D6")
    static let chipForegroundLight = Color(hex: "#5E554C")

    // MARK: - Typography Scale

    enum Typography {
        // Brand
        static let display = SwiftUI.Font.custom("Fraunces", size: 88).weight(.black)
        static let brand = SwiftUI.Font.custom("Fraunces", size: 38).weight(.black)
        static let hero = SwiftUI.Font.custom("Fraunces", size: 66).weight(.regular)
        static let heroLandscape = SwiftUI.Font.custom("Fraunces", size: 64).weight(.regular)

        // Headings
        static let sectionTitle = SwiftUI.Font.custom("Fraunces", size: 27).weight(.black)
        static let sectionHeader = SwiftUI.Font.custom("Fraunces", size: 24).weight(.regular)
        static let cardSerif = SwiftUI.Font.custom("Fraunces", size: 20).weight(.semibold)

        // Body
        static let bodyLarge = SwiftUI.Font.system(size: 17, weight: .regular)
        static let bodyMedium = SwiftUI.Font.system(size: 16, weight: .medium)
        static let bodySmall = SwiftUI.Font.system(size: 14, weight: .regular)

        // Labels
        static let labelLarge = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let labelMedium = SwiftUI.Font.system(size: 13, weight: .medium)
        static let labelSmall = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let labelTiny = SwiftUI.Font.system(size: 11, weight: .medium)

        // Pills & Chips
        static let pill = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let chip = SwiftUI.Font.system(size: 10, weight: .medium)

        // Badge
        static let badge = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let cardTitle = SwiftUI.Font.system(size: 16, weight: .medium)

        // Helper
        static func fraunces(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            SwiftUI.Font.custom("Fraunces", size: size).weight(weight)
        }
    }

    // MARK: - Deprecated Font Alias (backwards compatibility)

    @available(*, deprecated, renamed: "Typography")
    enum Font {
        static let brand = Typography.brand
        static let hero = Typography.display
        static let sectionTitle = Typography.sectionTitle
        static let cardSerif = Typography.cardSerif
        static let badge = Typography.badge
        static let cardTitle = Typography.cardTitle
        static let pill = Typography.pill
    }

    // MARK: - Spacing Scale

    enum Spacing {
        static let xxxs: CGFloat = 4
        static let xxs: CGFloat = 6
        static let xs: CGFloat = 8
        static let sm: CGFloat = 10
        static let md: CGFloat = 12
        static let lg: CGFloat = 14
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 18
        static let xxxl: CGFloat = 22
        static let pageInset: CGFloat = 40
        static let section: CGFloat = 12
        static let cardGap: CGFloat = 18
        static let sectionGap: CGFloat = 22
        static let sectionGapLandscape: CGFloat = 19
        static let sectionHeaderGap: CGFloat = 15
        static let sectionHeaderGapLandscape: CGFloat = 12
        static let topPaddingPortrait: CGFloat = 14
        static let topPaddingLandscape: CGFloat = 10
        static let bottomPadding: CGFloat = 122
        static let tabBarBottomPadding: CGFloat = 18
        static let tabBarHorizontalPadding: CGFloat = 32
        static let contentAboveTabBar: CGFloat = 86
    }

    // MARK: - Corner Radius Scale

    enum Radius {
        static let tight: CGFloat = 6
        static let card: CGFloat = 8
        static let cardLarge: CGFloat = 10
        static let collectionCard: CGFloat = 9
        static let pill: CGFloat = 999
        static let tabBar: CGFloat = 30
        static let continuousCard: CGFloat = 10
        static let continuousCollection: CGFloat = 9
    }

    // MARK: - Shadow Scale

    enum Shadow {
        static func card(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (SableTheme.gouacheCardShadow(for: colorScheme), 10, 0, 5)
        }
        static func cardSmall(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (SableTheme.gouacheCardShadow(for: colorScheme), 7, 0, 4)
        }
        static func cardMedium(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (SableTheme.gouacheCardShadow(for: colorScheme), 8, 0, 4)
        }
        static func tabBar(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(0.18), 14, 0, 6)
        }
        static func searchPill(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (SableTheme.gouacheCardShadow(for: colorScheme).opacity(0.35), 12, 0, 4)
        }
        static func floatingPanel(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12), 18, 0, 10)
        }
        static func canvasArtwork(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (SableTheme.shadow(for: colorScheme), 18, 0, 10)
        }
        static func canvasDock(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (SableTheme.shadow(for: colorScheme), 14, 0, 7)
        }
        static func canvasHeader(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (SableTheme.shadow(for: colorScheme), 12, 0, 5)
        }
        static func paintDab(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(0.16), 5, 0, 3)
        }
        static func heroTitle(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (.black.opacity(colorScheme == .dark ? 0.72 : 0.18), colorScheme == .dark ? 9 : 4, 0, 3)
        }
    }

    // MARK: - Motion / Timing Tokens

    enum Motion {
        static let slowFade = Animation.easeInOut(duration: 0.35)
        static let gentleFade = Animation.easeOut(duration: 0.25)
        static let quickFade = Animation.easeOut(duration: 0.15)

        static let cardPress = Animation.spring(response: 0.25, dampingFraction: 0.88)
        static let cardLift = Animation.spring(response: 0.30, dampingFraction: 0.86)

        static let searchExpand = Animation.spring(response: 0.34, dampingFraction: 0.86)

        static let panelToggle = Animation.spring(response: 0.24, dampingFraction: 0.86)

        static let segmentSwitch = Animation.easeInOut(duration: 0.18)

        static let fillShow = Animation.easeOut(duration: 0.15)
        static let fillDismiss = Animation.easeOut(duration: 0.20)

        static let gestureTipDismiss = Animation.easeOut(duration: 0.18)

        static let profileScroll = Animation.snappy(duration: 0.28)

        static let canvasFocusToggle = Animation.easeInOut(duration: 0.20)
    }

    // MARK: - Border / Hairline Tokens

    enum Border {
        static let hairlineWidth: CGFloat = 1
        static func hairlineColor(for colorScheme: ColorScheme) -> Color {
            SableTheme.hairline(for: colorScheme)
        }
        static func gouacheHairline(for colorScheme: ColorScheme) -> Color {
            SableTheme.gouacheHairline(for: colorScheme)
        }
        static func divider(for colorScheme: ColorScheme) -> Color {
            SableTheme.divider(for: colorScheme)
        }
    }

    // MARK: - Paper Texture Treatment

    enum PaperTexture {
        static let fiberCount = 190
        static let speckCount = 65
        static let fiberOpacityDark: Double = 0.055
        static let fiberOpacityLight: Double = 0.08
        static let speckOpacityDark: Double = 0.12
        static let speckOpacityLight: Double = 0.14
        static let fiberWidth: CGFloat = 1
        static let maxFiberLength: CGFloat = 80
    }

    // MARK: - Ink / Paint Accent Treatment

    enum InkPaint {
        static let inkColor = Color(hex: "#080808")
        static let softInk = Color(hex: "#2A2523")
        static let mutedInk = Color(hex: "#6F6660")
        static let accentPink = Color(hex: "#FF2D78")
        static let warmPaperLight = Color(hex: "#F6EFE3")
        static let warmPaperDark = Color(hex: "#151614")
    }

    // MARK: - Collection Tint Palette

    enum CollectionTints {
        static let all: [Color] = [
            collectionTintSage,
            collectionTintBlush,
            collectionTintGold,
            collectionTintTeal
        ]
        static func forIndex(_ index: Int) -> Color {
            all[index % all.count]
        }
    }

    // MARK: - Mood Wash Palette

    enum MoodWashes {
        static let calm: [Color] = [moodWashCalm1, moodWashCalm2, moodWashCalm3]
        static let bold: [Color] = [moodWashBold1, moodWashBold2, moodWashBold3, moodWashBold4]
        static let dreamy: [Color] = [moodWashDreamy1, moodWashDreamy2, moodWashDreamy3, moodWashDreamy4]
        static let focus: [Color] = [moodWashFocus1, moodWashFocus2, moodWashFocus3, moodWashFocus4]
    }

    // MARK: - Theme Functions (Existing)

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
