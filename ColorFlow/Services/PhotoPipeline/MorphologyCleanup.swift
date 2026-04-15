import UIKit
import CoreImage
import MetalPerformanceShaders

// MARK: - Morphology Cleanup

/// Stage 4: binary morphology to clean up edge noise and (for Bold Outlines) dilate lines.
///
/// MPS path (MPSImageDilate / MPSImageErode) preferred when GPU is available.
/// CIFilter morphology fallback for simulator / unsupported hardware.
enum MorphologyCleanup {

    // MARK: - Public API

    /// Close small gaps (erosion → dilation) and optionally dilate for bold outlines.
    /// - Parameters:
    ///   - image: Grayscale edge image from `XDoGEdgeDetector`.
    ///   - dilationRadius: Extra dilation pixels (0 = none, 4 = Bold Outlines).
    static func clean(_ image: UIImage, dilationRadius: Int) -> UIImage {
        guard dilationRadius > 0 else { return image }

        if let device = MTLCreateSystemDefaultDevice() {
            return cleanMPS(image: image, dilationRadius: dilationRadius, device: device)
                ?? cleanCI(image: image, dilationRadius: dilationRadius)
        }
        return cleanCI(image: image, dilationRadius: dilationRadius)
    }

    // MARK: - MPS path

    private static func cleanMPS(image: UIImage, dilationRadius: Int, device: MTLDevice) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width  = cgImage.width
        let height = cgImage.height

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        guard let texIn  = device.makeTexture(descriptor: descriptor),
              let texOut = device.makeTexture(descriptor: descriptor),
              let queue  = device.makeCommandQueue(),
              let cmdBuf = queue.makeCommandBuffer() else { return nil }

        // Upload
        var pixels = [UInt8](repeating: 0, count: width * height)
        let space = CGColorSpaceCreateDeviceGray()
        if let ctx = CGContext(data: &pixels, width: width, height: height,
                               bitsPerComponent: 8, bytesPerRow: width,
                               space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) {
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        texIn.replace(region: MTLRegionMake2D(0, 0, width, height),
                      mipmapLevel: 0, withBytes: pixels, bytesPerRow: width)

        let kernelSize = dilationRadius * 2 + 1
        // MPSImageDilate needs a flat probe kernel (all zeros or use distance kernel).
        // Use a simple box dilate via MPSImageAreaMax for binary images.
        let dilate = MPSImageAreaMax(device: device, kernelWidth: kernelSize, kernelHeight: kernelSize)
        dilate.encode(commandBuffer: cmdBuf, sourceTexture: texIn, destinationTexture: texOut)

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        var result = [UInt8](repeating: 0, count: width * height)
        texOut.getBytes(&result, bytesPerRow: width,
                        from: MTLRegionMake2D(0, 0, width, height),
                        mipmapLevel: 0)

        var mutable = result
        guard let ctx2 = CGContext(data: &mutable, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: width,
                                   space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let cg = ctx2.makeImage() else { return nil }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - CIFilter fallback

    private static func cleanCI(image: UIImage, dilationRadius: Int) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext(options: [.useSoftwareRenderer: true])

        guard let morpho = CIFilter(name: "CIMorphologyMaximum", parameters: [
            kCIInputImageKey:  ciImage,
            kCIInputRadiusKey: dilationRadius
        ])?.outputImage?.cropped(to: ciImage.extent),
              let cg = context.createCGImage(morpho, from: ciImage.extent)
        else { return image }

        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
