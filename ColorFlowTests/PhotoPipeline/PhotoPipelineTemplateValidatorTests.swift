import XCTest
@testable import ColorFlow

final class PhotoPipelineTemplateValidatorTests: XCTestCase {

    func test_vectorizationWithNoRegions_isRejectedBeforeSVGAssembly() {
        let result = makeResult(regionSizes: [])

        guard case .some(.insufficientTemplateDetail(let reason)) = PhotoPipelineTemplateValidator.validate(result) else {
            XCTFail("A photo with no usable contours should not become an empty user template.")
            return
        }

        XCTAssertTrue(reason.contains("0 usable fill regions"))
    }

    func test_vectorizationWithTooFewRegions_isRejectedAsUnusableColoringPage() {
        let result = makeResult(regionSizes: [20, 20])

        guard case .some(.insufficientTemplateDetail(let reason)) = PhotoPipelineTemplateValidator.validate(result) else {
            XCTFail("One or two regions is parseable SVG, but not a useful coloring page.")
            return
        }

        XCTAssertTrue(reason.contains("2 usable fill regions"))
    }

    func test_vectorizationWithTinySpeckRegions_isRejectedForLowCoverage() {
        let result = makeResult(regionSizes: [4, 4, 4], canvasSize: CGSize(width: 1_000, height: 1_000))

        guard case .some(.insufficientTemplateDetail(let reason)) = PhotoPipelineTemplateValidator.validate(result) else {
            XCTFail("Tiny specks should be treated as failed extraction, not saved as a template.")
            return
        }

        XCTAssertTrue(reason.contains("regions covering"))
    }

    func test_vectorizationWithInvalidCanvas_isRejected() {
        let result = makeResult(regionSizes: [20, 20, 20], canvasSize: .zero)

        guard case .some(.insufficientTemplateDetail(let reason)) = PhotoPipelineTemplateValidator.validate(result) else {
            XCTFail("Invalid canvas dimensions should fail before creating a malformed SVG viewBox.")
            return
        }

        XCTAssertTrue(reason.contains("invalid canvas size"))
    }

    func test_vectorizationWithMultipleMeaningfulRegions_isAccepted() {
        let result = makeResult(regionSizes: [20, 18, 16], canvasSize: CGSize(width: 100, height: 100))

        XCTAssertNil(
            PhotoPipelineTemplateValidator.validate(result),
            "Three meaningful regions with enough coverage should be allowed through to SVG assembly."
        )
    }

    func test_parsedGeometryWithDroppedRegions_isRejectedAfterParityCheck() {
        let geometry = TemplateGeometry(
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            regions: [makeRegion(size: 20)],
            decorativePaths: []
        )

        guard case .some(.insufficientTemplateDetail(let reason)) = PhotoPipelineTemplateValidator.validate(geometry) else {
            XCTFail("Parser parity must verify that enough fillable regions survived SVG parsing.")
            return
        }

        XCTAssertTrue(reason.contains("1 usable fill regions"))
    }

    private func makeResult(
        regionSizes: [CGFloat],
        canvasSize: CGSize = CGSize(width: 100, height: 100)
    ) -> ContourVectorizer.VectorizationResult {
        ContourVectorizer.VectorizationResult(
            regionPaths: regionSizes.enumerated().map { index, size in
                makeSquarePath(x: CGFloat(index) * (size + 2), y: 0, size: size)
            },
            decorativePaths: [],
            imageSize: canvasSize
        )
    }

    private func makeRegion(size: CGFloat) -> RegionGeometry {
        let path = makeSquarePath(x: 0, y: 0, size: size)
        return RegionGeometry(
            id: "region-1",
            path: path,
            bounds: path.boundingBoxOfPath,
            fillRule: .winding,
            zIndex: 0
        )
    }

    private func makeSquarePath(x: CGFloat, y: CGFloat, size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + size, y: y))
        path.addLine(to: CGPoint(x: x + size, y: y + size))
        path.addLine(to: CGPoint(x: x, y: y + size))
        path.closeSubpath()
        return path
    }
}
