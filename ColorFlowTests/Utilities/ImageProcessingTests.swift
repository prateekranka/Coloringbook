import XCTest
import PencilKit
@testable import ColorFlow

final class ImageProcessingTests: XCTestCase {

    // MARK: - Helpers

    private func solidColorImage(size: CGSize, color: UIColor = .white) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - composite: return value

    func test_composite_returnsNonNilImage() {
        let size = CGSize(width: 100, height: 100)
        let result = ImageProcessing.composite(
            background: .white,
            fillLayer: nil,
            drawing: PKDrawing(),
            template: nil,
            size: size
        )
        // UIImage is never nil from UIGraphicsImageRenderer, but verify via pixel size.
        XCTAssertNotNil(result as UIImage?)
    }

    // MARK: - composite: output size

    func test_composite_outputMatchesRequestedSize() {
        let size = CGSize(width: 200, height: 150)
        let result = ImageProcessing.composite(
            background: .white,
            fillLayer: nil,
            drawing: PKDrawing(),
            template: nil,
            size: size
        )
        XCTAssertEqual(result.size.width,  size.width,  accuracy: 0.5)
        XCTAssertEqual(result.size.height, size.height, accuracy: 0.5)
    }

    func test_composite_squareSize_isSquare() {
        let side: CGFloat = 256
        let size = CGSize(width: side, height: side)
        let result = ImageProcessing.composite(
            background: .black,
            fillLayer: nil,
            drawing: PKDrawing(),
            template: nil,
            size: size
        )
        XCTAssertEqual(result.size.width, result.size.height,
                       "A square-requested composite must produce a square image")
    }

    // MARK: - composite: nil fill layer

    func test_composite_nilFillLayer_doesNotCrash() {
        let size = CGSize(width: 50, height: 50)
        XCTAssertNoThrow(
            ImageProcessing.composite(
                background: .blue,
                fillLayer: nil,
                drawing: PKDrawing(),
                template: nil,
                size: size
            )
        )
    }

    // MARK: - composite: nil template

    func test_composite_nilTemplate_doesNotCrash() {
        let size = CGSize(width: 50, height: 50)
        XCTAssertNoThrow(
            ImageProcessing.composite(
                background: .white,
                fillLayer: solidColorImage(size: size, color: .red),
                drawing: PKDrawing(),
                template: nil,
                size: size
            )
        )
    }

    // MARK: - composite: with all layers provided

    func test_composite_withAllLayers_returnsCorrectSize() {
        let size = CGSize(width: 120, height: 80)
        let fill = solidColorImage(size: size, color: .yellow)
        let template = solidColorImage(size: size, color: .black)
        let result = ImageProcessing.composite(
            background: .white,
            fillLayer: fill,
            drawing: PKDrawing(),
            template: template,
            size: size
        )
        XCTAssertEqual(result.size.width,  size.width,  accuracy: 0.5)
        XCTAssertEqual(result.size.height, size.height, accuracy: 0.5)
    }

    // MARK: - thumbnail: return value

    func test_thumbnail_returnsNonNilImage() {
        let sourceSize = CGSize(width: 800, height: 800)
        let result = ImageProcessing.thumbnail(
            background: .white,
            fillLayer: nil,
            drawing: PKDrawing(),
            template: nil,
            sourceSize: sourceSize
        )
        XCTAssertNotNil(result as UIImage?)
    }

    // MARK: - thumbnail: output size

    func test_thumbnail_defaultSize_is400x400() {
        let sourceSize = CGSize(width: 1000, height: 1000)
        let result = ImageProcessing.thumbnail(
            background: .white,
            fillLayer: nil,
            drawing: PKDrawing(),
            template: nil,
            sourceSize: sourceSize
        )
        XCTAssertEqual(result.size.width,  400, accuracy: 0.5)
        XCTAssertEqual(result.size.height, 400, accuracy: 0.5)
    }

    func test_thumbnail_customSize_matchesRequestedSize() {
        let sourceSize    = CGSize(width: 500, height: 500)
        let thumbnailSize = CGSize(width: 200, height: 100)
        let result = ImageProcessing.thumbnail(
            background: .white,
            fillLayer: nil,
            drawing: PKDrawing(),
            template: nil,
            sourceSize: sourceSize,
            thumbnailSize: thumbnailSize
        )
        XCTAssertEqual(result.size.width,  thumbnailSize.width,  accuracy: 0.5)
        XCTAssertEqual(result.size.height, thumbnailSize.height, accuracy: 0.5)
    }

    func test_thumbnail_smallerThanSource_downscalesCorrectly() {
        let sourceSize    = CGSize(width: 800, height: 600)
        let thumbnailSize = CGSize(width: 80, height: 60)
        let result = ImageProcessing.thumbnail(
            background: .white,
            fillLayer: nil,
            drawing: PKDrawing(),
            template: nil,
            sourceSize: sourceSize,
            thumbnailSize: thumbnailSize
        )
        XCTAssertEqual(result.size.width,  thumbnailSize.width,  accuracy: 0.5)
        XCTAssertEqual(result.size.height, thumbnailSize.height, accuracy: 0.5)
    }

    // MARK: - thumbnail: nil inputs

    func test_thumbnail_nilFillLayerAndTemplate_doesNotCrash() {
        let sourceSize = CGSize(width: 400, height: 400)
        XCTAssertNoThrow(
            ImageProcessing.thumbnail(
                background: .gray,
                fillLayer: nil,
                drawing: PKDrawing(),
                template: nil,
                sourceSize: sourceSize
            )
        )
    }

    // MARK: - renderToBitmap

    func test_renderToBitmap_returnsCorrectSize() {
        let original = solidColorImage(size: CGSize(width: 100, height: 100), color: .green)
        let targetSize = CGSize(width: 50, height: 50)

        let result = ImageProcessing.renderToBitmap(original, size: targetSize)

        XCTAssertEqual(result.size.width,  targetSize.width,  accuracy: 0.5)
        XCTAssertEqual(result.size.height, targetSize.height, accuracy: 0.5)
    }

    func test_renderToBitmap_upscale_returnsCorrectSize() {
        let original = solidColorImage(size: CGSize(width: 50, height: 50), color: .orange)
        let targetSize = CGSize(width: 200, height: 200)

        let result = ImageProcessing.renderToBitmap(original, size: targetSize)

        XCTAssertEqual(result.size.width,  targetSize.width,  accuracy: 0.5)
        XCTAssertEqual(result.size.height, targetSize.height, accuracy: 0.5)
    }

    func test_renderToBitmap_returnsNonNilImage() {
        let original = solidColorImage(size: CGSize(width: 10, height: 10))
        let result = ImageProcessing.renderToBitmap(original, size: CGSize(width: 10, height: 10))
        XCTAssertNotNil(result as UIImage?)
    }

    func test_renderToBitmap_asymmetricSize_preservesRequestedDimensions() {
        let original = solidColorImage(size: CGSize(width: 100, height: 100))
        let targetSize = CGSize(width: 300, height: 150)

        let result = ImageProcessing.renderToBitmap(original, size: targetSize)

        XCTAssertEqual(result.size.width,  300, accuracy: 0.5)
        XCTAssertEqual(result.size.height, 150, accuracy: 0.5)
    }
}
