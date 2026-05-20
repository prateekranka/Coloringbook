import CoreGraphics
import UIKit

struct PigmentStroke: Identifiable, Codable, Equatable {
    let id: UUID
    var tool: ToolType
    var colorHex: String
    var opacity: Double
    var size: Double
    var points: [CodablePoint]
    var regionID: String?
    var timestamp: TimeInterval
    var seed: UInt64

    init(
        id: UUID = UUID(),
        tool: ToolType,
        colorHex: String,
        opacity: Double,
        size: Double,
        points: [CGPoint],
        regionID: String?,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        seed: UInt64? = nil
    ) {
        self.id = id
        self.tool = tool
        self.colorHex = colorHex
        self.opacity = opacity
        self.size = size
        self.points = points.map(CodablePoint.init)
        self.regionID = regionID
        self.timestamp = timestamp
        self.seed = seed ?? PigmentStroke.makeSeed(
            tool: tool,
            colorHex: colorHex,
            opacity: opacity,
            size: size,
            points: points
        )
    }

    var cgPoints: [CGPoint] {
        points.map(\.cgPoint)
    }

    private static func makeSeed(
        tool: ToolType,
        colorHex: String,
        opacity: Double,
        size: Double,
        points: [CGPoint]
    ) -> UInt64 {
        var hasher = PigmentStableHasher()
        hasher.combine(tool.rawValue)
        hasher.combine(colorHex)
        hasher.combine(opacity)
        hasher.combine(size)
        for point in points {
            hasher.combine(Double(point.x))
            hasher.combine(Double(point.y))
        }
        return hasher.value
    }
}

struct PigmentPatch {
    let rect: CGRect
    let before: UIImage
    let after: UIImage
}

protocol PigmentBrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, into bitmap: PigmentBitmap, mask: RegionMask?) -> PigmentPatch
}

struct RegionMask {
    let regionID: String
    let path: CGPath
    let fillRule: CGPathFillRule
    let image: UIImage
}

final class RegionMaskCache {
    private var masks: [String: RegionMask] = [:]

    func mask(
        for region: RegionGeometry,
        canvasSize: CGSize,
        documentToBitmap: CGAffineTransform = .identity
    ) -> RegionMask {
        let key = "\(region.id)-\(Int(canvasSize.width))x\(Int(canvasSize.height))"
        if let cached = masks[key] {
            return cached
        }
        var documentToBitmap = documentToBitmap
        let bitmapPath = region.path.copy(using: &documentToBitmap) ?? region.path

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            let cgContext = context.cgContext
            cgContext.addPath(bitmapPath)
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fillPath(using: region.fillRule)
        }
        let mask = RegionMask(regionID: region.id, path: bitmapPath, fillRule: region.fillRule, image: image)
        masks[key] = mask
        return mask
    }

    func removeAll() {
        masks.removeAll()
    }
}

final class PigmentBitmap {
    private(set) var image: UIImage
    let size: CGSize

    init(size: CGSize, image: UIImage? = nil) {
        self.size = size
        self.image = image.map { PigmentBitmap.normalizedImage($0, size: size) } ?? PigmentBitmap.emptyImage(size: size)
    }

    func replace(with image: UIImage) {
        self.image = Self.normalizedImage(image, size: size)
    }

    func fill(regionMask mask: RegionMask, colorHex: String) -> PigmentPatch {
        let before = image
        let format = Self.format
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            before.draw(in: CGRect(origin: .zero, size: size))
            let cgContext = context.cgContext
            cgContext.addPath(mask.path)
            cgContext.clip(using: mask.fillRule)
            cgContext.setBlendMode(.normal)
            cgContext.setFillColor(UIColor(hex: colorHex).cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
        }
        image = rendered
        return PigmentPatch(rect: mask.path.boundingBoxOfPath.integral, before: before, after: rendered)
    }

    func drawStroke(_ stroke: PigmentStroke, mask: RegionMask?) -> PigmentPatch {
        let before = image
        let renderer = renderer(for: stroke.tool)
        return renderer.renderStroke(stroke, into: self, mask: mask).withBefore(before)
    }

