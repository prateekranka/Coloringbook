import CoreGraphics
import Foundation

enum PhotoPipelineTemplateValidator {
    static let minimumFillableRegionCount = 3
    static let minimumRegionArea: CGFloat = 16
    static let minimumRegionCoverageRatio: CGFloat = 0.01

    static func validate(_ result: ContourVectorizer.VectorizationResult) -> PhotoPipelineError? {
        validate(
            regionBounds: result.regionPaths.map(\.boundingBoxOfPath),
            canvasSize: result.imageSize,
            stage: "vectorization"
        )
    }

    static func validate(_ geometry: TemplateGeometry) -> PhotoPipelineError? {
        validate(
            regionBounds: geometry.regions.map(\.bounds),
            canvasSize: geometry.viewBox.size,
            stage: "SVG parser parity"
        )
    }

    private static func validate(
        regionBounds: [CGRect],
        canvasSize: CGSize,
        stage: String
    ) -> PhotoPipelineError? {
        guard canvasSize.isUsableCanvasSize else {
            return .insufficientTemplateDetail("\(stage) produced an invalid canvas size.")
        }

        let meaningfulBounds = regionBounds.filter { bounds in
            bounds.isUsableRegionBounds && bounds.area >= minimumRegionArea
        }

        guard meaningfulBounds.count >= minimumFillableRegionCount else {
            return .insufficientTemplateDetail(
                "\(stage) found \(meaningfulBounds.count) usable fill regions; at least \(minimumFillableRegionCount) are needed."
            )
        }

        let canvasArea = canvasSize.width * canvasSize.height
        let coveredArea = meaningfulBounds.reduce(CGFloat.zero) { partial, bounds in
            partial + min(bounds.area, canvasArea)
        }
        let coverageRatio = coveredArea / canvasArea

        guard coverageRatio >= minimumRegionCoverageRatio else {
            return .insufficientTemplateDetail(
                "\(stage) found regions covering \(Self.percentString(coverageRatio)) of the image; at least \(Self.percentString(minimumRegionCoverageRatio)) is needed."
            )
        }

        return nil
    }

    private static func percentString(_ value: CGFloat) -> String {
        let percent = Double(value * 100)
        return String(format: "%.1f%%", percent)
    }
}

private extension CGSize {
    var isUsableCanvasSize: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

private extension CGRect {
    var area: CGFloat { width * height }

    var isUsableRegionBounds: Bool {
        !isNull && !isInfinite && width.isFinite && height.isFinite && width > 0 && height > 0
    }
}
