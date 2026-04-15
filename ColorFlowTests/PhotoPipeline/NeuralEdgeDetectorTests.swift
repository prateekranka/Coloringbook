import XCTest
@testable import ColorFlow

/// Tests for NeuralEdgeDetector.
///
/// The Informative Drawings model is not bundled in the repo (it requires a
/// one-time conversion spike on a machine with PyTorch). Therefore these tests
/// verify the *fallback behaviour* — that the detector degrades gracefully when
/// the model is absent — and the *integration contract* — that its output is
/// consumable by the rest of the pipeline.
final class NeuralEdgeDetectorTests: XCTestCase {

    // MARK: - Model availability

    /// When the model is not bundled, the detector must return a `.fallback`
    /// result rather than throwing or returning `.success` silently.
    func test_modelAbsent_returnsFallback() {
        let input = makeTestImage(width: 64, height: 64)
        let result = NeuralEdgeDetector.detect(input)

        // If the model is absent, we expect .fallback.
        // If the model IS present (after conversion), this test will receive .success — also fine.
        switch result {
        case .success(let img):
            // Model is present and inference succeeded — verify output shape.
            XCTAssertGreaterThan(img.size.width,  0, "Neural output must have positive width")
            XCTAssertGreaterThan(img.size.height, 0, "Neural output must have positive height")

        case .fallback(let img, let error):
            // Expected when model is not bundled.
            XCTAssertGreaterThan(img.size.width,  0, "Fallback image must have positive width")
            XCTAssertGreaterThan(img.size.height, 0, "Fallback image must have positive height")

            if case .modelUnavailable(let fallbackPreset) = error {
                XCTAssertEqual(fallbackPreset, .detailed,
                    "Fallback should use Detailed preset when Artistic model is unavailable")
            } else {
                XCTFail("Unexpected fallback error: \(error)")
            }
        }
    }

    // MARK: - Output contract

    /// Whatever the detector returns (neural or XDoG fallback), the output image
    /// must be usable as input to the next pipeline stage (ContourVectorizer).
    func test_output_canBePassedToContourVectorizer() throws {
        let input = makeTestImage(width: 128, height: 128)
        let edgeImage: UIImage = {
            switch NeuralEdgeDetector.detect(input) {
            case .success(let img): return img
            case .fallback(let img, _): return img
            }
        }()

        // ContourVectorizer.detect should not throw on any valid UIImage
        let result = try ContourVectorizer.detect(
            edgeImage,
            params: .detailed
        )
        // Any result (including empty regions) is acceptable — just must not crash
        XCTAssertNotNil(result.imageSize)
    }

    // MARK: - Helpers

    private func makeTestImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            // Checkerboard for non-trivial content
            let tileSize: CGFloat = 16
            for row in stride(from: 0, to: CGFloat(height), by: tileSize) {
                for col in stride(from: 0, to: CGFloat(width), by: tileSize) {
                    let isWhite = (Int(row / tileSize) + Int(col / tileSize)) % 2 == 0
                    (isWhite ? UIColor.white : UIColor.black).setFill()
                    context.fill(CGRect(x: col, y: row, width: tileSize, height: tileSize))
                }
            }
        }
    }
}
