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
        let affectedRect = PigmentStrokeRenderer.affectedRect(for: stroke)
        let rendered = render(clipRect: affectedRect) { context in
            PigmentStrokeRenderer.render(stroke, in: context, mask: mask)
        }
        replace(with: rendered)
        return PigmentPatch(rect: affectedRect, before: before, after: image)
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
        guard let region = cleanStrokeRegion(for: points, tool: tool) else {
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

    private func cleanStrokeRegion(for points: [CGPoint], tool: ToolType) -> RegionGeometry? {
        guard tool == .eraser else {
            return points.first.flatMap { geometry.region(at: $0) }
        }
        for point in points {
            if let region = geometry.region(at: point) {
                return region
            }
        }
        return nil
    }

    private var documentToBitmapScale: CGFloat {
        min(bitmap.size.width / geometry.viewBox.width, bitmap.size.height / geometry.viewBox.height)
    }
}

private extension PigmentPatch {
    func inDocumentSpace(using transform: CGAffineTransform) -> PigmentPatch {
        PigmentPatch(
            rect: rect.applying(transform).integral,
            before: before,
            after: after
        )
    }
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
