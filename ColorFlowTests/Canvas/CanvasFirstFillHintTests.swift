import XCTest
@testable import ColorFlow

@MainActor
final class CanvasFirstFillHintTests: XCTestCase {

    private let hasCompletedFirstFillKey = "hasCompletedFirstFill"
    private let hasSeenOnboardingKey = "hasSeenOnboarding"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: hasCompletedFirstFillKey)
        UserDefaults.standard.removeObject(forKey: hasSeenOnboardingKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: hasCompletedFirstFillKey)
        UserDefaults.standard.removeObject(forKey: hasSeenOnboardingKey)
        super.tearDown()
    }

    // MARK: - hasCompletedFirstFill lifecycle

    func test_beforeAnyFill_hasCompletedFirstFillIsFalse() {
        XCTAssertFalse(
            UserDefaults.standard.bool(forKey: hasCompletedFirstFillKey),
            "On a fresh install, hasCompletedFirstFill must be false."
        )
    }

    func test_afterSuccessfulFill_hasCompletedFirstFillIsTrue() async throws {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        guard let geometry = viewModel.templateGeometry,
              let region = geometry.regions.first else {
            XCTFail("Fixture must have regions")
            return
        }

        let point = CanvasTestFixture.interiorPoint(of: region)
        let viewSize = geometry.viewBox.size
        await viewModel.performRegionFill(at: point, in: viewSize)

        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: hasCompletedFirstFillKey),
            "After a successful region fill, hasCompletedFirstFill must be true."
        )
    }

    func test_fillMiss_doesNotFlipHasCompletedFirstFill() async throws {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        let viewSize = viewModel.templateGeometry!.viewBox.size
        await viewModel.performRegionFill(at: CanvasTestFixture.pointOutsideAllRegions, in: viewSize)

        XCTAssertFalse(
            UserDefaults.standard.bool(forKey: hasCompletedFirstFillKey),
            "A fill miss (no region hit) must not flip hasCompletedFirstFill."
        )
    }

    func test_secondFill_doesNotCrashOrResetFlag() async throws {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()

        guard let geometry = viewModel.templateGeometry,
              geometry.regions.count >= 2 else {
            XCTFail("Fixture must have >= 2 regions")
            return
        }

        let viewSize = geometry.viewBox.size
        let p1 = CanvasTestFixture.interiorPoint(of: geometry.regions[0])
        let p2 = CanvasTestFixture.interiorPoint(of: geometry.regions[1])

        await viewModel.performRegionFill(at: p1, in: viewSize)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: hasCompletedFirstFillKey))

        await viewModel.performRegionFill(at: p2, in: viewSize)
        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: hasCompletedFirstFillKey),
            "Second fill must not reset the flag."
        )
    }
}
