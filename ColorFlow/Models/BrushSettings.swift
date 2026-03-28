import SwiftUI
import PencilKit

enum DrawingTool: String, CaseIterable, Identifiable {
    case pencil = "Pencil"
    case marker = "Marker"
    case watercolor = "Soft Brush"
    case eraser = "Eraser"
    case fountainPen = "Fountain Pen"
    case crayon = "Crayon"
    case highlighter = "Highlighter"
    case stamp = "Stamp"
    case floodFill = "Fill"
    case eyedropper = "Eyedropper"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .pencil: return "pencil"
        case .marker: return "paintbrush.pointed"
        case .watercolor: return "paintbrush"
        case .eraser: return "eraser"
        case .fountainPen: return "scribble.variable"
        case .crayon: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .stamp: return "star.circle"
        case .floodFill: return "drop"
        case .eyedropper: return "eyedropper"
        }
    }

    var accessibilityName: String {
        switch self {
        case .pencil:     return "Pencil"
        case .marker:     return "Marker"
        case .watercolor: return "Soft Brush"
        case .eraser:       return "Eraser"
        case .fountainPen:  return "Fountain pen"
        case .crayon:       return "Crayon"
        case .highlighter:  return "Highlighter"
        case .stamp:        return "Stamp"
        case .floodFill:    return "Flood fill"
        case .eyedropper: return "Eyedropper"
        }
    }

    var isPencilKitTool: Bool {
        switch self {
        case .pencil, .marker, .watercolor, .eraser, .fountainPen, .crayon, .highlighter: return true
        case .stamp, .floodFill, .eyedropper: return false
        }
    }

    func pkTool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pencil:
            return PKInkingTool(.pencil, color: color, width: width)
        case .marker:
            return PKInkingTool(.marker, color: color, width: width)
        case .watercolor:
            // Soft Brush: monoline ink with reduced opacity
            return PKInkingTool(.monoline, color: color.withAlphaComponent(0.4), width: width)
        case .eraser:
            return PKEraserTool(.bitmap, width: width)
        case .fountainPen:
            return PKInkingTool(.fountainPen, color: color, width: width)
        case .crayon:
            return PKInkingTool(.crayon, color: color, width: width)
        case .highlighter:
            return PKInkingTool(.marker, color: color.withAlphaComponent(0.5), width: width * 2.5)
        case .stamp, .floodFill, .eyedropper:
            // These don't use PKTool — return a no-op pencil tool
            return PKInkingTool(.pencil, color: .clear, width: 1)
        }
    }
}

struct BrushSettings {
    var tool: DrawingTool = .pencil
    var size: CGFloat = 8.0
    var opacity: Double = 1.0
    var color: Color = .black

    static let sizeRange: ClosedRange<CGFloat> = 1...50
}
