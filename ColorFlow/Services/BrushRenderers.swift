import UIKit
import CoreGraphics

enum BrushRenderers {

    // MARK: - Main Dispatcher

    static func draw(action: StrokeAction, geometry: TemplateGeometry, in context: CGContext) {
        guard action.points.count > 1 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        if let regionID = action.clippedRegionID,
           let region = geometry.regions.first(where: { $0.id == regionID }) {
            context.addPath(region.path)
            context.clip(using: region.fillRule == .evenOdd ? .evenOdd : .winding)
        } else if !geometry.regions.isEmpty {
            for region in geometry.regions {
                context.addPath(region.path)
            }
            context.clip()
        }

        switch action.tool {
        case .crayon:
            drawCrayon(action: action, in: context)
        case .coloredPencil:
            drawColoredPencil(action: action, in: context)
        case .watercolor:
            drawWatercolor(action: action, in: context)
        case .marker:
            drawMarker(action: action, in: context)
        case .sprayPaint:
            drawSprayPaint(action: action, in: context)
        case .eraser:
            drawEraser(action: action, in: context)
        case .fillBucket:
            break
        }
    }

    // MARK: - Crayon

    static func drawCrayon(action: StrokeAction, in context: CGContext) {
        let color = UIColor(hex: action.colorHex).withAlphaComponent(action.opacity)
        srand48(action.id.hashValue)

        context.setBlendMode(.normal)
        context.setStrokeColor(color.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.setLineWidth(CGFloat(action.size))
        strokePoints(action.points, in: context)

        let extraPasses = 2 + Int(drand48() * 2)
        for _ in 0..<extraPasses {
            let widthVariation = CGFloat(action.size) * CGFloat(0.85 + drand48() * 0.3)
            context.setLineWidth(widthVariation)
            strokeSegmentsOffset(action.points, context: context) {
                CGFloat(drand48() * 3.0 - 1.5)
            }
        }
    }

    // MARK: - Colored Pencil

    static func drawColoredPencil(action: StrokeAction, in context: CGContext) {
        let baseColor = UIColor(hex: action.colorHex)
        srand48(action.id.hashValue)

        context.setBlendMode(.normal)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(CGFloat(action.size))

        let numPasses = 3 + Int(drand48() * 3)
        for _ in 0..<numPasses {
            let perPassOpacity = CGFloat(0.3 + drand48() * 0.2)
            let alpha = perPassOpacity * CGFloat(action.opacity)
            context.setStrokeColor(baseColor.withAlphaComponent(alpha).cgColor)
            let offset = CGFloat(drand48() * 4.0 - 2.0)
            strokeSegmentsOffset(action.points, context: context) { offset }
        }
    }

    // MARK: - Watercolor

    static func drawWatercolor(action: StrokeAction, in context: CGContext) {
        let color = UIColor(hex: action.colorHex)
        context.setBlendMode(.normal)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let baseOpacity = CGFloat(action.opacity)
        let layers: [(width: CGFloat, opacity: CGFloat)] = [
            (CGFloat(action.size) * 0.5, baseOpacity * 0.3),
            (CGFloat(action.size), baseOpacity * 0.18),
            (CGFloat(action.size) * 1.5, baseOpacity * 0.08)
        ]

        for layer in layers {
            context.setLineWidth(layer.width)
            context.setStrokeColor(color.withAlphaComponent(layer.opacity).cgColor)
            strokePoints(action.points, in: context)
        }
    }

    // MARK: - Marker

    static func drawMarker(action: StrokeAction, in context: CGContext) {
        let color = UIColor(hex: action.colorHex)
        context.setBlendMode(.multiply)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.setLineWidth(CGFloat(action.size) * 1.15)
        context.setStrokeColor(color.withAlphaComponent(CGFloat(action.opacity) * 0.12).cgColor)
        strokePoints(action.points, in: context)

        context.setLineWidth(CGFloat(action.size))
        context.setStrokeColor(color.withAlphaComponent(action.opacity).cgColor)
        strokePoints(action.points, in: context)
    }

    // MARK: - Spray Paint

    static func drawSprayPaint(action: StrokeAction, in context: CGContext) {
        let color = UIColor(hex: action.colorHex)
        let radius = CGFloat(action.size) / 2.0
        srand48(action.id.hashValue)

        context.setBlendMode(.normal)

        let stepSize: CGFloat = 3.0
        let points = action.points

        for i in 0..<(points.count - 1) {
            let p1 = points[i].cgPoint
            let p2 = points[i + 1].cgPoint
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let segLen = hypot(dx, dy)
            guard segLen > 0 else { continue }

            let steps = max(1, Int(segLen / stepSize))

            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let centerX = p1.x + dx * t
                let centerY = p1.y + dy * t

                let dotCount = 8 + Int(drand48() * 8)

                for _ in 0..<dotCount {
                    let u1 = drand48()
                    let u2 = drand48()
                    let dist = radius * CGFloat(pow(u1, 0.7))
                    let angle = CGFloat(u2 * 2.0 * .pi)
                    let dotX = centerX + dist * cos(angle)
                    let dotY = centerY + dist * sin(angle)
                    let dotSize = CGFloat(1.5 + drand48() * 2.0)
                    let dotOpacity = CGFloat(0.5 + drand48() * 0.5) * CGFloat(action.opacity)

                    context.setFillColor(color.withAlphaComponent(dotOpacity).cgColor)
                    let rect = CGRect(
                        x: dotX - dotSize / 2,
                        y: dotY - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fillEllipse(in: rect)
                }
            }
        }
    }

    // MARK: - Eraser

    static func drawEraser(action: StrokeAction, in context: CGContext) {
        context.setBlendMode(.clear)
        context.setStrokeColor(UIColor.clear.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(CGFloat(action.size) * 1.2)
        strokePoints(action.points, in: context)
    }

    // MARK: - Private Helpers

    private static func strokePoints(_ points: [CodablePoint], in context: CGContext) {
        guard points.count > 1 else { return }
        context.beginPath()
        context.move(to: points[0].cgPoint)
        for point in points.dropFirst() {
            context.addLine(to: point.cgPoint)
        }
        context.strokePath()
    }

    private static func strokeSegmentsOffset(
        _ points: [CodablePoint],
        context: CGContext,
        offsetProvider: () -> CGFloat
    ) {
        for i in 0..<(points.count - 1) {
            let p1 = points[i].cgPoint
            let p2 = points[i + 1].cgPoint
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let len = hypot(dx, dy)
            guard len > 0 else { continue }

            let perpX = -dy / len
            let perpY = dx / len
            let offset = offsetProvider()
            let o1 = CGPoint(x: p1.x + perpX * offset, y: p1.y + perpY * offset)
            let o2 = CGPoint(x: p2.x + perpX * offset, y: p2.y + perpY * offset)

            context.beginPath()
            context.move(to: o1)
            context.addLine(to: o2)
            context.strokePath()
        }
    }
}