    fileprivate func render(_ block: (CGContext) -> Void) -> UIImage {
        UIGraphicsImageRenderer(size: size, format: Self.format).image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
            block(context.cgContext)
        }
    }

    fileprivate func render(clipRect: CGRect, _ block: (CGContext) -> Void) -> UIImage {
        let paddedRect = clipRect.insetBy(dx: -8, dy: -8).intersection(CGRect(origin: .zero, size: size))
        guard paddedRect.width > 1, paddedRect.height > 1 else {
            return image
        }
        return UIGraphicsImageRenderer(size: size, format: Self.format).image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
            context.cgContext.saveGState()
            context.cgContext.clip(to: paddedRect)
            block(context.cgContext)
            context.cgContext.restoreGState()
        }
    }

    func savePNG(to url: URL) {
        guard let data = image.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func loadPNG(from url: URL, size: CGSize) -> PigmentBitmap {
        PigmentBitmap(size: size, image: UIImage(contentsOfFile: url.path))
    }

    static func normalizedImage(_ image: UIImage, size: CGSize) -> UIImage {
        guard abs(image.size.width - size.width) > 0.5 || abs(image.size.height - size.height) > 0.5 else {
            return image
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func emptyImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size, format: format).image { _ in }
    }

    private static var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        return format
    }

    private func renderer(for tool: ToolType) -> PigmentBrushRenderer {
        switch tool {
        case .watercolor:
            return WatercolorPigmentRenderer()
        case .marker:
            return MarkerPigmentRenderer()
        case .coloredPencil, .crayon:
            return PencilPigmentRenderer()
        case .eraser:
            return EraserPigmentRenderer()
        case .sprayPaint:
            return SprayPigmentRenderer()
        case .fillBucket:
            return MarkerPigmentRenderer()
        }
    }
}

final class RegionPigmentEngine {
    let bitmap: PigmentBitmap
    let geometry: TemplateGeometry
    private let maskCache = RegionMaskCache()
    private let documentToBitmap: CGAffineTransform
    private let bitmapToDocument: CGAffineTransform

    init(geometry: TemplateGeometry, bitmapSize: CGSize? = nil, existingImage: UIImage? = nil) {
        self.geometry = geometry
        let size = bitmapSize ?? geometry.viewBox.size
        self.documentToBitmap = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: size
        )
        self.bitmapToDocument = documentToBitmap.inverted()
        self.bitmap = PigmentBitmap(size: size, image: existingImage)
    }

    var image: UIImage {
        bitmap.image
    }

    func fill(regionID: String, colorHex: String) -> PigmentPatch? {
        guard let region = region(withID: regionID) else { return nil }
        let patch = bitmap.fill(
            regionMask: maskCache.mask(for: region, canvasSize: bitmap.size, documentToBitmap: documentToBitmap),
            colorHex: colorHex
        )
        return patch.inDocumentSpace(using: bitmapToDocument)
    }

    func renderCleanStroke(
        tool: ToolType,
        colorHex: String,
        points: [CGPoint],
        size: CGFloat,
        opacity: Double,
        seed: UInt64? = nil
    ) -> PigmentPatch? {
        guard let first = points.first,
              let region = geometry.region(at: first) else {
            return nil
        }
        return renderStroke(
            tool: tool,
            colorHex: colorHex,
            points: points,
            regionID: region.id,
            size: size,
            opacity: opacity,
            seed: seed
        )
    }

    func renderStroke(
        tool: ToolType,
        colorHex: String,
        points: [CGPoint],
        regionID: String?,
        size: CGFloat,
        opacity: Double,
        seed: UInt64? = nil
    ) -> PigmentPatch? {
        guard tool != .fillBucket else { return nil }
        let stroke = PigmentStroke(
            tool: tool,
            colorHex: colorHex,
            opacity: opacity,
            size: Double(size * documentToBitmapScale),
            points: points.map { $0.applying(documentToBitmap) },
            regionID: regionID,
            seed: seed
        )
        let mask = regionID
            .flatMap(region(withID:))
            .map { maskCache.mask(for: $0, canvasSize: bitmap.size, documentToBitmap: documentToBitmap) }
        return bitmap.drawStroke(stroke, mask: mask).inDocumentSpace(using: bitmapToDocument)
    }

    func renderFreeStroke(
        tool: ToolType,
        colorHex: String,
        points: [CGPoint],
        size: CGFloat,
        opacity: Double,
        seed: UInt64? = nil
    ) -> PigmentPatch? {
        renderStroke(
            tool: tool,
            colorHex: colorHex,
            points: points,
            regionID: nil,
            size: size,
            opacity: opacity,
            seed: seed
        )
    }

    func restore(_ image: UIImage) {
        bitmap.replace(with: image)
    }

    func mask(for region: RegionGeometry) -> RegionMask {
        maskCache.mask(for: region, canvasSize: bitmap.size, documentToBitmap: documentToBitmap)
    }

    private func region(withID id: String) -> RegionGeometry? {
        geometry.regions.first { $0.id == id }
    }

    private var documentToBitmapScale: CGFloat {
        min(bitmap.size.width / geometry.viewBox.width, bitmap.size.height / geometry.viewBox.height)
    }
}

private struct WatercolorPigmentRenderer: PigmentBrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, into bitmap: PigmentBitmap, mask: RegionMask?) -> PigmentPatch {
        let before = bitmap.image
        let points = stroke.cgPoints
        let affectedRect = dirtyRect(points: points, size: CGFloat(stroke.size) * 2.2)
        let color = UIColor(hex: stroke.colorHex)
        let rendered = bitmap.render(clipRect: affectedRect) { context in
            clip(mask, in: context)
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
        bitmap.replace(with: rendered)
        return PigmentPatch(rect: affectedRect, before: before, after: rendered)
    }
}

