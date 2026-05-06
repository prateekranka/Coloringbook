import XCTest
@testable import ColorFlow

final class CanvasViewportTests: XCTestCase {
    func test_updateScale_clampsToSupportedZoomRange() {
        var viewport = CanvasViewport()

        viewport.updateScale(
            from: 1,
            magnification: 12,
            canvasSize: CGSize(width: 400, height: 400),
            viewportSize: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(viewport.scale, CanvasViewport.maximumScale)

        viewport.updateScale(
            from: 2,
            magnification: 0.1,
            canvasSize: CGSize(width: 400, height: 400),
            viewportSize: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(viewport.scale, CanvasViewport.minimumScale)
    }

    func test_updateOffset_clampsToVisibleCanvasOverflow() {
        var viewport = CanvasViewport()
        viewport.updateScale(
            from: 1,
            magnification: 2,
            canvasSize: CGSize(width: 400, height: 300),
            viewportSize: CGSize(width: 300, height: 200)
        )

        viewport.updateOffset(
            from: .zero,
            translation: CGSize(width: 10_000, height: -10_000),
            canvasSize: CGSize(width: 400, height: 300),
            viewportSize: CGSize(width: 300, height: 200)
        )

        XCTAssertEqual(viewport.offset.width, 250)
        XCTAssertEqual(viewport.offset.height, -200)
    }

    func test_reset_restoresIdentityViewport() {
        var viewport = CanvasViewport()
        viewport.updateScale(
            from: 1,
            magnification: 2,
            canvasSize: CGSize(width: 400, height: 400),
            viewportSize: CGSize(width: 300, height: 300)
        )
        viewport.updateOffset(
            from: .zero,
            translation: CGSize(width: 40, height: 40),
            canvasSize: CGSize(width: 400, height: 400),
            viewportSize: CGSize(width: 300, height: 300)
        )

        viewport.reset()

        XCTAssertTrue(viewport.isIdentity)
        XCTAssertEqual(viewport.scale, 1)
        XCTAssertEqual(viewport.offset, .zero)
    }
}
