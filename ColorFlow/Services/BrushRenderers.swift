import UIKit
import CoreGraphics
import os.signpost

enum BrushRenderers {

    // MARK: - Public Rendering Entry Points

    static func draw(action: StrokeAction, geometry: TemplateGeometry, in context: CGContext) {
        RenderPerformanceProbe.measure("CommittedStroke") {
            let clip = clipPath(for: action, geometry: geometry)
            let stroke = BrushStroke(
                tool: action.tool,
                colorHex: action.colorHex,
                points: action.renderSamples.map(\.cgPoint),
                size: CGFloat(action.size),
                opacity: CGFloat(action.opacity),
                seed: stableSeed(for: action)
            )
            draw(stroke: stroke, clip: clip, in: context)
        }
    }

    static func drawLiveStroke(
        samples: [StrokeSample],
        tool: ToolType,
        colorHex: String,
        size: CGFloat,
        opacity: CGFloat,
        clipPath: CGPath? = nil,
        clipFillRule: CGPathFillRule = .winding,
        seed: UInt64? = nil,
        in context: CGContext
    ) {
        RenderPerformanceProbe.measure("LiveStroke") {
            let stroke = BrushStroke(
                tool: tool,
                colorHex: colorHex,
                points: samples.map(\.cgPoint),
                size: size,
                opacity: opacity,
                seed: seed ?? stableSeed(for: samples, tool: tool, colorHex: colorHex, size: size, opacity: opacity)
            )
            let clip = clipPath.map { BrushClip(path: $0, fillRule: clipFillRule) }
            draw(stroke: stroke, clip: clip, in: context)
        }
    }

    static func drawLiveStroke(
        points: [CGPoint],
        tool: ToolType,
        colorHex: String,
        size: CGFloat,
        opacity: CGFloat,
        clipPath: CGPath? = nil,
        clipFillRule: CGPathFillRule = .winding,
        seed: UInt64? = nil,
        in context: CGContext
    ) {
        drawLiveStroke(
            samples: points.map { StrokeSample(point: $0) },
            tool: tool,
            colorHex: colorHex,
            size: size,
            opacity: opacity,
            clipPath: clipPath,
            clipFillRule: clipFillRule,
            seed: seed,
            in: context
        )
    }

    // MARK: - Main Dispatcher

    private static func draw(stroke: BrushStroke, clip: BrushClip?, in context: CGContext) {
        guard stroke.points.count > 1 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        if let clip {
            context.addPath(clip.path)
            context.clip(using: clip.fillRule)
        }

        switch stroke.tool {
        case .crayon:
            drawCrayon(stroke: stroke, in: context)
        case .coloredPencil:
            drawColoredPencil(stroke: stroke, in: context)
        case .watercolor:
            drawWatercolor(stroke: stroke, in: context)
        case .marker:
            drawMarker(stroke: stroke, in: context)
        case .sprayPaint:
            drawSprayPaint(stroke: stroke, in: context)
        case .eraser:
            drawEraser(stroke: stroke, in: context)
        case .fillBucket:
            break
        }
    }

    // MARK: - Crayon

    private static func drawCrayon(stroke: BrushStroke, in context: CGContext) {
        var rng = SeededRandom(seed: stroke.seed)
        let color = UIColor(hex: stroke.colorHex)

        context.setBlendMode(.normal)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.setStrokeColor(color.withAlphaComponent(stroke.opacity * 0.68).cgColor)
        context.setLineWidth(stroke.size)
        strokePoints(stroke.points, in: context)

        let extraPasses = 2 + Int(rng.nextUnit() * 2)
        for _ in 0..<extraPasses {
            let widthVariation = stroke.size * CGFloat(0.85 + rng.nextUnit() * 0.3)
            let passOpacity = stroke.opacity * CGFloat(0.18 + rng.nextUnit() * 0.12)
            context.setStrokeColor(color.withAlphaComponent(passOpacity).cgColor)
            context.setLineWidth(widthVariation)
            strokeSegmentsOffset(stroke.points, context: context) {
                CGFloat(rng.nextUnit() * 3.0 - 1.5)
            }
        }
    }

    // MARK: - Colored Pencil

    private static func drawColoredPencil(stroke: BrushStroke, in context: CGContext) {
        var rng = SeededRandom(seed: stroke.seed)
        let baseColor = UIColor(hex: stroke.colorHex)

        context.setBlendMode(.normal)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(stroke.size)

        let numPasses = 3 + Int(rng.nextUnit() * 3)
        for _ in 0..<numPasses {
            let perPassOpacity = CGFloat(0.3 + rng.nextUnit() * 0.2)
            let alpha = perPassOpacity * stroke.opacity
            context.setStrokeColor(baseColor.withAlphaComponent(alpha).cgColor)
            let offset = CGFloat(rng.nextUnit() * 4.0 - 2.0)
            strokeSegmentsOffset(stroke.points, context: context) { offset }
        }
    }

    // MARK: - Watercolor

    private static func drawWatercolor(stroke: BrushStroke, in context: CGContext) {
        let color = UIColor(hex: stroke.colorHex)
        context.setBlendMode(.normal)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let layers: [(width: CGFloat, opacity: CGFloat)] = [
            (stroke.size * 0.5, stroke.opacity * 0.3),
            (stroke.size, stroke.opacity * 0.18),
            (stroke.size * 1.5, stroke.opacity * 0.08)
        ]

        for layer in layers {
            context.setLineWidth(layer.width)
            context.setStrokeColor(color.withAlphaComponent(layer.opacity).cgColor)
            strokePoints(stroke.points, in: context)
        }
    }

