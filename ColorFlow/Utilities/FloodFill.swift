import UIKit
import CoreGraphics

// MARK: - Fill Bitmap

/// Off-screen RGBA pixel buffer used for flood fill operations.
struct FillBitmap {
    var pixels: [UInt8]   // RGBA, row-major
    let width: Int
    let height: Int

    // MARK: - Init

    init(size: CGSize) {
        self.width = Int(size.width)
        self.height = Int(size.height)
        self.pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    init(image: UIImage) {
        let size = image.size
        self.width = Int(size.width)
        self.height = Int(size.height)
        self.pixels = [UInt8](repeating: 0, count: width * height * 4)
        self.draw(image: image)
    }

    private mutating func draw(image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        pixels.withUnsafeMutableBytes { ptr in
            guard let ctx = CGContext(
                data: ptr.baseAddress,
                width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    // MARK: - Pixel Access

    func pixelIndex(x: Int, y: Int) -> Int { (y * width + x) * 4 }

    func color(at point: CGPoint) -> UIColor? {
        let x = Int(point.x), y = Int(point.y)
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        let i = pixelIndex(x: x, y: y)
        return UIColor(
            red: CGFloat(pixels[i]) / 255,
            green: CGFloat(pixels[i+1]) / 255,
            blue: CGFloat(pixels[i+2]) / 255,
            alpha: CGFloat(pixels[i+3]) / 255
        )
    }

    // MARK: - Export

    func toUIImage() -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var mutablePixels = pixels
        return mutablePixels.withUnsafeMutableBytes { ptr -> UIImage? in
            guard let ctx = CGContext(
                data: ptr.baseAddress,
                width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let cgImage = ctx.makeImage() else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
}

// MARK: - Flood Fill Engine

enum FloodFillEngine {

    /// Scanline flood fill. Runs on a background thread — call via Task.detached.
    /// - Parameters:
    ///   - bitmap: The RGBA fill bitmap (modified in place).
    ///   - at: Tap point in bitmap coordinates.
    ///   - with: Fill color.
    ///   - boundaryBitmap: Optional — template line art bitmap used as boundary detection.
    ///   - tolerance: Color similarity threshold (0–255 per channel).
    static func fill(
        bitmap: inout FillBitmap,
        at point: CGPoint,
        with fillUIColor: UIColor,
        boundaryBitmap: FillBitmap?,
        tolerance: Int = 40
    ) {
        let startX = Int(point.x)
        let startY = Int(point.y)
        guard startX >= 0, startX < bitmap.width,
              startY >= 0, startY < bitmap.height else { return }

        // Decompose fill color
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        fillUIColor.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        let fillR = UInt8(fr * 255), fillG = UInt8(fg * 255)
        let fillB = UInt8(fb * 255), fillA = UInt8(fa * 255)

        // Target color (the color we're replacing)
        let si = bitmap.pixelIndex(x: startX, y: startY)
        let targetR = bitmap.pixels[si]
        let targetG = bitmap.pixels[si+1]
        let targetB = bitmap.pixels[si+2]

        // Abort if target already matches fill
        if colorsMatch(r: targetR, g: targetG, b: targetB,
                       r2: fillR, g2: fillG, b2: fillB, tolerance: 2) { return }

        // Scanline stack-based flood fill
        var stack: [(Int, Int)] = [(startX, startY)]
        var visited = Set<Int>()  // pixel flat indices

        while !stack.isEmpty {
            let (cx, cy) = stack.removeLast()
            guard cx >= 0, cx < bitmap.width, cy >= 0, cy < bitmap.height else { continue }

            let flatIdx = cy * bitmap.width + cx
            guard !visited.contains(flatIdx) else { continue }

            let pixIdx = flatIdx * 4
            let pr = bitmap.pixels[pixIdx], pg = bitmap.pixels[pixIdx+1], pb = bitmap.pixels[pixIdx+2]

            // Stop at line art boundary
            if let boundary = boundaryBitmap, isLineArtBoundary(boundary, x: cx, y: cy) { continue }

            // Stop if pixel doesn't match target color
            guard colorsMatch(r: pr, g: pg, b: pb, r2: targetR, g2: targetG, b2: targetB, tolerance: tolerance) else { continue }

            // Fill this pixel
            visited.insert(flatIdx)
            bitmap.pixels[pixIdx] = fillR
            bitmap.pixels[pixIdx+1] = fillG
            bitmap.pixels[pixIdx+2] = fillB
            bitmap.pixels[pixIdx+3] = fillA

            // Scan horizontally to find full run, then push rows above/below
            var left = cx - 1
            while left >= 0 {
                let li = (cy * bitmap.width + left) * 4
                if let boundary = boundaryBitmap, isLineArtBoundary(boundary, x: left, y: cy) { break }
                let lr = bitmap.pixels[li], lg = bitmap.pixels[li+1], lb = bitmap.pixels[li+2]
                guard colorsMatch(r: lr, g: lg, b: lb, r2: targetR, g2: targetG, b2: targetB, tolerance: tolerance) else { break }
                let lFlat = cy * bitmap.width + left
                if !visited.contains(lFlat) {
                    visited.insert(lFlat)
                    bitmap.pixels[li] = fillR; bitmap.pixels[li+1] = fillG
                    bitmap.pixels[li+2] = fillB; bitmap.pixels[li+3] = fillA
                }
                stack.append((left, cy - 1))
                stack.append((left, cy + 1))
                left -= 1
            }

            var right = cx + 1
            while right < bitmap.width {
                let ri = (cy * bitmap.width + right) * 4
                if let boundary = boundaryBitmap, isLineArtBoundary(boundary, x: right, y: cy) { break }
                let rr = bitmap.pixels[ri], rg = bitmap.pixels[ri+1], rb = bitmap.pixels[ri+2]
                guard colorsMatch(r: rr, g: rg, b: rb, r2: targetR, g2: targetG, b2: targetB, tolerance: tolerance) else { break }
                let rFlat = cy * bitmap.width + right
                if !visited.contains(rFlat) {
                    visited.insert(rFlat)
                    bitmap.pixels[ri] = fillR; bitmap.pixels[ri+1] = fillG
                    bitmap.pixels[ri+2] = fillB; bitmap.pixels[ri+3] = fillA
                }
                stack.append((right, cy - 1))
                stack.append((right, cy + 1))
                right += 1
            }

            stack.append((cx, cy - 1))
            stack.append((cx, cy + 1))
        }
    }

    // MARK: - Helpers

    private static func colorsMatch(r: UInt8, g: UInt8, b: UInt8,
                                     r2: UInt8, g2: UInt8, b2: UInt8,
                                     tolerance: Int) -> Bool {
        abs(Int(r) - Int(r2)) <= tolerance &&
        abs(Int(g) - Int(g2)) <= tolerance &&
        abs(Int(b) - Int(b2)) <= tolerance
    }

    /// Returns true if the template pixel at (x,y) is a dark boundary line.
    /// Brightness threshold: pixels with luminance < 0.25 are treated as line art.
    private static func isLineArtBoundary(_ bitmap: FillBitmap, x: Int, y: Int) -> Bool {
        guard x >= 0, x < bitmap.width, y >= 0, y < bitmap.height else { return false }
        let i = bitmap.pixelIndex(x: x, y: y)
        let r = CGFloat(bitmap.pixels[i]) / 255
        let g = CGFloat(bitmap.pixels[i+1]) / 255
        let b = CGFloat(bitmap.pixels[i+2]) / 255
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.25
    }
}
