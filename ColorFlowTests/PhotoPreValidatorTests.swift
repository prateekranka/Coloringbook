import XCTest
@testable import ColorFlow

final class PhotoPreValidatorTests: XCTestCase {

    // MARK: - Size checks

    func test_validImage_passes() {
        let image = makeImage(width: 1024, height: 768)
        let result = PhotoPreValidator.validate(image)
        if case .tooSmall = result {
            XCTFail("Expected .valid or soft warning for a 768px short-edge image")
        }
    }

    func test_squareMinimumSize_passes() {
        let image = makeImage(width: 640, height: 640)
        // Short edge == minimumShortEdge, should not be rejected for size.
        if case .tooSmall(let actual, _) = PhotoPreValidator.validate(image) {
            XCTFail("640px image should pass size check, got tooSmall(\(actual))")
        }
    }

    func test_imageBelowMinimumSize_failsWithTooSmall() {
        let image = makeImage(width: 400, height: 600)   // short edge = 400 < 640
        guard case .tooSmall(let actual, let minimum) = PhotoPreValidator.validate(image) else {
            XCTFail("Expected .tooSmall for a 400px short-edge image")
            return
        }
        XCTAssertEqual(actual, 400)
        XCTAssertEqual(minimum, PhotoPreValidator.minimumShortEdge)
    }

    func test_verySmallImage_failsWithTooSmall() {
        let image = makeImage(width: 100, height: 100)
        guard case .tooSmall = PhotoPreValidator.validate(image) else {
            XCTFail("Expected .tooSmall for a 100×100 image")
            return
        }
    }

    func test_landscapeImage_usesShortEdge() {
        // 300×2000 — short edge is 300, below minimum
        let image = makeImage(width: 2000, height: 300)
        guard case .tooSmall(let actual, _) = PhotoPreValidator.validate(image) else {
            XCTFail("Expected .tooSmall when short edge is 300px")
            return
        }
        XCTAssertEqual(actual, 300)
    }

    // MARK: - Contrast checks

    func test_flatWhiteImage_isLowContrast() {
        let image = makeImage(width: 256, height: 256, color: .white)
        XCTAssertTrue(
            PhotoPreValidator.isLowContrast(image),
            "Solid white image should be flagged as low contrast"
        )
    }

    func test_flatBlackImage_isLowContrast() {
        let image = makeImage(width: 256, height: 256, color: .black)
        XCTAssertTrue(
            PhotoPreValidator.isLowContrast(image),
            "Solid black image should be flagged as low contrast"
        )
    }

    func test_checkerboardImage_isNotLowContrast() {
        let image = makeCheckerboard(size: 256, tileSize: 32)
        XCTAssertFalse(
            PhotoPreValidator.isLowContrast(image),
            "Checkerboard should have sufficient contrast"
        )
    }

    // MARK: - Integration: validate() routing

    func test_smallImage_returnsToSmall_beforeContrastCheck() {
        // Image is too small AND low contrast — tooSmall should come first.
        let image = makeImage(width: 100, height: 100, color: .white)
        guard case .tooSmall = PhotoPreValidator.validate(image) else {
            XCTFail("Size rejection should precede contrast check")
            return
        }
    }

    func test_validContrastImage_returnsValid() {
        let image = makeCheckerboard(size: 640, tileSize: 80)
        // Should not return .tooSmall (640 == minimum) or .lowContrast
        switch PhotoPreValidator.validate(image) {
        case .tooSmall:
            XCTFail("Checkerboard 640px should not be too small")
        case .lowContrast:
            XCTFail("Checkerboard should not be low contrast")
        default:
            break  // .valid or .blurry is acceptable
        }
    }

    // MARK: - Helpers

    private func makeImage(width: Int, height: Int, color: UIColor = .gray) -> UIImage {
        var format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func makeCheckerboard(size: Int, tileSize: Int) -> UIImage {
        var format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { context in
            let cols = size / tileSize
            for row in 0..<cols {
                for col in 0..<cols {
                    let isWhite = (row + col) % 2 == 0
                    (isWhite ? UIColor.white : UIColor.black).setFill()
                    let rect = CGRect(
                        x: col * tileSize, y: row * tileSize,
                        width: tileSize, height: tileSize
                    )
                    context.fill(rect)
                }
            }
        }
    }
}
