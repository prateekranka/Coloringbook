import CoreGraphics
import UIKit

/// Renders a `PigmentStroke` into an arbitrary `CGContext` using the same
/// pigment brush implementations that `RegionPigmentEngine` uses for final
/// committed strokes.  Used for live-stroke preview so the on-screen stroke
/// looks identical to the committed result.
enum PigmentStrokeRenderer {

    // MARK: - Public entry point

    static func affectedRect(for stroke: PigmentStroke) -> CGRect {
        dirtyRect(points: stroke.cgPoints, size: dirtyMargin(for: stroke))
    }

    static func render(
        _ stroke: PigmentStroke,
        in context: CGContext,
        mask: RegionMask? = nil
    ) {
        context.saveGState()
        defer { context.restoreGState() }

        if let mask {
            context.addPath(mask.path)
            context.clip(using: mask.fillRule)
        }

        let renderer = renderer(for: stroke.tool)
        renderer.renderStroke(stroke, in: context)
    }

    // MARK: - Dispatcher

    private static func renderer(for tool: ToolType) -> any BrushRenderer {
        switch tool {
        case .watercolor:
            return WatercolorBrushRenderer()
        case .marker:
            return MarkerBrushRenderer()
        case .crayon:
            return PencilBrushRenderer()
        case .eraser:
            return EraserBrushRenderer()
        case .fillBucket:
            return MarkerBrushRenderer()
        }
    }

    private static func dirtyMargin(for stroke: PigmentStroke) -> CGFloat {
        switch stroke.tool {
        case .watercolor:
            return CGFloat(stroke.size) * 2.2
        case .marker, .eraser:
            return CGFloat(stroke.size) * 1.6
        case .crayon:
            return CGFloat(stroke.size) * 1.8
        case .fillBucket:
            return CGFloat(stroke.size) * 1.6
        }
    }
}

// MARK: - Protocol

private protocol BrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, in context: CGContext)
}

// MARK: - Watercolor

private struct WatercolorBrushRenderer: BrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, in context: CGContext) {
        let points = stroke.cgPoints
        let color = UIColor(hex: stroke.colorHex)
        var rng = PigmentSeededRandom(seed: stroke.seed)
        context.setBlendMode(.normal)
        stamp(points: points, spacing: max(2, CGFloat(stroke.size) * 0.22)) { center in
            let radius = CGFloat(stroke.size) * CGFloat(0.42 + rng.nextUnit() * 0.16)
            let alpha = CGFloat(stroke.opacity) * CGFloat(0.045 + rng.nextUnit() * 0.035)
            let colors = [
                color.withAlphaComponent(alpha).cgColor,
                color.withAlphaComponent(alpha * 0.38).cgColor,
                color.withAlphaComponent(0).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.68, 1])!
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
    }
}

// MARK: - Marker

private struct MarkerBrushRenderer: BrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, in context: CGContext) {
        let points = stroke.cgPoints
        context.setBlendMode(.multiply)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(CGFloat(stroke.size) * 1.08)
        context.setStrokeColor(UIColor(hex: stroke.colorHex).withAlphaComponent(CGFloat(stroke.opacity)).cgColor)
        strokePath(points, in: context)
    }
}

// MARK: - Pencil / Crayon

private struct PencilBrushRenderer: BrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, in context: CGContext) {
        let points = stroke.cgPoints
        var rng = PigmentSeededRandom(seed: stroke.seed)
        let color = UIColor(hex: stroke.colorHex)
        context.setBlendMode(.normal)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let baseSize = CGFloat(stroke.size)
        for _ in 0..<4 {
            context.setLineWidth(baseSize * CGFloat(0.72 + rng.nextUnit() * 0.28))
            context.setStrokeColor(color.withAlphaComponent(CGFloat(stroke.opacity) * CGFloat(0.18 + rng.nextUnit() * 0.1)).cgColor)
            strokeOffsetPath(points, offset: baseSize * CGFloat(rng.nextUnit() * 0.16 - 0.08), in: context)
        }
    }
}

// MARK: - Eraser

private struct EraserBrushRenderer: BrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, in context: CGContext) {
        let points = stroke.cgPoints
        context.setBlendMode(.clear)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(CGFloat(stroke.size) * 1.2)
        context.setStrokeColor(UIColor.clear.cgColor)
        strokePath(points, in: context)
    }
}

// MARK: - Helpers

private func strokePath(_ points: [CGPoint], in context: CGContext) {
    guard points.count > 1 else { return }
    context.beginPath()
    context.move(to: points[0])
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()
}

private func strokeOffsetPath(_ points: [CGPoint], offset: CGFloat, in context: CGContext) {
    guard points.count > 1 else { return }
    context.beginPath()
    for index in 0..<(points.count - 1) {
        let p1 = points[index]
        let p2 = points[index + 1]
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let length = max(1, hypot(dx, dy))
        let ox = -dy / length * offset
        let oy = dx / length * offset
        let start = CGPoint(x: p1.x + ox, y: p1.y + oy)
        let end = CGPoint(x: p2.x + ox, y: p2.y + oy)
        if index == 0 {
            context.move(to: start)
        }
        context.addLine(to: end)
    }
    context.strokePath()
}

private func stamp(points: [CGPoint], spacing: CGFloat, draw: (CGPoint) -> Void) {
    guard points.count > 1 else { return }
    for index in 0..<(points.count - 1) {
        let a = points[index]
        let b = points[index + 1]
        let distance = hypot(b.x - a.x, b.y - a.y)
        let steps = max(1, Int(distance / spacing))
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            draw(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
    }
}

private func dirtyRect(points: [CGPoint], size: CGFloat) -> CGRect {
    guard !points.isEmpty else { return .zero }
    let rect = points.reduce(CGRect.null) { partial, point in
        partial.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
    }
    return rect.insetBy(dx: -size, dy: -size).integral
}
