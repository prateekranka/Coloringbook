import XCTest
@testable import ColorFlow

final class KMeansSegmenterTests: XCTestCase {

    // MARK: - Basic output shape

    func test_segment_returnsImageOfSameSize() {
        let input = makeGradientImage(width: 64, height: 64)
        let output = KMeansSegmenter.segment(input, k: 3)
        XCTAssertEqual(Int(output.size.width),  64)
        XCTAssertEqual(Int(output.size.height), 64)
    }

    func test_segment_k1_returnsUniformImage() {
        // With k=1 every pixel maps to the single centroid — image should be flat.
        let input = makeGradientImage(width: 32, height: 32)
        let output = KMeansSegmenter.segment(input, k: 1)
        XCTAssertNotNil(output.cgImage)
        let colours = uniqueColours(in: output)
        // k=1 → one or very few distinct colours
        XCTAssertLessThanOrEqual(colours.count, 2, "k=1 should produce at most 2 colours (rounding artefacts)")
    }

    func test_segment_k4_producesAtMost4Colours() {
        let input = makeGradientImage(width: 64, height: 64)
        let output = KMeansSegmenter.segment(input, k: 4)
        let colours = uniqueColours(in: output)
        XCTAssertLessThanOrEqual(colours.count, 4,
            "k=4 segmentation should produce at most 4 distinct colours")
    }

    func test_segment_solidColour_returns1Colour() {
        let input = makeSolidImage(width: 32, height: 32, color: .red)
        let output = KMeansSegmenter.segment(input, k: 5)
        let colours = uniqueColours(in: output)
        XCTAssertEqual(colours.count, 1, "Solid colour input should produce exactly 1 cluster")
    }

    func test_segment_doesNotCrashOnLargerK() {
        // k > pixel count — should clamp gracefully
        let input = makeGradientImage(width: 4, height: 4)  // 16 pixels
        let output = KMeansSegmenter.segment(input, k: 100)
        XCTAssertNotNil(output.cgImage)
    }

    // MARK: - Helpers

    private func makeGradientImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.red.cgColor, UIColor.blue.cgColor] as CFArray,
                locations: [0, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: CGFloat(width), y: 0),
                options: []
            )
        }
    }

    private func makeSolidImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// Returns the set of unique RGB tuples in the image (ignoring alpha).
    private func uniqueColours(in image: UIImage) -> Set<[Int]> {
        guard let cg = image.cgImage else { return [] }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var seen = Set<[Int]>()
        for i in 0..<(w * h) {
            seen.insert([Int(pixels[i*4]), Int(pixels[i*4+1]), Int(pixels[i*4+2])])
        }
        return seen
    }
}
