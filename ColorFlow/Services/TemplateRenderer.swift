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
        strokeColor: UIColor = UIColor(AppTheme.Ink.lineArt)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let transform = documentToViewTransform(viewBox: geometry.viewBox, viewSize: size)
            cgContext.concatenate(transform)

            let scale = min(size.width / geometry.viewBox.width, size.height / geometry.viewBox.height)
            let strokeWidth = 3.0 / scale

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

            backgroundColor.setFill()
            context.fill(bounds)

            let fillLayer = renderFillLayer(geometry: geometry, fills: fills, size: size)
            fillLayer.draw(in: bounds)

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