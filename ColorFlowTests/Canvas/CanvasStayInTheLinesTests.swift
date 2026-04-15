import XCTest
import UIKit
import PencilKit
@testable import ColorFlow

/// RED-BAR stubs for U8 (stay-in-the-lines stroke clipping).
///
/// These tests fail today on purpose — they pin the contract U8 must deliver:
/// a persisted, togglable mode that clips drawing-brush strokes to the region
/// that contained the stroke's first touch point ("first-touched region wins").
/// Eraser ignores the mode.
///
/// U8 must introduce the following APIs before these tests can assert against them:
///   - `CanvasViewModel.stayInTheLines: Bool` (persisted via @AppStorage).
///   - `CanvasViewModel.clipStroke(_:toRegion:) -> [PKStroke]` — pure function.
///   - Delegate-hook interception in `PencilCanvasRepresentable.canvasViewDrawingDidChange`
///     that clips and replaces the drawing before propagating to the viewmodel.
///
/// See docs/plans/2026-04-15-001-fix-canvas-ux-fill-bounce-premium-plan.md,
/// Unit U8. Requirements R11, R12, R13, R14.
@MainActor
final class CanvasStayInTheLinesTests: XCTestCase {

    // MARK: - Happy paths

    func test_strokeFullyInsideRegion_isUnchanged() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: with stayInTheLines = ON, a stroke whose every sample " +
            "lies inside region R must survive clipStroke(_:toRegion:) point-for-point " +
            "(same point count, same locations). Guards against over-aggressive clipping."
        )
    }

    func test_strokeCrossingBoundaryOnce_isClippedAtBoundary() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: with stayInTheLines = ON, a stroke that enters region R " +
            "and then exits must be clipped to the inside portion only. The clipped stroke " +
            "must have fewer points than the input, and every surviving point must satisfy " +
            "region.path.contains(point.location)."
        )
    }

    func test_strokeCrossingBoundaryTwice_emitsTwoStrokes() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: a stroke that goes IN → OUT → IN must produce two " +
            "PKStroke outputs from clipStroke(_:toRegion:), one per inside sub-sequence, " +
            "preserving the original ink on each. Pins the 'multiple sub-strokes on re-entry' " +
            "clause of the clipping design."
        )
    }

    // MARK: - Policy edges

    func test_strokeStartingOutsideAnyRegion_commitsUnclipped() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: v1 policy is 'stroke starts outside any region' → commit " +
            "unclipped. Document the choice in the settings sheet's explainer text. If the " +
            "user decides on the reject-entirely alternative during implementation, invert " +
            "this assertion and update the plan's Open Questions section."
        )
    }

    func test_togglingOffMidStroke_doesNotAffectInProgressStroke() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: the first-touched region is captured at stroke START; " +
            "flipping stayInTheLines ON→OFF during a stroke must leave the in-progress " +
            "stroke clipped (the stroke is bound to the state at its start). Next stroke " +
            "honors the new state."
        )
    }

    func test_togglingOnMidStroke_doesNotClipInProgressStroke() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: conversely, flipping OFF→ON during a stroke must leave " +
            "the in-progress stroke unclipped. Only strokes that START with the mode ON " +
            "are clipped."
        )
    }

    // MARK: - Eraser contract

    func test_eraserIgnoresStayInTheLines() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: with stayInTheLines = ON, an eraser stroke must be " +
            "delivered to the viewmodel unchanged — eraser can clean up anywhere, " +
            "including areas outside the 'first-touched region' of any prior stroke. " +
            "Pins R11's explicit eraser-ignores-mode clause."
        )
    }

    // MARK: - Persistence

    func test_clippedStroke_persistedDrawing_containsOnlyClippedPortion() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: clipping happens at COMMIT time, not render time. " +
            "After a crossing stroke is saved via StorageService.save, loading the same " +
            "PKDrawing from disk must return only the clipped portion — not the original. " +
            "Pins R13: re-open / export / undo cannot reveal the dropped portion."
        )
    }

    // MARK: - Settings persistence

    func test_stayInTheLinesFlag_persistsAcrossViewModelInstances() async throws {
        XCTFail(
            "U8 NOT IMPLEMENTED: setting viewModel.stayInTheLines = true on one instance " +
            "must be observable on a freshly-constructed CanvasViewModel via @AppStorage. " +
            "Pins R11's 'persisted' clause."
        )
    }
}
