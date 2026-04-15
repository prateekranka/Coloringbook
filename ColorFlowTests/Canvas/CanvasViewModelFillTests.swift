import XCTest
import CoreGraphics
@testable import ColorFlow

/// Characterization tests that pin the current fill behavior so future
/// refactors (U2 through U8 in the canvas UX plan) cannot regress it.
///
/// These tests should be GREEN today — they document the existing
/// tap-to-fill pipeline that U1 characterizes before U2-U5 touch it.
@MainActor
final class CanvasViewModelFillTests: XCTestCase {

    // MARK: - Template loading (pre-conditions for every other test)

    func test_loadTemplate_populatesGeometryAndCanvasSize() async throws {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        XCTAssertNotNil(viewModel.templateGeometry,
                        "loadTemplate must populate templateGeometry for the default fixture")
        XCTAssertNotEqual(viewModel.canvasSize, .zero,
                          "canvasSize must be derived from the SVG viewBox after load")

        let regionCount = viewModel.templateGeometry?.regions.count ?? 0
        XCTAssertGreaterThan(regionCount, 3,
                             "Default fixture should have more than three regions; found \(regionCount)")
    }

    func test_loadTemplate_rendersFillLayerAndLineArt() async throws {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        XCTAssertNotNil(viewModel.templateImage,
                        "loadTemplate must produce a rendered line-art image")
        XCTAssertNotNil(viewModel.fillLayerImage,
                        "loadTemplate must produce an initial (possibly empty) fill layer")
    }

    // MARK: - Hit-testing

    func test_regionCentroid_hitTestsToThatRegion() async throws {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        let geometry = try XCTUnwrap(viewModel.templateGeometry)

        // Exercise every region: its bounding-box centroid should hit-test
        // to SOME region (either itself or an equally valid overlapping
        // region). The plan's contract is that `region(at:)` is deterministic
        // and returns non-nil for centroids that fall inside the geometry.
        for region in geometry.regions {
            let point = CanvasTestFixture.interiorPoint(of: region)
            let hit = geometry.region(at: point)
            XCTAssertNotNil(
                hit,
                "Centroid \(point) of region '\(region.id)' hit-tested to nil; " +
                "fixture assumption that centroids fall inside the geometry is broken"
            )
        }
    }

    // MARK: - Fill behavior

    func test_performRegionFill_onRegionCentroid_changesFillLayer() async throws {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        let geometry = try XCTUnwrap(viewModel.templateGeometry)
        let firstRegion = try XCTUnwrap(geometry.regions.first)

        // Pass viewSize = viewBox.size so documentToViewTransform reduces to
        // identity — the doc-space centroid and the "view" point coincide.
        let viewSize = geometry.viewBox.size
        let docCentroid = CanvasTestFixture.interiorPoint(of: firstRegion)

        let imageBefore = viewModel.fillLayerImage
        await viewModel.performRegionFill(at: docCentroid, in: viewSize)
        let imageAfter = viewModel.fillLayerImage

        XCTAssertNotNil(imageAfter, "fillLayerImage must remain non-nil after a successful fill")
        XCTAssertFalse(
            imageBefore === imageAfter,
            "A successful fill must replace fillLayerImage with a freshly rendered UIImage instance; " +
            "instance identity was preserved, which means no re-render happened"
        )
    }

    func test_performRegionFill_outsideAnyRegion_isNoOp() async throws {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        let geometry = try XCTUnwrap(viewModel.templateGeometry)
        let viewSize = geometry.viewBox.size

        let imageBefore = viewModel.fillLayerImage
        await viewModel.performRegionFill(
            at: CanvasTestFixture.pointOutsideAllRegions,
            in: viewSize
        )
        let imageAfter = viewModel.fillLayerImage

        XCTAssertTrue(
            imageBefore === imageAfter,
            "A tap outside any region must not re-render the fill layer; " +
            "fillLayerImage identity changed, which means a spurious fill happened"
        )
    }

    func test_performRegionFill_setsIsFillingBackToFalse() async throws {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        let geometry = try XCTUnwrap(viewModel.templateGeometry)
        let firstRegion = try XCTUnwrap(geometry.regions.first)
        let viewSize = geometry.viewBox.size

        await viewModel.performRegionFill(
            at: CanvasTestFixture.interiorPoint(of: firstRegion),
            in: viewSize
        )

        XCTAssertFalse(
            viewModel.isFilling,
            "isFilling must be false after performRegionFill returns; " +
            "a stuck-true value would leave the UI in a loading state"
        )
    }

    // MARK: - Undo after fill

    func test_undo_afterSingleFill_revertsFillLayer() async throws {
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        let geometry = try XCTUnwrap(viewModel.templateGeometry)
        let firstRegion = try XCTUnwrap(geometry.regions.first)
        let viewSize = geometry.viewBox.size

        await viewModel.performRegionFill(
            at: CanvasTestFixture.interiorPoint(of: firstRegion),
            in: viewSize
        )
        let afterFill = viewModel.fillLayerImage

        viewModel.undo()

        // undo() schedules a detached re-render; wait for it to reach main.
        try await waitForFillLayerChange(on: viewModel, from: afterFill, timeoutSeconds: 2.0)

        XCTAssertFalse(
            afterFill === viewModel.fillLayerImage,
            "undo() must eventually replace fillLayerImage after a fill is reversed"
        )
    }

    // MARK: - Helpers

    /// Polls `fillLayerImage` on the viewmodel until it differs from
    /// `previous` (by instance identity) or the timeout expires. Needed
    /// because `undo()` dispatches a detached Task to re-render.
    private func waitForFillLayerChange(
        on viewModel: CanvasViewModel,
        from previous: UIImage?,
        timeoutSeconds: Double
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if viewModel.fillLayerImage !== previous {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("fillLayerImage did not change within \(timeoutSeconds)s")
    }
}
