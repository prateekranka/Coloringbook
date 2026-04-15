import UIKit
import Vision
import CoreGraphics

// MARK: - Contour Vectorizer

/// Stage 5: detect contours in the binary edge image using Vision's
/// `VNDetectContoursRequest` and return them as `CGPath` objects.
///
/// Each detected contour becomes a candidate fillable region (id="region-N").
/// Very small contours (area < minRegionArea) are treated as decorative noise.
enum ContourVectorizer {

    // MARK: - Result

    struct VectorizationResult {
        let regionPaths:    [CGPath]   // fillable regions (area ≥ minRegionArea)
        let decorativePaths: [CGPath]  // small noise contours
        let imageSize: CGSize
    }

    // MARK: - Parameters

    struct Params {
        /// Minimum bounding-box area (in pixels²) for a contour to become a region.
        var minRegionArea: CGFloat
        /// VNDetectContoursRequest contrast adjustment (0–1).
        var contrastAdjustment: Float

        static let simple       = Params(minRegionArea: 200, contrastAdjustment: 2.0)
        static let detailed     = Params(minRegionArea: 50,  contrastAdjustment: 1.5)
        static let boldOutlines = Params(minRegionArea: 200, contrastAdjustment: 2.0)
    }

    // MARK: - Public API

    static func detect(
        _ image: UIImage,
        params: Params
    ) throws -> VectorizationResult {
        guard let cgImage = image.cgImage else {
            throw PhotoPipelineError.processingFailed("ContourVectorizer: cgImage is nil")
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        var allNormalizedContours: [VNContour] = []
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = params.contrastAdjustment
        request.detectsDarkOnLight = true  // dark edges on white background

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        if let obs = request.results?.first as? VNContoursObservation {
            allNormalizedContours = (0..<obs.contourCount).compactMap {
                try? obs.contour(at: $0)
            }
        }

        var regionPaths: [CGPath]    = []
        var decorativePaths: [CGPath] = []

        for contour in allNormalizedContours {
            // Vision returns normalized coords [0,1] with Y flipped.
            // Convert to image-pixel coords.
            guard let path = normalizedContourToCGPath(
                contour,
                imageSize: imageSize
            ) else { continue }

            let bounds = path.boundingBox
            let area   = bounds.width * bounds.height

            if area >= params.minRegionArea {
                regionPaths.append(path)
            } else {
                decorativePaths.append(path)
            }
        }

        return VectorizationResult(
            regionPaths:    regionPaths,
            decorativePaths: decorativePaths,
            imageSize: imageSize
        )
    }

    // MARK: - CGPath conversion

    /// Convert a `VNContour` (normalized 0–1, Y-up) to a `CGPath` in pixel coords (Y-down).
    private static func normalizedContourToCGPath(
        _ contour: VNContour,
        imageSize: CGSize
    ) -> CGPath? {
        // Vision: normalized 0–1, origin bottom-left, Y up.
        // CoreGraphics: origin top-left, Y down.
        // Transform: scale to pixels, flip Y by translate(0, h) + scale(1, -1).
        var transform = CGAffineTransform.identity
            .translatedBy(x: 0, y: imageSize.height)
            .scaledBy(x: imageSize.width, y: -imageSize.height)

        guard let transformed = contour.normalizedPath.copy(using: &transform),
              !transformed.isEmpty
        else { return nil }

        // SVGParser requires a Z terminator on every region path.
        let mutable = CGMutablePath()
        mutable.addPath(transformed)
        mutable.closeSubpath()
        return mutable
    }
}
