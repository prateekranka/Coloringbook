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

    func test_updateScale_anchorsDocumentPointUnderPinchLocation() {
        var viewport = CanvasViewport()
        let canvasSize = CGSize(width: 400, height: 400)
        let viewportSize = CGSize(width: 300, height: 300)
        let anchor = CGPoint(x: 180, y: 160)

        viewport.updateScale(
            from: 1,
            magnification: 2,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )
        let documentPointBefore = viewport.canvasPoint(
            forViewportPoint: anchor,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )

        viewport.updateScale(
            from: viewport.scale,
            baseOffset: viewport.offset,
            magnification: 1.5,
            anchor: anchor,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )
        let documentPointAfter = viewport.canvasPoint(
            forViewportPoint: anchor,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )

        XCTAssertEqual(documentPointAfter.x, documentPointBefore.x, accuracy: 0.01)
        XCTAssertEqual(documentPointAfter.y, documentPointBefore.y, accuracy: 0.01)
    }

    func test_canvasPointMapping_accountsForViewportTransform() {
        var viewport = CanvasViewport()
        let canvasSize = CGSize(width: 400, height: 300)
        let viewportSize = CGSize(width: 300, height: 200)

        viewport.updateScale(
            from: 1,
            magnification: 2,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )
        viewport.updateOffset(
            from: .zero,
            translation: CGSize(width: 40, height: -20),
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )

        let canvasPoint = viewport.canvasPoint(
            forViewportPoint: CGPoint(x: 190, y: 80),
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )

        XCTAssertEqual(canvasPoint.x, 200, accuracy: 0.01)
        XCTAssertEqual(canvasPoint.y, 150, accuracy: 0.01)
        XCTAssertTrue(viewport.containsCanvasPoint(canvasPoint, canvasSize: canvasSize))
    }

    func test_canvasState_roundTripsViewportValues() {
        var state = CanvasState()
        state.zoomScale = 2.5
        state.offsetX = 42
        state.offsetY = -31

        let viewport = CanvasViewport(canvasState: state)
        let values = viewport.canvasStateValues

        XCTAssertEqual(viewport.scale, 2.5)
        XCTAssertEqual(viewport.offset, CGSize(width: 42, height: -31))
        XCTAssertEqual(values.zoomScale, 2.5)
        XCTAssertEqual(values.offsetX, 42)
        XCTAssertEqual(values.offsetY, -31)
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

    func test_viewportPoint_forCanvasPoint_roundTrip() {
        var viewport = CanvasViewport()
        let canvasSize = CGSize(width: 400, height: 300)
        let viewportSize = CGSize(width: 300, height: 200)

        viewport.updateScale(
            from: 1,
            magnification: 2,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )
        viewport.updateOffset(
            from: .zero,
            translation: CGSize(width: 40, height: -20),
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )

        let canvasPoint = CGPoint(x: 150, y: 100)
        let viewportPoint = viewport.viewportPoint(
            forCanvasPoint: canvasPoint,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )
        let roundTripped = viewport.canvasPoint(
            forViewportPoint: viewportPoint,
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )

        XCTAssertEqual(roundTripped.x, canvasPoint.x, accuracy: 0.5)
        XCTAssertEqual(roundTripped.y, canvasPoint.y, accuracy: 0.5)
    }
}
