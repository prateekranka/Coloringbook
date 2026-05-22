import UIKit
import CoreGraphics
import os.signpost

enum BrushRenderers {

    static func draw(action: StrokeAction, geometry: TemplateGeometry, in context: CGContext) {
        RenderPerformanceProbe.measure("CommittedStroke") {
            let stroke = PigmentStroke(
                tool: action.tool,
                colorHex: action.colorHex,
                opacity: action.opacity,
                size: action.size,
                points: action.renderSamples.map(\.cgPoint),
                regionID: action.clippedRegionID,
                seed: action.seed ?? stableSeed(for: action)
            )
            PigmentStrokeRenderer.render(stroke, in: context, mask: clipMask(for: action, geometry: geometry))
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
            let stroke = PigmentStroke(
                tool: tool,
                colorHex: colorHex,
                opacity: Double(opacity),
                size: Double(size),
                points: samples.map(\.cgPoint),
                regionID: nil,
                seed: seed ?? stableSeed(for: samples, tool: tool, colorHex: colorHex, size: size, opacity: opacity)
            )
            let mask = clipPath.map { RegionMask(regionID: "live", path: $0, fillRule: clipFillRule, image: UIImage()) }
            PigmentStrokeRenderer.render(stroke, in: context, mask: mask)
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

    private static func clipMask(for action: StrokeAction, geometry: TemplateGeometry) -> RegionMask? {
        if let regionID = action.clippedRegionID,
           let region = geometry.regions.first(where: { $0.id == regionID }) {
            return RegionMask(regionID: regionID, path: region.path, fillRule: region.fillRule, image: UIImage())
        }

        guard !geometry.regions.isEmpty else { return nil }
        let path = CGMutablePath()
        for region in geometry.regions {
            path.addPath(region.path)
        }
        return RegionMask(regionID: "all-regions", path: path, fillRule: .winding, image: UIImage())
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
