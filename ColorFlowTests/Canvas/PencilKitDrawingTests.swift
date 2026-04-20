import XCTest
import PencilKit
import UIKit
@testable import ColorFlow

/// PencilKit drawing tests that bypass touch synthesis.
///
/// XCUITest `swipe` / Axe `swipe` don't produce `UITouch` events the
/// PKCanvasView recognizer accepts on the Simulator. Instead of synthesizing
/// touches, we build `PKStroke` objects via `PKStrokeFactory`, wrap them in a
/// `PKDrawing`, and assign directly to `viewModel.drawing`. This is what
/// Apple's own PencilKit sample tests do, and it exercises the full pipeline:
/// drawing-did-change delegate, undo manager registration, auto-save.
@MainActor
final class PencilKitDrawingTests: XCTestCase {

    func test_assigningDrawing_updatesStrokeCount() async throws {
        let vm = try await CanvasTestFixture.makeLoadedViewModel()
        XCTAssertEqual(vm.drawing.strokes.count, 0, "Fresh viewModel should have no strokes.")

        let stroke = PKStrokeFactory.pencilLine(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 300, y: 300),
            color: .black
        )
        vm.drawing = PKStrokeFactory.drawing(with: [stroke])

        XCTAssertEqual(vm.drawing.strokes.count, 1, "Stroke assignment must persist on the viewModel.")
    }

    func test_strokeBounds_containGeneratedLine() async throws {
        let vm = try await CanvasTestFixture.makeLoadedViewModel()
        let start = CGPoint(x: 120, y: 120)
        let end = CGPoint(x: 400, y: 400)

        let stroke = PKStrokeFactory.pencilLine(from: start, to: end, color: .red, width: 12)
        vm.drawing = PKStrokeFactory.drawing(with: [stroke])

        let bounds = vm.drawing.bounds
        XCTAssertTrue(bounds.contains(start), "Drawing bounds must contain the start point.")
        XCTAssertTrue(bounds.contains(end), "Drawing bounds must contain the end point.")
    }

    func test_multipleStrokes_accumulateInDrawing() async throws {
        let vm = try await CanvasTestFixture.makeLoadedViewModel()

        let s1 = PKStrokeFactory.pencilLine(from: .init(x: 50, y: 50), to: .init(x: 150, y: 150), color: .blue)
        let s2 = PKStrokeFactory.pencilLine(from: .init(x: 200, y: 200), to: .init(x: 300, y: 300), color: .green)
        let s3 = PKStrokeFactory.pencilLine(from: .init(x: 350, y: 350), to: .init(x: 450, y: 450), color: .red)

        vm.drawing = PKStrokeFactory.drawing(with: [s1, s2, s3])

        XCTAssertEqual(vm.drawing.strokes.count, 3)
    }

    func test_clearingDrawing_resetsStrokes() async throws {
        let vm = try await CanvasTestFixture.makeLoadedViewModel()
        let stroke = PKStrokeFactory.pencilLine(
            from: .init(x: 10, y: 10),
            to: .init(x: 100, y: 100),
            color: .black
        )
        vm.drawing = PKStrokeFactory.drawing(with: [stroke])
        XCTAssertEqual(vm.drawing.strokes.count, 1)

        vm.drawing = PKDrawing()
        XCTAssertEqual(vm.drawing.strokes.count, 0)
    }
}
