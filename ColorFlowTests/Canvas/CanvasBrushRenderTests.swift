import XCTest
import UIKit
import PencilKit
@testable import ColorFlow

/// RED-BAR stubs for U7 (brush verification harness).
///
/// These tests fail today on purpose — they pin the U7 scope so it cannot
/// ship without each brush being verified. Once U7 lands, the `XCTFail` in
/// each test is replaced by the real render-and-sample assertion described
/// in the doc comment.
///
/// Harness requirements U7 must stand up:
///   - `ColorFlowTests/Canvas/Support/PixelSampler.swift` — given a UIImage
///     and a rect, return mean RGBA of the pixels in that rect.
///   - a render entry point that pipes `viewModel.drawing` + `fillLayerImage`
///     + line art through `TemplateRenderer.renderExport` at a known size.
///   - `PKStrokeFactory` (already exists in Support/) for deterministic
///     straight-line strokes.
///
/// See docs/plans/2026-04-15-001-fix-canvas-ux-fill-bounce-premium-plan.md,
/// Unit U7. Requirements R9, R10.
@MainActor
final class CanvasBrushRenderTests: XCTestCase {

    // MARK: - Pencil

    func test_pencilStroke_rendersRedPixels() async throws {
        XCTFail(
            "U7 NOT IMPLEMENTED: inject a PKStrokeFactory.pencilLine stroke, " +
            "render via TemplateRenderer.renderExport, then assert PixelSampler " +
            "mean R > 200, G < 80, B < 80 in a 16×16 window centered on the " +
            "midpoint of (100,100)→(300,100). Replace this XCTFail with the real " +
            "assertion once U7 lands."
        )
    }

    // MARK: - Marker

    func test_markerStroke_producesThickerBandThanPencil() async throws {
        XCTFail(
            "U7 NOT IMPLEMENTED: render a pencil stroke and a marker stroke at the " +
            "same nominal size; assert the marker's red-pixel count across a " +
            "cross-section is > 1.5× the pencil's. Pins marker → PKInkingTool(.marker)."
        )
    }

    // MARK: - Watercolor

    func test_watercolorStroke_shipsAtExpectedAlpha() async throws {
        XCTFail(
            "U7 NOT IMPLEMENTED: render a watercolor stroke (systemRed) over white; " +
            "assert sample-window mean R ∈ [100, 200]. Pins BrushSettings.pkTool's " +
            "monoline(alpha=0.4) mapping to the user-visible alpha of ~0.4."
        )
    }

    // MARK: - Eraser (PKDrawing-only contract)

    func test_eraserStroke_removesDrawingStroke_preservesFillLayer() async throws {
        XCTFail(
            "U7 NOT IMPLEMENTED: two-stage assertion. " +
            "(1) paint a pencil stroke, then an overlapping eraser stroke — " +
            "the sample window under the overlap must be white (R,G,B all > 245). " +
            "(2) fillLayerImage pixel bytes must be byte-equal before and after. " +
            "Pins R9's contract: eraser is PKDrawing-only, never touches the fill layer."
        )
    }

    // MARK: - Color / size plumbing

    func test_brushColorChange_flowsToRenderedPixels() async throws {
        XCTFail(
            "U7 NOT IMPLEMENTED: set brushSettings.color = .blue, render a stroke, " +
            "assert sample window is blue-dominant. Pins BrushSettings.color → " +
            "currentPKTool → rendered raster."
        )
    }

    func test_brushSizeChange_flowsToStrokeWidth() async throws {
        XCTFail(
            "U7 NOT IMPLEMENTED: render two pencil strokes at size 4 and size 20; " +
            "assert perpendicular red-pixel counts differ by > 3×. Pins BrushSettings.size " +
            "→ ink width."
        )
    }

    // MARK: - Release no-op for the debug launch arg

    func test_enableFingerDrawingFlag_isNoOpInRelease() async throws {
        XCTFail(
            "U7 NOT IMPLEMENTED: assert the -enableFingerDrawing launch arg is " +
            "compiled out in Release — drawingPolicy must stay .pencilOnly regardless " +
            "of the argument's presence. Verify via #if DEBUG branching."
        )
    }
}
