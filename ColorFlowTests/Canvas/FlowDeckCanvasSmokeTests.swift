import XCTest
@testable import ColorFlow

/// RED-BAR stub for the end-to-end FlowDeck smoke test.
///
/// Unlike the other Canvas test files, this test cannot be made to pass by
/// writing more Swift — it requires:
///   1. `Scripts/qa/canvas_smoke.sh` to exist (created in U6).
///   2. U2's post-onboarding default-tool resolution to be live (so the
///      fresh-install flow lands on `.floodFill`).
///   3. A reachable simulator + FlowDeck binary on PATH.
///
/// The script must: reset UserDefaults, advance past onboarding, tap the
/// canvas center, and scrape launch logs for `[ViewModel] performRegionFill
/// — hit region` within a 2-second window. This is the end-to-end gate for
/// "first finger tap on a new install produces a visible fill" (R1 + R7).
///
/// Today this stub fails loudly so U6 cannot be declared green without the
/// script in place. Once the script exists, replace this XCTFail with a
/// `Process` launch of `Scripts/qa/canvas_smoke.sh` and assert `exitCode == 0`.
///
/// See docs/plans/2026-04-15-001-fix-canvas-ux-fill-bounce-premium-plan.md,
/// Units U1 and U6. Requirements R1, R7, R8.
@MainActor
final class FlowDeckCanvasSmokeTests: XCTestCase {

    func test_firstFingerTap_producesPerformRegionFillLogEntry() throws {
        XCTFail(
            "SMOKE SCRIPT NOT IMPLEMENTED: Scripts/qa/canvas_smoke.sh does not exist yet. " +
            "U6 must create it. The script should: " +
            "(1) boot the configured simulator UDID, " +
            "(2) reset UserDefaults keys hasSeenOnboarding + hasCompletedFirstFill, " +
            "(3) launch the app via FlowDeck, " +
            "(4) advance past onboarding (button-label or coordinate-tap fallback), " +
            "(5) open any template, " +
            "(6) tap the canvas center, " +
            "(7) scrape stdout/stderr for '[ViewModel] performRegionFill — hit region' " +
            "within 2 seconds. " +
            "Script exits 0 on success, non-zero on any step failure. " +
            "Once the script lands, replace this XCTFail with Process.launch(script) + " +
            "assertion on exit code, and surface script stdout on failure."
        )
    }
}