    // MARK: - Marker

    private static func drawMarker(stroke: BrushStroke, in context: CGContext) {
        let color = UIColor(hex: stroke.colorHex)
        context.setBlendMode(.multiply)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.setLineWidth(stroke.size * 1.15)
        context.setStrokeColor(color.withAlphaComponent(stroke.opacity * 0.12).cgColor)
        strokePoints(stroke.points, in: context)

        context.setLineWidth(stroke.size)
        context.setStrokeColor(color.withAlphaComponent(stroke.opacity).cgColor)
        strokePoints(stroke.points, in: context)
    }

    // MARK: - Spray Paint

    private static func drawSprayPaint(stroke: BrushStroke, in context: CGContext) {
        var rng = SeededRandom(seed: stroke.seed)
        let color = UIColor(hex: stroke.colorHex)
        let radius = stroke.size / 2.0

        context.setBlendMode(.normal)

        let stepSize: CGFloat = 3.0
        let points = stroke.points

        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let segLen = hypot(dx, dy)
            guard segLen > 0 else { continue }

            let steps = max(1, Int(segLen / stepSize))

            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let centerX = p1.x + dx * t
                let centerY = p1.y + dy * t

                let dotCount = 8 + Int(rng.nextUnit() * 8)

                for _ in 0..<dotCount {
                    let u1 = rng.nextUnit()
                    let u2 = rng.nextUnit()
                    let dist = radius * CGFloat(pow(u1, 0.7))
                    let angle = CGFloat(u2 * 2.0 * .pi)
                    let dotX = centerX + dist * cos(angle)
                    let dotY = centerY + dist * sin(angle)
                    let dotSize = CGFloat(1.5 + rng.nextUnit() * 2.0)
                    let dotOpacity = CGFloat(0.5 + rng.nextUnit() * 0.5) * stroke.opacity

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

    private static func drawEraser(stroke: BrushStroke, in context: CGContext) {
        context.setBlendMode(.clear)
        context.setStrokeColor(UIColor.clear.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(stroke.size * 1.2)
        strokePoints(stroke.points, in: context)
    }

    // MARK: - Private Helpers

    private static func clipPath(for action: StrokeAction, geometry: TemplateGeometry) -> BrushClip? {
        if let regionID = action.clippedRegionID,
           let region = geometry.regions.first(where: { $0.id == regionID }) {
            return BrushClip(path: region.path, fillRule: region.fillRule)
        }

        guard !geometry.regions.isEmpty else { return nil }
        let path = CGMutablePath()
        for region in geometry.regions {
            path.addPath(region.path)
        }
        return BrushClip(path: path, fillRule: .winding)
    }

    private static func strokePoints(_ points: [CGPoint], in context: CGContext) {
        guard points.count > 1 else { return }
        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    private static func strokeSegmentsOffset(
        _ points: [CGPoint],
        context: CGContext,
        offsetProvider: () -> CGFloat
    ) {
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
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

    private static func stableSeed(for action: StrokeAction) -> UInt64 {
        var hasher = StableHasher()
        hasher.combine(action.tool.rawValue)
        hasher.combine(action.colorHex)
        hasher.combine(action.size)
        hasher.combine(action.opacity)
        if let firstSample = action.renderSamples.first {
            hasher.combine(firstSample.point.x)
            hasher.combine(firstSample.point.y)
            if let force = firstSample.force {
                hasher.combine(force)
            }
        }
        return hasher.value
    }

    private static func stableSeed(
        for samples: [StrokeSample],
        tool: ToolType,
        colorHex: String,
        size: CGFloat,
        opacity: CGFloat
    ) -> UInt64 {
        var hasher = StableHasher()
        hasher.combine(tool.rawValue)
        hasher.combine(colorHex)
        hasher.combine(Double(size))
        hasher.combine(Double(opacity))
        if let firstSample = samples.first {
            hasher.combine(firstSample.point.x)
            hasher.combine(firstSample.point.y)
            if let force = firstSample.force {
                hasher.combine(force)
            }
        }
        return hasher.value
    }
}

private struct BrushStroke {
    let tool: ToolType
    let colorHex: String
    let points: [CGPoint]
    let size: CGFloat
    let opacity: CGFloat
    let seed: UInt64
}

private struct BrushClip {
    let path: CGPath
    let fillRule: CGPathFillRule
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func nextUnit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9_007_199_254_740_992.0
    }
}

private struct StableHasher {
    private(set) var value: UInt64 = 0xcbf29ce484222325

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            combine(byte)
        }
        combine(UInt8(0xff))
    }

    mutating func combine(_ double: Double) {
        combine(double.bitPattern)
    }

    private mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value = value &* 0x100000001b3
    }

    private mutating func combine(_ integer: UInt64) {
        var value = integer
        for _ in 0..<8 {
            combine(UInt8(truncatingIfNeeded: value))
            value >>= 8
        }
    }
}

private enum RenderPerformanceProbe {
    private static let log = OSLog(subsystem: "com.prateekranka.colorflow", category: "CanvasRender")

    static func measure<T>(_ name: StaticString, _ work: () -> T) -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        let result = work()
        os_signpost(.end, log: log, name: name, signpostID: id)
        return result
    }
}
