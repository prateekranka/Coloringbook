import SwiftUI

enum MoodCategory: String, CaseIterable, Identifiable, Hashable {
    case calm
    case bold
    case playful
    case dreamy
    case wild
    case noir

    var id: Self { self }

    var title: String {
        rawValue.uppercased()
    }

    var accentHex: String {
        switch self {
        case .calm:
            return "#2BBCB3"
        case .bold:
            return "#E91E84"
        case .playful:
            return "#F5C518"
        case .dreamy:
            return "#7B68AE"
        case .wild:
            return "#E8611A"
        case .noir:
            return "#8B1A1A"
        }
    }

    var accentColor: Color {
        Color(hex: accentHex)
    }
}
