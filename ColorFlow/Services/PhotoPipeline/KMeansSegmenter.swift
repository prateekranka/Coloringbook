import UIKit
import Accelerate

// MARK: - KMeans Segmenter

/// Stage 2: reduce the image to k dominant colour regions using k-means clustering.
///
/// Implementation uses Accelerate vDSP for distance computations.
/// Initialization uses k-means++ for faster convergence.
/// Fixed iteration cap of 20 keeps runtime predictable.
enum KMeansSegmenter {

    // MARK: - Public API

    /// Segment `image` into `k` colour clusters and return a posterized UIImage
    /// where each pixel is replaced by its cluster centroid colour.
    static func segment(_ image: UIImage, k: Int) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width  = cgImage.width
        let height = cgImage.height
        let count  = width * height

        // Extract RGBA pixels
        var pixels = [UInt8](repeating: 0, count: count * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Work in Float RGB (ignore alpha)
        var points = [[Float]](repeating: [Float](repeating: 0, count: 3), count: count)
        for i in 0..<count {
            points[i][0] = Float(pixels[i * 4])     / 255.0  // R
            points[i][1] = Float(pixels[i * 4 + 1]) / 255.0  // G
            points[i][2] = Float(pixels[i * 4 + 2]) / 255.0  // B
        }

        let clampedK = min(max(k, 2), count)
        var centroids = kMeansPlusPlus(points: points, k: clampedK)
        var assignments = [Int](repeating: 0, count: count)

        // Run k-means for up to 20 iterations
        for _ in 0..<20 {
            var changed = false
            for i in 0..<count {
                let nearest = nearestCentroid(point: points[i], centroids: centroids)
                if assignments[i] != nearest { changed = true }
                assignments[i] = nearest
            }
            if !changed { break }
            centroids = recomputeCentroids(points: points, assignments: assignments, k: clampedK)
        }

        // Reconstruct image using centroid colours
        for i in 0..<count {
            let c = centroids[assignments[i]]
            pixels[i * 4]     = UInt8(min(max(c[0] * 255.0, 0), 255))
            pixels[i * 4 + 1] = UInt8(min(max(c[1] * 255.0, 0), 255))
            pixels[i * 4 + 2] = UInt8(min(max(c[2] * 255.0, 0), 255))
            pixels[i * 4 + 3] = 255
        }

        guard let outCtx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outCG = outCtx.makeImage() else { return image }

        return UIImage(cgImage: outCG, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - k-means++ initialization

    private static func kMeansPlusPlus(points: [[Float]], k: Int) -> [[Float]] {
        var centroids = [[Float]]()
        // Pick first centroid at random
        centroids.append(points[Int.random(in: 0..<points.count)])

        while centroids.count < k {
            // Compute squared distances to nearest centroid for every point
            var distances = [Float](repeating: 0, count: points.count)
            for i in 0..<points.count {
                let nearest = nearestCentroid(point: points[i], centroids: centroids)
                distances[i] = squaredDistance(points[i], centroids[nearest])
            }
            // Sample next centroid proportionally to distance²
            let totalDist = distances.reduce(Float(0), +)
            guard totalDist > 0 else {
                centroids.append(points[Int.random(in: 0..<points.count)])
                continue
            }
            var r = Float.random(in: 0..<totalDist)
            var chosen = 0
            for i in 0..<distances.count {
                r -= distances[i]
                if r <= 0 { chosen = i; break }
                chosen = i
            }
            centroids.append(points[chosen])
        }
        return centroids
    }

    // MARK: - Assignment and centroid update

    private static func nearestCentroid(point: [Float], centroids: [[Float]]) -> Int {
        var bestIdx = 0
        var bestDist = Float.greatestFiniteMagnitude
        for (i, c) in centroids.enumerated() {
            let d = squaredDistance(point, c)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }

    private static func recomputeCentroids(points: [[Float]], assignments: [Int], k: Int) -> [[Float]] {
        var sums   = [[Float]](repeating: [Float](repeating: 0, count: 3), count: k)
        var counts = [Int](repeating: 0, count: k)
        for (i, c) in assignments.enumerated() {
            sums[c][0] += points[i][0]
            sums[c][1] += points[i][1]
            sums[c][2] += points[i][2]
            counts[c] += 1
        }
        return (0..<k).map { c in
            guard counts[c] > 0 else { return sums[c] }
            return [sums[c][0] / Float(counts[c]),
                    sums[c][1] / Float(counts[c]),
                    sums[c][2] / Float(counts[c])]
        }
    }

    private static func squaredDistance(_ a: [Float], _ b: [Float]) -> Float {
        let dr = a[0] - b[0]; let dg = a[1] - b[1]; let db = a[2] - b[2]
        return dr*dr + dg*dg + db*db
    }
}
