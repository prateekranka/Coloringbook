import UIKit
import CoreML
import CoreImage

// MARK: - Neural Edge Detector

/// Stage 3 (Artistic preset): runs the Informative Drawings CoreML model to produce
/// hand-drawn-style line art, replacing the XDoG stage only.
///
/// The model (InformativeDrawings.mlmodelc) must be bundled in the app under
/// `ColorFlow/Resources/Models/`. If the model is absent or fails to load,
/// this detector falls back to XDoG with `detailed` parameters and surfaces a
/// non-fatal `.modelUnavailable` error so the caller can inform the user.
///
/// **Memory invariant:** The model is loaded lazily on first call and released
/// immediately after inference completes. It is never held across invocations.
///
/// See `Scripts/coreml/README.md` for the conversion runbook.
enum NeuralEdgeDetector {

    // MARK: - Model name

    static let modelName = "InformativeDrawings"

    // MARK: - Result

    enum NeuralResult {
        case success(UIImage)
        case fallback(UIImage, PhotoPipelineError)  // model unavailable; XDoG used instead
    }

    // MARK: - Public API

    /// Detect edges using the bundled CoreML model, or fall back to XDoG Detailed.
    ///
    /// - Parameter image: Pre-processed, k-means segmented image.
    /// - Returns: `.success` with the neural edge image, or `.fallback` with a
    ///   XDoG result and the reason the model was unavailable.
    static func detect(_ image: UIImage) -> NeuralResult {
        // Try to load the bundled model
        guard let modelURL = Bundle.main.url(
            forResource: modelName,
            withExtension: "mlmodelc",
            subdirectory: "Models"
        ) ?? Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
        else {
            // Model not bundled yet (expected before C3 conversion spike completes)
            let fallback = XDoGEdgeDetector.detect(image, params: .detailed)
            return .fallback(fallback, .modelUnavailable(fallbackPreset: .detailed))
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // prefer Neural Engine + GPU
            let model = try MLModel(contentsOf: modelURL, configuration: config)
            let output = try runInference(model: model, image: image)
            return .success(output)
        } catch {
            // Load or inference failure — fall back gracefully
            let fallback = XDoGEdgeDetector.detect(image, params: .detailed)
            return .fallback(
                fallback,
                .modelUnavailable(fallbackPreset: .detailed)
            )
        }
    }

    // MARK: - Inference

    private static func runInference(model: MLModel, image: UIImage) throws -> UIImage {
        // Resize to the model's expected input size.
        // InformativeDrawings accepts 512×512 RGB input by default;
        // actual shape is validated at conversion time (see Scripts/coreml/README.md).
        let inputSize = CGSize(width: 512, height: 512)
        let resized = resize(image, to: inputSize)

        guard let cgImage = resized.cgImage else {
            throw PhotoPipelineError.processingFailed("Could not prepare neural input image")
        }

        // Convert to CVPixelBuffer for CoreML
        let pixelBuffer = try cgImageToPixelBuffer(cgImage, size: inputSize)

        // Run inference via generic MLFeatureProvider
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input": MLFeatureValue(pixelBuffer: pixelBuffer)
        ])
        let output = try model.prediction(from: inputFeatures)

        // Extract output — the model's output feature name depends on the conversion.
        // We try common names; the conversion runbook specifies the actual name.
        let outputKey = output.featureNames.first ?? "output"
        guard let outputBuffer = output.featureValue(for: outputKey)?.imageBufferValue else {
            throw PhotoPipelineError.processingFailed("Neural model output is not a pixel buffer")
        }

        let ciImage = CIImage(cvPixelBuffer: outputBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let outCG = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw PhotoPipelineError.processingFailed("Could not render neural output")
        }

        let outputImage = UIImage(cgImage: outCG, scale: image.scale, orientation: image.imageOrientation)

        // Scale back to original input dimensions
        return resize(outputImage, to: image.size)
    }

    // MARK: - Helpers

    private static func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func cgImageToPixelBuffer(_ cgImage: CGImage, size: CGSize) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey:   true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width), Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw PhotoPipelineError.processingFailed("Could not create CVPixelBuffer for neural input")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw PhotoPipelineError.processingFailed("CVPixelBuffer base address is nil")
        }
        let context = CGContext(
            data: baseAddress,
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
