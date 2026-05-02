import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case stayInLines
    case multipleTools
    case iCloudSync

    var id: Int { rawValue }

    /// Short uppercase eyebrow above the title.
    var eyebrow: String {
        switch self {
        case .stayInLines:    return "Stay in the lines"
        case .multipleTools:  return "A tool for every mood"
        case .iCloudSync:     return "Synced to iCloud"
        }
    }

    /// Display headline (no trailing full stop — Sable rule).
    var title: String {
        switch self {
        case .stayInLines:    return "Color outside, stay inside"
        case .multipleTools:  return "Four tools, all Pencil-native"
        case .iCloudSync:     return "Never lose a stroke"
        }
    }

    var body: String {
        switch self {
        case .stayInLines:
            return "Sable clips every stroke to the region you’re in. Sweep wildly across the page — only the inside takes the paint."
        case .multipleTools:
            return "Pencil, marker, watercolor, flood fill. Each reads pressure and tilt so the line on screen feels like the one in your hand."
        case .iCloudSync:
            return "Every piece syncs to iCloud the moment you set the Pencil down. Pick up on iPhone, finish on iPad — the work follows you."
        }
    }

    var ctaLabel: String {
        switch self {
        case .stayInLines, .multipleTools: return "Continue"
        case .iCloudSync:                  return "Start coloring"
        }
    }

    /// Gradient accent used for the step's hero and subtle background shift.
    var accent: Color {
        switch self {
        case .stayInLines:   return AppTheme.Brand.accent
        case .multipleTools: return Color(hue: 0.05, saturation: 0.45, brightness: 0.92)  // warm coral
        case .iCloudSync:    return Color(hue: 0.58, saturation: 0.55, brightness: 0.95)  // sky blue
        }
    }
}
