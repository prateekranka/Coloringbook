import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case fill
    case pencil
    case save

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fill:   return "Tap to Fill"
        case .pencil: return "Draw with Apple Pencil"
        case .save:   return "Your work, saved"
        }
    }

    var body: String {
        switch self {
        case .fill:
            return "Tap any enclosed region to instantly fill it with colour."
        case .pencil:
            return "Add fine detail with pressure-sensitive, pencil-accurate strokes."
        case .save:
            return "Every change saves automatically. Pick up right where you left off."
        }
    }

    var ctaLabel: String {
        switch self {
        case .fill, .pencil: return "Continue"
        case .save:          return "Start Coloring"
        }
    }

    /// Gradient accent used for the step's hero and subtle background shift.
    var accent: Color {
        switch self {
        case .fill:   return Color(hue: 0.58, saturation: 0.55, brightness: 0.95)   // cyan-blue
        case .pencil: return AppTheme.Brand.accent                                   // brand purple
        case .save:   return Color(hue: 0.38, saturation: 0.55, brightness: 0.85)   // minty green
        }
    }
}
