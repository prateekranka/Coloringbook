import UIKit
import CoreImage

// MARK: - Validation Result

enum PhotoValidationResult: Equatable {
    case valid
    case invalidImage
    case tooSmall(shortEdge: Int, minimum: Int)
    case lowContrast    // flat histogram — warning, not a hard rejection
    case blurry         // low Laplacian variance — warning, not a hard rejection
}

// MARK: - PhotoPreValidator

/// Validates a user-provided photo before it enters the pipeline.
///
/// Hard rejections (returns non-valid result the UI must show and block):
///   - Image data cannot be read
///   - Image smaller than 640px on the short edge
///
/// Soft warnings (UI shows a message but lets the user proceed):
///   - Flat histogram (nearly-blank / very low contrast)
///   - Laplacian blur metric too low (blurry image)
struct PhotoPreValidator {

    /// Minimum pixels on the short edge.
    static let minimumShortEdge: Int = 640

    /// Fraction of pixels that must differ from the mean by at least this
    /// normalized value (0–1) for the image to be considered non-flat.
    static let contrastThreshold: Float = 0.04

    // MARK: - Public API

    /// Returns the first issue found, or `.valid` if the image passes all checks.
    /// Hard failures come before soft warnings so callers see the blocker first.
    static func validate(_ image: UIImage) -> PhotoValidationResult {
        guard let pixelSize = pixelSize(of: image) else {
            return .invalidImage
        }

        let shortEdge = Int(floor(min(pixelSize.width, pixelSize.height)))

        if shortEdge < minimumShortEdge {
            return .tooSmall(shortEdge: shortEdge, minimum: minimumShortEdge)
        }

        // Downsample for metric computation — we don't need full resolution.
        guard let small = downsampled(image, maxEdge: 256) else {
            return .valid   // can't compute metrics, let it through
        }

        if isLowContrast(small) { return .lowContrast }
        if isBlurry(small)      { return .blurry }

        return .valid
    }

    // MARK: - Contrast check

    /// Returns true when the image has very little variance (near-blank, pure gradient, etc.)
    static func isLowContrast(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width  = cgImage.width
        let height = cgImage.height
        let count  = width * height

        var pixels = [UInt8](repeating: 0, count: count)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sum = pixels.reduce(0, { $0 + Int($1) })
        let mean = Float(sum) / Float(count)
        let variance = pixels.reduce(Float(0)) { acc, p in
            let d = Float(p) / 255.0 - mean / 255.0
            return acc + d * d
        } / Float(count)

        return variance < (contrastThreshold * contrastThreshold)
    }

    // MARK: - Blur check (Laplacian variance)

    /// Returns true when the Laplacian variance is below a threshold (image is blurry).
    static func isBlurry(_ image: UIImage) -> Bool {
        guard let ciImage = CIImage(image: image) else { return false }
        let laplacian = CIFilter(name: "CIConvolution3X3", parameters: [
            "inputWeights": CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9),
            "inputBias":    0.0,
            kCIInputImageKey: ciImage
        ])
        guard let output = laplacian?.outputImage else { return false }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        let extent  = output.extent.intersection(CGRect(x: 0, y: 0, width: 256, height: 256))
        guard !extent.isNull, !extent.isInfinite,
              let cgImage = context.createCGImage(output, from: extent) else { return false }

        let width  = cgImage.width
        let height = cgImage.height
        let count  = width * height
        var pixels = [UInt8](repeating: 0, count: count)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return false }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let mean = Float(pixels.reduce(0, { $0 + Int($1) })) / Float(count)
        let variance = pixels.reduce(Float(0)) { acc, p in
            let d = Float(p) - mean; return acc + d * d
        } / Float(count)

        // Empirically: clear images ≥ 100, blurry images < 40
        return variance < 40.0
    }

    // MARK: - Helpers

    private static func downsampled(_ image: UIImage, maxEdge: Int) -> UIImage? {
        let size = image.size
        let scale = min(CGFloat(maxEdge) / max(size.width, size.height), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func pixelSize(of image: UIImage) -> CGSize? {
        if let cgImage = image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        if let ciImage = image.ciImage {
            let extent = ciImage.extent
            guard extent.isUsablePixelExtent else { return nil }
            return extent.size
        }

        let scaledSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        guard scaledSize.isUsablePixelSize else { return nil }
        return scaledSize
    }
}

private extension CGSize {
    var isUsablePixelSize: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

private extension CGRect {
    var isUsablePixelExtent: Bool {
        !isNull && !isInfinite && size.isUsablePixelSize
    }
}
