import XCTest
@testable import ColorFlow

final class AlgorithmicPhotoPipelineValidationTests: XCTestCase {

    func test_runRejectsUnreadableImageBeforeProcessingStages() async {
        let pipeline = AlgorithmicPhotoPipeline()

        let result = await pipeline.run(image: UIImage(), preset: .simple) { stage in
            XCTFail("Invalid images should fail before progress reaches \(stage).")
        }

        guard case .failure(.processingFailed(let detail)) = result else {
            XCTFail("Expected unreadable image to fail before pipeline work starts.")
            return
        }

        XCTAssertTrue(detail.contains("could not be read"))
    }

    func test_runRejectsTooSmallImageBeforeProcessingStages() async {
        let pipeline = AlgorithmicPhotoPipeline()

        let result = await pipeline.run(image: makeImage(width: 100, height: 120), preset: .simple) { stage in
            XCTFail("Too-small images should fail before progress reaches \(stage).")
        }

        guard case .failure(.imageTooSmall(let shortEdge, let minimum)) = result else {
            XCTFail("Expected too-small image to fail before pipeline work starts.")
            return
        }

        XCTAssertEqual(shortEdge, 100)
        XCTAssertEqual(minimum, PhotoPreValidator.minimumShortEdge)
    }

    private func makeImage(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
