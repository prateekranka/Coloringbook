import UIKit

enum PixelSampler {

    struct RGBA {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat
    }

    static func meanColor(of image: UIImage, in rect: CGRect) -> RGBA? {
        guard let cgImage = image.cgImage else { return nil }

        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height
        let pixelRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.size.width * scaleX,
            height: rect.size.height * scaleY
        ).integral

        let width = Int(pixelRect.width)
        let height = Int(pixelRect.height)
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(
            x: -pixelRect.origin.x,
            y: -(CGFloat(cgImage.height) - pixelRect.origin.y - pixelRect.height),
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        ))

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var totalA: CGFloat = 0
        let count = width * height

        for i in 0..<count {
            let offset = i * bytesPerPixel
            totalR += CGFloat(pixelData[offset])
            totalG += CGFloat(pixelData[offset + 1])
            totalB += CGFloat(pixelData[offset + 2])
            totalA += CGFloat(pixelData[offset + 3])
        }

        let n = CGFloat(count)
        return RGBA(r: totalR / n, g: totalG / n, b: totalB / n, a: totalA / n)
    }

    static func redPixelCount(
        of image: UIImage,
        in rect: CGRect,
        threshold: CGFloat = 100
    ) -> Int {
        guard let cgImage = image.cgImage else { return 0 }

        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height
        let pixelRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.size.width * scaleX,
            height: rect.size.height * scaleY
        ).integral

        let width = Int(pixelRect.width)
        let height = Int(pixelRect.height)
        guard width > 0, height > 0 else { return 0 }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(
            x: -pixelRect.origin.x,
            y: -(CGFloat(cgImage.height) - pixelRect.origin.y - pixelRect.height),
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        ))

        var count = 0
        let total = width * height
        for i in 0..<total {
            let offset = i * bytesPerPixel
            if CGFloat(pixelData[offset]) > threshold {
                count += 1
            }
        }
        return count
    }

    static func nonWhitePixelCount(
        of image: UIImage,
        in rect: CGRect,
        whiteThreshold: UInt8 = 245
    ) -> Int {
        guard let cgImage = image.cgImage else { return 0 }

        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height
        let pixelRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.size.width * scaleX,
            height: rect.size.height * scaleY
        ).integral

        let width = Int(pixelRect.width)
        let height = Int(pixelRect.height)
        guard width > 0, height > 0 else { return 0 }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(
            x: -pixelRect.origin.x,
            y: -(CGFloat(cgImage.height) - pixelRect.origin.y - pixelRect.height),
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        ))

        var count = 0
        let total = width * height
        for i in 0..<total {
            let offset = i * bytesPerPixel
            let r = pixelData[offset]
            let g = pixelData[offset + 1]
            let b = pixelData[offset + 2]
            if r < whiteThreshold || g < whiteThreshold || b < whiteThreshold {
                count += 1
            }
        }
        return count
    }
}
