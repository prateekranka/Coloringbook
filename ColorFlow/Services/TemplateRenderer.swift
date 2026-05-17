import UIKit
import CoreGraphics

struct TemplateRenderer {

    // MARK: - Coordinate Transform

    static func documentToViewTransform(viewBox: CGRect, viewSize: CGSize) -> CGAffineTransform {
        let scale = min(viewSize.width / viewBox.width, viewSize.height / viewBox.height)
        let tx = (viewSize.width - viewBox.width * scale) / 2
        let ty = (viewSize.height - viewBox.height * scale) / 2
        return CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scale, y: scale)
    }

    // MARK: - Fill Layer

    static func renderFillLayer(
        geometry: TemplateGeometry,
        fills: [String: String],
        size: CGSize
    ) -> UIImage {
        let sortedRegions = geometry.regions.sorted { $0.zIndex < $1.zIndex }
        let holeMap = Self.computeHoleMap(regions: sortedRegions)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let transform = documentToViewTransform(viewBox: geometry.viewBox, viewSize: size)
            cgContext.concatenate(transform)

            for region in sortedRegions {
                guard let hexColor = fills[region.id] else { continue }
                let color = UIColor(hex: hexColor)
                let holes = holeMap[region.id] ?? []

                cgContext.saveGState()
                cgContext.addPath(region.path)
                for hole in holes {
                    cgContext.addPath(hole.path)
                }
                cgContext.clip(using: .evenOdd)
                cgContext.setFillColor(color.cgColor)
                cgContext.fill(region.bounds)
                cgContext.restoreGState()
            }
        }
    }

    private static func computeHoleMap(regions: [RegionGeometry]) -> [String: [RegionGeometry]] {
        var map: [String: [RegionGeometry]] = [:]
        for region in regions {
            var holes: [RegionGeometry] = []
            for candidate in regions where candidate.zIndex > region.zIndex {
                guard region.bounds.contains(candidate.bounds) else { continue }
                let candidateCenter = CGPoint(x: candidate.bounds.midX, y: candidate.bounds.midY)
                guard region.path.contains(candidateCenter, using: region.fillRule) else { continue }
                holes.append(candidate)
            }
            if !holes.isEmpty {
                map[region.id] = holes
            }
        }
        return map
    }

    // MARK: - Line Art

    static func renderLineArt(
        geometry: TemplateGeometry,
        size: CGSize,
        strokeColor: UIColor = .black,
        strokeWidthPixels: CGFloat = 5
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let transform = documentToViewTransform(viewBox: geometry.viewBox, viewSize: size)
            cgContext.concatenate(transform)

            let scale = min(size.width / geometry.viewBox.width, size.height / geometry.viewBox.height)
            let strokeWidth = strokeWidthPixels / scale

            cgContext.setStrokeColor(strokeColor.cgColor)
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

    static func thumbnail(
        for template: Template,
        fills: [String: String] = [:],
        size: CGSize = CGSize(width: 400, height: 400),
        strokeWidthPixels: CGFloat = 2.4
    ) async -> UIImage? {
        guard let url = template.svgURL else { return nil }
        let lineArtURL = template.lineArtURL
        return await Task.detached(priority: .userInitiated) {
            guard case .success(let geo) = SVGParser.parse(url: url) else { return nil }
            let lineArtImage = lineArtURL.flatMap { UIImage(contentsOfFile: $0.path) }
            return renderThumbnail(
                geometry: geo,
                fills: fills,
                size: size,
                lineArtImage: lineArtImage,
                strokeWidthPixels: strokeWidthPixels
            )
        }.value
    }

    static func thumbnail(
        for template: Template,
        fillLayer: UIImage?,
        size: CGSize = CGSize(width: 400, height: 400),
        strokeWidthPixels: CGFloat = 2.4
    ) async -> UIImage? {
        guard let url = template.svgURL else { return nil }
        let lineArtURL = template.lineArtURL
        return await Task.detached(priority: .userInitiated) {
            guard case .success(let geo) = SVGParser.parse(url: url) else { return nil }
            let lineArtImage = lineArtURL.flatMap { UIImage(contentsOfFile: $0.path) }
            return renderThumbnail(
                geometry: geo,
                fillLayer: fillLayer,
                size: size,
                lineArtImage: lineArtImage,
                strokeWidthPixels: strokeWidthPixels
            )
        }.value
    }

    static func renderThumbnail(
        geometry: TemplateGeometry,
        fills: [String: String] = [:],
        size: CGSize = CGSize(width: 400, height: 400),
        lineArtImage: UIImage? = nil,
        strokeWidthPixels: CGFloat = 2.4
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let inset = min(size.width, size.height) * 0.04
            let artBounds = bounds.insetBy(dx: inset, dy: inset)
            let artSize = artBounds.size

            UIColor(hex: SableTheme.creamHex).setFill()
            context.fill(bounds)

            if !fills.isEmpty {
                let fillLayer = renderFillLayer(geometry: geometry, fills: fills, size: artSize)
                fillLayer.draw(in: artBounds)
            }

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.setBlendMode(.multiply)
            if let lineArtImage {
                drawLineArtImage(lineArtImage, geometry: geometry, in: artBounds)
            } else {
                let lineArt = renderLineArt(
                    geometry: geometry,
                    size: artSize,
                    strokeWidthPixels: strokeWidthPixels
                )
                lineArt.draw(in: artBounds)
            }
            cgContext.restoreGState()
        }
    }

    static func renderThumbnail(
        geometry: TemplateGeometry,
        fillLayer: UIImage?,
        size: CGSize = CGSize(width: 400, height: 400),
        lineArtImage: UIImage? = nil,
        strokeWidthPixels: CGFloat = 2.4
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let inset = min(size.width, size.height) * 0.04
            let artBounds = bounds.insetBy(dx: inset, dy: inset)
            let artSize = artBounds.size

            UIColor(hex: SableTheme.creamHex).setFill()
            context.fill(bounds)

            fillLayer?.draw(in: artBounds)

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.setBlendMode(.multiply)
            if let lineArtImage {
                drawLineArtImage(lineArtImage, geometry: geometry, in: artBounds)
            } else {
                let lineArt = renderLineArt(
                    geometry: geometry,
                    size: artSize,
                    strokeWidthPixels: strokeWidthPixels
                )
                lineArt.draw(in: artBounds)
            }
            cgContext.restoreGState()
        }
    }

    private static func drawLineArtImage(
        _ image: UIImage,
        geometry: TemplateGeometry,
        in bounds: CGRect
    ) {
        let viewBoxSize = geometry.viewBox.size
        let scale = min(bounds.width / viewBoxSize.width, bounds.height / viewBoxSize.height)
        let fittedSize = CGSize(width: viewBoxSize.width * scale, height: viewBoxSize.height * scale)
        let fittedRect = CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
        image.draw(in: fittedRect)
    }

    // MARK: - Export

    static func renderExport(
        geometry: TemplateGeometry,
        fills: [String: String],
        pigmentLayer: UIImage? = nil,
        pencilImage: UIImage?,
        backgroundColor: UIColor,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)

            backgroundColor.setFill()
            context.fill(bounds)

            if let pigmentLayer {
                pigmentLayer.draw(in: bounds)
            } else {
                let fillLayer = renderFillLayer(geometry: geometry, fills: fills, size: size)
                fillLayer.draw(in: bounds)
            }

            if let pencilImage = pencilImage {
                pencilImage.draw(in: bounds)
            }

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.setBlendMode(.multiply)
            let lineArt = renderLineArt(geometry: geometry, size: size)
            lineArt.draw(in: bounds)
            cgContext.restoreGState()
        }
    }
}
