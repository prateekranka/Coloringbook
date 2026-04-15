import XCTest
@testable import ColorFlow

/// RED-BAR: these tests are expected to fail today and will pass once U2
/// (post-onboarding default tool resolution) lands. They pin the contract
/// from R1 in the canvas UX plan: new users opening a canvas after onboarding
/// should land on the `.floodFill` tool so the first tap produces a visible
/// result without a tool switch.
///
/// See docs/plans/2026-04-15-001-fix-canvas-ux-fill-bounce-premium-plan.md,
/// Unit U2.
@MainActor
final class CanvasDefaultToolTests: XCTestCase {

    // Keys under test — must stay in sync with the implementations U2
    // introduces in CanvasViewModel.init and ToolbarView's selection handler.
    private let lastUsedToolKey = "lastUsedTool"
    private let hasSeenOnboardingKey = "hasSeenOnboarding"

    override func setUp() {
        super.setUp()
        // Clean slate: neither key present.
        UserDefaults.standard.removeObject(forKey: lastUsedToolKey)
        UserDefaults.standard.removeObject(forKey: hasSeenOnboardingKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: lastUsedToolKey)
        UserDefaults.standard.removeObject(forKey: hasSeenOnboardingKey)
        super.tearDown()
    }

    // MARK: - Happy path (currently RED — default is `.pencil`)

    func test_freshInstall_postOnboarding_defaultsToFloodFill() async throws {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        // No lastUsedTool stored — this is the "just finished onboarding, opening
        // first canvas" state.

        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        XCTAssertEqual(
            viewModel.brushSettings.tool, .floodFill,
            "After onboarding with no prior tool choice, the canvas must default to " +
            ".floodFill so the onboarding 'Tap to Fill' promise matches the canvas. " +
            "Currently fails because BrushSettings.tool's struct default is .pencil " +
            "and CanvasViewModel.init does not override it — implement in U2."
        )
    }

    // MARK: - Returning user keeps their last pick

    func test_withStoredLastUsedTool_initialToolMatchesStoredValue() async throws {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        UserDefaults.standard.set(DrawingTool.marker.rawValue, forKey: lastUsedToolKey)

        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        XCTAssertEqual(
            viewModel.brushSettings.tool, .marker,
            "An explicit lastUsedTool must survive canvas re-entry; " +
            "returning users should not get bounced back to the Fill default."
        )
    }

    // MARK: - Edge cases

    func test_preOnboarding_defaultsToPencil() async throws {
        // hasSeenOnboarding not set — the pre-onboarding branch should keep
        // the legacy default so existing tests of pre-onboarding screens do
        // not regress.
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        XCTAssertEqual(
            viewModel.brushSettings.tool, .pencil,
            "Before onboarding completes the default must remain .pencil " +
            "(onboarding itself is the signal that a user is ready for the Fill promise)."
        )
    }

    func test_corruptedLastUsedTool_fallsThroughToPostOnboardingDefault() async throws {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        UserDefaults.standard.set("not-a-real-tool", forKey: lastUsedToolKey)

        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        XCTAssertEqual(
            viewModel.brushSettings.tool, .floodFill,
            "A corrupted lastUsedTool value must not crash and must fall through " +
            "to the post-onboarding default; a user who had garbage in their defaults " +
            "should still get a working canvas."
        )
    }
}
