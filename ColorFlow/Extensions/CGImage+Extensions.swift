import CoreGraphics
import UIKit

extension CGImage {
    /// Creates a CGImage from an RGBA pixel buffer (UInt8 array).
    static func fromRGBAPixels(_ pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var mutablePixels = pixels
        return mutablePixels.withUnsafeMutableBytes { ptr -> CGImage? in
            guard let ctx = CGContext(
                data: ptr.baseAddress,
                width: width, height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return ctx.makeImage()
        }
    }

    /// Converts this CGImage to a UIImage.
    var uiImage: UIImage { UIImage(cgImage: self) }
}
