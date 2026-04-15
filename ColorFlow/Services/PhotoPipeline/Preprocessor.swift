import UIKit
import CoreImage

// MARK: - Preprocessor Parameters

struct PreprocessorParams {
    /// Radius of the bilateral / gaussian blur (higher = smoother, fewer noise regions).
    var blurRadius: Float
    /// Contrast boost applied before edge detection (1.0 = no change).
    var contrast: Float
    /// Saturation reduction before edge detection (0 = grayscale, 1 = original).
    var saturation: Float

    static let simple       = PreprocessorParams(blurRadius: 3.0, contrast: 1.1, saturation: 0.0)
    static let detailed     = PreprocessorParams(blurRadius: 1.5, contrast: 1.2, saturation: 0.0)
    static let boldOutlines = PreprocessorParams(blurRadius: 2.0, contrast: 1.3, saturation: 0.0)
}

// MARK: - Preprocessor

/// Stage 1: smooth and normalize the input image before segmentation.
///
/// Uses CIFilter bilateral approximation (Gaussian blur + contrast):
///   - `CIGaussianBlur` removes fine texture noise
///   - `CIColorControls` boosts contrast and desaturates to grey for better edge detection
enum Preprocessor {

    static func preprocess(_ image: UIImage, params: PreprocessorParams) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let context = CIContext(options: [.useSoftwareRenderer: false])

        // Step 1: Gaussian blur to remove fine noise
        let blurred: CIImage = {
            guard let filter = CIFilter(name: "CIGaussianBlur", parameters: [
                kCIInputImageKey:  ciImage,
                kCIInputRadiusKey: params.blurRadius
            ]) else { return ciImage }
            return filter.outputImage ?? ciImage
        }()

        // Step 2: Contrast boost + desaturate
        let adjusted: CIImage = {
            guard let filter = CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey:       blurred,
                kCIInputContrastKey:    params.contrast,
                kCIInputSaturationKey:  params.saturation,
                kCIInputBrightnessKey:  0.0
            ]) else { return blurred }
            return filter.outputImage ?? blurred
        }()

        // Crop back to original extent (CIGaussianBlur expands the extent)
        let cropped = adjusted.cropped(to: ciImage.extent)

        guard let cgImage = context.createCGImage(cropped, from: ciImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
