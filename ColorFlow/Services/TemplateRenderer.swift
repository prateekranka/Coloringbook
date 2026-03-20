import UIKit
import CoreGraphics

struct TemplateRenderer {

    // MARK: - Coordinate Transform

    /// The single coordinate transform used everywhere.
    static func documentToViewTransform(viewBox: CGRect, viewSize: CGSize) -> CGAffineTransform {
        let scale = min(viewSize.width / viewBox.width, viewSize.height / viewBox.height)
        let tx = (viewSize.width - viewBox.width * scale) / 2
        let ty = (viewSize.height - viewBox.height * scale) / 2
        return CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scale, y: scale)
    }

    // MARK: - Fill Layer

    /// Render filled regions to UIImage. Only regions with entries in `fills` are drawn.
    /// fills: [regionID: hexColor]
    static func renderFillLayer(
        geometry: TemplateGeometry,
        fills: [String: String],
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let transform = documentToViewTransform(viewBox: geometry.viewBox, viewSize: size)
            cgContext.concatenate(transform)

            let sortedRegions = geometry.regions.sorted { $0.zIndex < $1.zIndex }
            for region in sortedRegions {
                guard let hexColor = fills[region.id],
                      let color = UIColor(hex: hexColor) else { continue }

                cgContext.setFillColor(color.cgColor)
                cgContext.addPath(region.path)
                cgContext.fillPath(using: region.fillRule)
            }
        }
    }

    // MARK: - Line Art

    /// Render line art (all paths with black strokes) to UIImage.
    /// This image is used as the topmost layer with .multiply blend mode.
    static func renderLineArt(
        geometry: TemplateGeometry,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let transform = documentToViewTransform(viewBox: geometry.viewBox, viewSize: size)
            cgContext.concatenate(transform)

            let scale = min(size.width / geometry.viewBox.width, size.height / geometry.viewBox.height)
            let strokeWidth = 3.0 / scale

            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(strokeWidth)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            cgContext.setFillColor(UIColor.clear.cgColor)

            for region in geometry.regions {
                cgContext.addPath(region.path)
                cgContext.strokePath()
            }

            for path in geometry.decorativePaths {
                cgContext.addPath(path)
                cgContext.strokePath()
            }
        }
    }

    // MARK: - Thumbnail

    /// Render a thumbnail for the template library.
    static func renderThumbnail(
        geometry: TemplateGeometry,
        fills: [String: String] = [:],
        size: CGSize = CGSize(width: 400, height: 400)
    ) -> UIImage {
        guard !fills.isEmpty else {
            return renderLineArt(geometry: geometry, size: size)
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let fillLayer = renderFillLayer(geometry: geometry, fills: fills, size: size)
            fillLayer.draw(in: CGRect(origin: .zero, size: size))

            let lineArt = renderLineArt(geometry: geometry, size: size)
            lineArt.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Export

    /// Composite all layers for export: background + fills + pencil strokes + line art.
    static func renderExport(
        geometry: TemplateGeometry,
        fills: [String: String],
        pencilImage: UIImage?,
        backgroundColor: UIColor,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)

            // 1. Background
            backgroundColor.setFill()
            context.fill(bounds)

            // 2. Fill layer
            let fillLayer = renderFillLayer(geometry: geometry, fills: fills, size: size)
            fillLayer.draw(in: bounds)

            // 3. Pencil strokes composited on top of fills
            if let pencilImage = pencilImage {
                pencilImage.draw(in: bounds)
            }

            // 4. Line art on top with multiply blend mode
            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.setBlendMode(.multiply)
            let lineArt = renderLineArt(geometry: geometry, size: size)
            lineArt.draw(in: bounds)
            cgContext.restoreGState()
        }
    }
}

// MARK: - UIColor Hex Parsing

private extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized
        guard hexSanitized.count == 6, let rgbValue = UInt64(hexSanitized, radix: 16) else { return nil }
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
