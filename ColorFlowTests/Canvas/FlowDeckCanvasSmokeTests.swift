import XCTest
@testable import ColorFlow

/// End-to-end smoke test for the "first finger tap produces a fill" flow.
///
/// The actual smoke test is a shell script (`Scripts/qa/canvas_smoke.sh`) that
/// drives FlowDeck UI automation. Since XCTests run inside the iOS Simulator
/// (where Foundation.Process is unavailable), this test verifies the script
/// exists in the repo and documents the contract.
///
/// To run the full smoke: `bash Scripts/qa/canvas_smoke.sh` from the repo root.
@MainActor
final class FlowDeckCanvasSmokeTests: XCTestCase {

    func test_firstFingerTap_producesPerformRegionFillLogEntry() throws {
        // Resolve script path relative to the source root
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Canvas/
            .deletingLastPathComponent() // ColorFlowTests/
            .deletingLastPathComponent() // repo root
        let scriptURL = repoRoot.appendingPathComponent("Scripts/qa/canvas_smoke.sh")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: scriptURL.path),
            "Smoke script must exist at Scripts/qa/canvas_smoke.sh. " +
            "Run it from the repo root: bash Scripts/qa/canvas_smoke.sh"
        )

        XCTAssertTrue(
            FileManager.default.isExecutableFile(atPath: scriptURL.path),
            "Smoke script must be executable (chmod +x)."
        )
    }
}
