import UIKit
import CoreImage
import MetalPerformanceShaders

// MARK: - XDoG Parameters

struct XDoGParams {
    /// Standard deviation of the tighter Gaussian (σ₁).
    var sigma1: Float
    /// Standard deviation of the wider Gaussian (σ₂ = sigma1 * sigmaMul).
    var sigmaMul: Float  // σ₂ = σ₁ × sigmaMul
    /// Soft-threshold sharpness (higher = crisper edges).
    var tau: Float
    /// Threshold below which values are clamped to white (controls line density).
    var epsilon: Float

    static let simple       = XDoGParams(sigma1: 2.0, sigmaMul: 1.6, tau: 0.99, epsilon: -0.1)
    static let detailed     = XDoGParams(sigma1: 1.0, sigmaMul: 1.6, tau: 0.98, epsilon: -0.1)
    static let boldOutlines = XDoGParams(sigma1: 2.0, sigmaMul: 1.6, tau: 0.95, epsilon: -0.2)
}

// MARK: - XDoG Edge Detector

/// Stage 3 (algorithmic branch): eXtended Difference-of-Gaussians edge detection.
///
/// Preferred path uses MetalPerformanceShaders (GPU):
///   two MPSImageGaussianBlur passes + weighted subtract + soft tanh threshold.
///
/// Fallback to CIFilter-based implementation when MPS is unavailable
/// (e.g., simulator without GPU) or when the Metal device is nil.
enum XDoGEdgeDetector {

    // MARK: - Public API

    /// Returns a grayscale edge image where edges are dark on a white background.
    static func detect(_ image: UIImage, params: XDoGParams) -> UIImage {
        if let device = MTLCreateSystemDefaultDevice() {
            return detectMPS(image: image, params: params, device: device)
                ?? detectCI(image: image, params: params)
        }
        return detectCI(image: image, params: params)
    }

    // MARK: - MPS path

    private static func detectMPS(image: UIImage, params: XDoGParams, device: MTLDevice) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width  = cgImage.width
        let height = cgImage.height

        // Pixel format: R8Unorm (grayscale)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width, height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        guard let texIn  = device.makeTexture(descriptor: descriptor),
              let texG1  = device.makeTexture(descriptor: descriptor),
              let texG2  = device.makeTexture(descriptor: descriptor),
              let queue  = device.makeCommandQueue() else { return nil }

        // Upload greyscale image
        uploadGrayscale(cgImage: cgImage, to: texIn, width: width, height: height)

        guard let cmdBuf = queue.makeCommandBuffer() else { return nil }

        // Gaussian blur σ₁
        let blur1 = MPSImageGaussianBlur(device: device, sigma: params.sigma1)
        blur1.encode(commandBuffer: cmdBuf, sourceTexture: texIn, destinationTexture: texG1)

        // Gaussian blur σ₂ = σ₁ × sigmaMul
        let blur2 = MPSImageGaussianBlur(device: device, sigma: params.sigma1 * params.sigmaMul)
        blur2.encode(commandBuffer: cmdBuf, sourceTexture: texIn, destinationTexture: texG2)

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        // Read back both textures and compute DoG + soft threshold on CPU
        let g1 = readGrayscale(texture: texG1, width: width, height: height)
        let g2 = readGrayscale(texture: texG2, width: width, height: height)

        var result = [UInt8](repeating: 255, count: width * height)
        for i in 0..<(width * height) {
            let f1 = Float(g1[i]) / 255.0
            let f2 = Float(g2[i]) / 255.0
            // XDoG formula: (1+tau) * G1 - tau * G2, then soft threshold
            let dog = (1.0 + params.tau) * f1 - params.tau * f2
            // Soft threshold via tanh; edges where dog < epsilon become dark
            let xdog: Float = dog >= params.epsilon ? 1.0 : 1.0 + tanh(dog - params.epsilon)
            result[i] = UInt8(min(max(xdog * 255.0, 0), 255))
        }

        return buildGrayscaleImage(pixels: result, width: width, height: height,
                                   scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - CIFilter fallback

    private static func detectCI(image: UIImage, params: XDoGParams) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext(options: [.useSoftwareRenderer: true])

        func gaussianBlur(_ src: CIImage, radius: Float) -> CIImage {
            CIFilter(name: "CIGaussianBlur", parameters: [
                kCIInputImageKey: src,
                kCIInputRadiusKey: radius
            ])?.outputImage?.cropped(to: src.extent) ?? src
        }

        let g1 = gaussianBlur(ciImage, radius: params.sigma1)
        let g2 = gaussianBlur(ciImage, radius: params.sigma1 * params.sigmaMul)

        // Subtract: DoG = g1 - tau*(g2-g1)  — approximate via blend
        guard let diff = CIFilter(name: "CISubtractBlendMode", parameters: [
            kCIInputImageKey:           g2,
            kCIInputBackgroundImageKey: g1
        ])?.outputImage?.cropped(to: ciImage.extent) else { return image }

        // Threshold
        guard let thresholded = CIFilter(name: "CIColorThreshold", parameters: [
            kCIInputImageKey:    diff,
            "inputThreshold":    0.5
        ])?.outputImage?.cropped(to: ciImage.extent) else { return image }

        guard let cg = context.createCGImage(thresholded, from: ciImage.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Texture helpers

    private static func uploadGrayscale(cgImage: CGImage, to texture: MTLTexture, width: Int, height: Int) {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let space = CGColorSpaceCreateDeviceGray()
        if let ctx = CGContext(data: &pixels, width: width, height: height,
                               bitsPerComponent: 8, bytesPerRow: width,
                               space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) {
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height),
                        mipmapLevel: 0,
                        withBytes: pixels,
                        bytesPerRow: width)
    }

    private static func readGrayscale(texture: MTLTexture, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        texture.getBytes(&pixels, bytesPerRow: width,
                         from: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0)
        return pixels
    }

    private static func buildGrayscaleImage(
        pixels: [UInt8], width: Int, height: Int,
        scale: CGFloat, orientation: UIImage.Orientation
    ) -> UIImage? {
        var mutable = pixels
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &mutable, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: orientation)
    }
}
