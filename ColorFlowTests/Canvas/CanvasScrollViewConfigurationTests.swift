import XCTest
import SwiftUI
import UIKit
@testable import ColorFlow

/// RED-BAR: these tests are expected to fail today and will pass once U3
/// (finger-pan gated on zoom state, pan-bounce disabled) and U4 (bounds-
/// flutter guard) land.
///
/// They exercise `PencilCanvasRepresentable` through a `UIHostingController`
/// so the real `makeUIView`/`Coordinator` path runs, then assert invariants
/// on the resulting UIScrollView configuration.
///
/// See docs/plans/2026-04-15-001-fix-canvas-ux-fill-bounce-premium-plan.md,
/// Units U3 and U4. Requirements R2, R3, R4.
@MainActor
final class CanvasScrollViewConfigurationTests: XCTestCase {

    /// Tolerance for "content fits exactly in the viewport" — picked to match
    /// the plan's prescribed epsilon window. U3 will also stamp an epsilon
    /// into the coordinator; if U3 picks a different value, update this one
    /// to match.
    private let fitEpsilon: CGFloat = 0.001

    // MARK: - Invariants at construction time (RED until U3)

    func test_afterMakeUIView_bouncesIsOff_bouncesZoomIsOn() async throws {
        let (_, scrollView) = try await makeHostedRepresentable()

        XCTAssertFalse(
            scrollView.bounces,
            "Pan-bounce must be OFF (scrollView.bounces == false). " +
            "With bounces ON, dragging on a fitted canvas produces the 'bouncing' " +
            "the U3 plan eliminates."
        )
        XCTAssertTrue(
            scrollView.bouncesZoom,
            "Pinch-zoom bounce must stay ON (scrollView.bouncesZoom == true) " +
            "so the pinch interaction keeps its natural feel."
        )
    }

    // MARK: - Finger-pan gate (RED until U3)

    func test_whenFitted_scrollIsDisabled() async throws {
        let (coordinator, scrollView) = try await makeHostedRepresentable()

        // Force a fitted state: drive updateContentSize and settle zoomScale
        // to the computed fit. Pass a docSize matching the known fixture.
        let docSize = CGSize(width: 800, height: 800) // sunflower_mandala viewBox
        coordinator.updateContentSize(docSize, in: scrollView)

        let fitScale = min(
            scrollView.bounds.width / docSize.width,
            scrollView.bounds.height / docSize.height
        )
        XCTAssertEqual(
            scrollView.zoomScale, fitScale, accuracy: fitEpsilon,
            "Test precondition: after updateContentSize the scroll view must be at fitScale"
        )

        XCTAssertFalse(
            scrollView.isScrollEnabled,
            "When content fits the viewport (zoomScale ≈ fitScale), finger-pan " +
            "must be disabled so stray touches do not drift the canvas. " +
            "U3 implements this gate in updateContentSize + scrollViewDidEndZooming."
        )
    }

    func test_whenZoomedIn_scrollIsEnabled() async throws {
        let (coordinator, scrollView) = try await makeHostedRepresentable()

        let docSize = CGSize(width: 800, height: 800)
        coordinator.updateContentSize(docSize, in: scrollView)

        // Simulate a user pinch-in past fitScale, then the delegate callback.
        let fitScale = min(
            scrollView.bounds.width / docSize.width,
            scrollView.bounds.height / docSize.height
        )
        scrollView.setZoomScale(fitScale * 2, animated: false)
        // Route through the UIScrollViewDelegate protocol: today the Coordinator
        // doesn't implement scrollViewDidEndZooming, so this optional-method call
        // is a no-op and isScrollEnabled stays false (RED). Once U3 implements
        // the hook, the gate re-enables scrolling.
        let zoomView = coordinator.viewForZooming(in: scrollView)
        (coordinator as UIScrollViewDelegate).scrollViewDidEndZooming?(
            scrollView,
            with: zoomView,
            atScale: fitScale * 2
        )

        XCTAssertTrue(
            scrollView.isScrollEnabled,
            "When the user has zoomed in past fitScale, finger-pan must re-enable " +
            "so the user can actually explore the zoomed canvas. " +
            "U3 implements this gate in scrollViewDidEndZooming."
        )
    }

    // MARK: - Bounds-flutter guard (RED until U4)

    func test_repeatedUpdateContentSize_withinDebounceWindow_appliesFitZoomOnce() async throws {
        let (coordinator, scrollView) = try await makeHostedRepresentable()

        let docSize = CGSize(width: 800, height: 800)
        coordinator.updateContentSize(docSize, in: scrollView)

        // Simulate a user pinch-in; any subsequent spurious updateContentSize
        // triggered by toolbar-animation bounds flutter should NOT snap zoom
        // back to fitScale.
        let fitScale = min(
            scrollView.bounds.width / docSize.width,
            scrollView.bounds.height / docSize.height
        )
        let userZoom = fitScale * 2
        scrollView.setZoomScale(userZoom, animated: false)

        // Flutter call immediately after: same size, should be a no-op on zoom.
        coordinator.updateContentSize(docSize, in: scrollView)

        XCTAssertEqual(
            scrollView.zoomScale, userZoom, accuracy: fitEpsilon,
            "Bounds-flutter updateContentSize within the debounce window must NOT " +
            "snap zoomScale back to fitScale. The user's zoom is sacred during toolbar " +
            "animations. U4 implements this guard with a timestamp + size-equality check."
        )
    }

    // MARK: - Hosting helpers

    /// Stand up a `PencilCanvasRepresentable` inside a real UIHostingController,
    /// lay it out in a test window, and return the coordinator + outer UIScrollView.
    private func makeHostedRepresentable() async throws -> (PencilCanvasRepresentable.Coordinator, UIScrollView) {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        let representable = PencilCanvasRepresentable(viewModel: viewModel)

        let host = UIHostingController(rootView: representable)
        let frame = CGRect(x: 0, y: 0, width: 1024, height: 1024) // iPad-ish bounds

        let window = UIWindow(frame: frame)
        window.rootViewController = host
        window.makeKeyAndVisible()

        // Force layout so makeUIView + coordinator wiring runs.
        host.view.frame = frame
        host.view.layoutIfNeeded()

        // Let SwiftUI's runloop process the attachment.
        try await Task.sleep(for: .milliseconds(50))
        host.view.layoutIfNeeded()

        // Descend to find the UIScrollView our representable added.
        guard let scrollView = findFirstScrollView(in: host.view) else {
            throw FixtureError.scrollViewNotFound
        }

        // Drive one layout pass on the scroll view explicitly so bounds are
        // populated (updateContentSize guards against zero-bounds).
        scrollView.layoutIfNeeded()

        // Coordinator is on the PencilCanvasRepresentable's delegate — it IS
        // the scroll view's delegate by construction.
        guard let coordinator = scrollView.delegate as? PencilCanvasRepresentable.Coordinator else {
            throw FixtureError.coordinatorNotFound
        }

        return (coordinator, scrollView)
    }

    private func findFirstScrollView(in view: UIView) -> UIScrollView? {
        if let sv = view as? UIScrollView { return sv }
        for subview in view.subviews {
            if let sv = findFirstScrollView(in: subview) { return sv }
        }
        return nil
    }

    private enum FixtureError: Error, CustomStringConvertible {
        case scrollViewNotFound
        case coordinatorNotFound

        var description: String {
            switch self {
            case .scrollViewNotFound:
                return "Could not locate the outer UIScrollView inside the hosted representable."
            case .coordinatorNotFound:
                return "UIScrollView delegate was not a PencilCanvasRepresentable.Coordinator."
            }
        }
    }
}