private struct MarkerPigmentRenderer: PigmentBrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, into bitmap: PigmentBitmap, mask: RegionMask?) -> PigmentPatch {
        let before = bitmap.image
        let points = stroke.cgPoints
        let affectedRect = dirtyRect(points: points, size: CGFloat(stroke.size) * 1.6)
        let rendered = bitmap.render(clipRect: affectedRect) { context in
            clip(mask, in: context)
            context.setBlendMode(.multiply)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(CGFloat(stroke.size) * 1.08)
            context.setStrokeColor(UIColor(hex: stroke.colorHex).withAlphaComponent(CGFloat(stroke.opacity)).cgColor)
            strokePath(points, in: context)
        }
        bitmap.replace(with: rendered)
        return PigmentPatch(rect: affectedRect, before: before, after: rendered)
    }
}

private struct PencilPigmentRenderer: PigmentBrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, into bitmap: PigmentBitmap, mask: RegionMask?) -> PigmentPatch {
        let before = bitmap.image
        let points = stroke.cgPoints
        let affectedRect = dirtyRect(points: points, size: CGFloat(stroke.size) * 1.8)
        let rendered = bitmap.render(clipRect: affectedRect) { context in
            clip(mask, in: context)
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
        bitmap.replace(with: rendered)
        return PigmentPatch(rect: affectedRect, before: before, after: rendered)
    }
}

private struct SprayPigmentRenderer: PigmentBrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, into bitmap: PigmentBitmap, mask: RegionMask?) -> PigmentPatch {
        let before = bitmap.image
        let points = stroke.cgPoints
        let affectedRect = dirtyRect(points: points, size: CGFloat(stroke.size) * 2.2)
        let rendered = bitmap.render(clipRect: affectedRect) { context in
            clip(mask, in: context)
            var rng = PigmentSeededRandom(seed: stroke.seed)
            let color = UIColor(hex: stroke.colorHex)
            let radius = CGFloat(stroke.size) / 2

            context.setBlendMode(.normal)
            stamp(points: points, spacing: max(1.5, CGFloat(stroke.size) * 0.06)) { center in
                let dotCount = 8 + Int(rng.nextUnit() * 8)
                for _ in 0..<dotCount {
                    let distance = radius * CGFloat(pow(rng.nextUnit(), 0.7))
                    let angle = CGFloat(rng.nextUnit() * 2 * .pi)
                    let dotSize = CGFloat(1.5 + rng.nextUnit() * 2)
                    let alpha = CGFloat(stroke.opacity) * CGFloat(0.5 + rng.nextUnit() * 0.5)
                    let dotCenter = CGPoint(
                        x: center.x + distance * cos(angle),
                        y: center.y + distance * sin(angle)
                    )
                    let rect = CGRect(
                        x: dotCenter.x - dotSize / 2,
                        y: dotCenter.y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.setFillColor(color.withAlphaComponent(alpha).cgColor)
                    context.fillEllipse(in: rect)
                }
            }
        }
        bitmap.replace(with: rendered)
        return PigmentPatch(rect: affectedRect, before: before, after: rendered)
    }
}

private struct EraserPigmentRenderer: PigmentBrushRenderer {
    func renderStroke(_ stroke: PigmentStroke, into bitmap: PigmentBitmap, mask: RegionMask?) -> PigmentPatch {
        let before = bitmap.image
        let points = stroke.cgPoints
        let affectedRect = dirtyRect(points: points, size: CGFloat(stroke.size) * 1.6)
        let rendered = bitmap.render(clipRect: affectedRect) { context in
            clip(mask, in: context)
            context.setBlendMode(.clear)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(CGFloat(stroke.size) * 1.2)
            context.setStrokeColor(UIColor.clear.cgColor)
            strokePath(points, in: context)
        }
        bitmap.replace(with: rendered)
        return PigmentPatch(rect: affectedRect, before: before, after: rendered)
    }
}

private extension PigmentPatch {
    func withBefore(_ before: UIImage) -> PigmentPatch {
        PigmentPatch(rect: rect, before: before, after: after)
    }

    func inDocumentSpace(using transform: CGAffineTransform) -> PigmentPatch {
        PigmentPatch(
            rect: rect.applying(transform).integral,
            before: before,
            after: after
        )
    }
}

private func clip(_ mask: RegionMask?, in context: CGContext) {
    guard let mask else { return }
    context.addPath(mask.path)
    context.clip(using: mask.fillRule)
}

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

struct PigmentSeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9e3779b97f4a7c15 : seed
    }

    mutating func nextUnit() -> Double {
        state = state &* 2862933555777941757 &+ 3037000493
        return Double(state >> 11) / 9_007_199_254_740_992.0
    }
}

private struct PigmentStableHasher {
    private(set) var value: UInt64 = 0xcbf29ce484222325

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            combine(byte)
        }
        combine(UInt8(0xff))
    }

    mutating func combine(_ double: Double) {
        combine(String(format: "%.6f", double))
    }

    private mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value &*= 0x100000001b3
    }
}
