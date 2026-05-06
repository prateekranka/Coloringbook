import SwiftUI
import PencilKit

enum DrawingTool: String, CaseIterable, Identifiable {
    case pencil = "Pencil"
    case marker = "Marker"
    case watercolor = "Watercolor"
    case eraser = "Eraser"
    case floodFill = "Fill"
    case eyedropper = "Eyedropper"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .pencil: return "pencil"
        case .marker: return "paintbrush.pointed"
        case .watercolor: return "paintbrush"
        case .eraser: return "eraser"
        case .floodFill: return "drop"
        case .eyedropper: return "eyedropper"
        }
    }

    var isPencilKitTool: Bool {
        switch self {
        case .pencil, .marker, .watercolor, .eraser: return true
        case .floodFill, .eyedropper: return false
        }
    }

    func pkTool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pencil:
            return PKInkingTool(.pencil, color: color, width: width)
        case .marker:
            return PKInkingTool(.marker, color: color, width: width)
        case .watercolor:
            // Watercolor approximated via monoline ink with reduced opacity
            return PKInkingTool(.monoline, color: color.withAlphaComponent(0.4), width: width)
        case .eraser:
            return PKEraserTool(.bitmap, width: width)
        case .floodFill, .eyedropper:
            // These don't use PKTool — return a no-op pencil tool
            return PKInkingTool(.pencil, color: .clear, width: 1)
        }
    }
}

struct BrushSettings {
    var tool: DrawingTool = .floodFill
    var size: CGFloat = 6.0
    var opacity: Double = 1.0
    var color: Color = SableTheme.progressPink

    static let sizeRange: ClosedRange<CGFloat> = 1...50
}
