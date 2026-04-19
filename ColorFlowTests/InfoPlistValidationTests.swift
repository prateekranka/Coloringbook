// InfoPlistValidationTests.swift
//
// NOTE: The `ColorFlowTests` target is not yet wired in `project.yml`.
// This file is written at the plan-specified path so that the moment the
// test target is added (tracked as a follow-up blocker in the A1 audit
// under F-05), these assertions run automatically. Until then, the file
// lives as documentation of the Info.plist contract we rely on for App
// Store submission.
//
// When wiring the target, add to `project.yml`:
//
//   ColorFlowTests:
//     type: bundle.unit-test
//     platform: iOS
//     deploymentTarget: "17.0"
//     sources:
//       - path: ColorFlowTests
//     dependencies:
//       - target: ColorFlow
//
// And extend the `ColorFlow` scheme's `test.targets` to include
// `ColorFlowTests`.

import XCTest

final class InfoPlistValidationTests: XCTestCase {

    /// The app bundle's Info.plist. Resolved via the app target under test.
    private var infoPlist: [String: Any] {
        let bundle = Bundle(for: type(of: self))
        // When running under a host app, `Bundle.main` is the host.
        let hostBundle = Bundle.main.bundleIdentifier == "com.apple.dt.xctest.tool"
            ? bundle
            : Bundle.main
        guard let dict = hostBundle.infoDictionary else {
            XCTFail("Info.plist not loaded into bundle under test")
            return [:]
        }
        return dict
    }

    // MARK: - Required keys for App Store submission

    func test_launchScreen_isDeclared() {
        XCTAssertNotNil(
            infoPlist["UILaunchScreen"],
            "UILaunchScreen is required on iOS 14+ (replaces LaunchScreen.storyboard). Missing this key causes App Store rejection."
        )
    }

    func test_supportedInterfaceOrientations_baseKey_isPopulated() {
        let orientations = infoPlist["UISupportedInterfaceOrientations"] as? [String] ?? []
        XCTAssertFalse(
            orientations.isEmpty,
            "Base UISupportedInterfaceOrientations must not be empty. iPad Split View / Slide Over can hit this key even when ~ipad variant is present."
        )
        XCTAssertTrue(
            orientations.contains("UIInterfaceOrientationPortrait"),
            "Portrait must be supported."
        )
    }

    func test_supportedInterfaceOrientations_ipadVariant_coversAllFour() {
        let orientations = infoPlist["UISupportedInterfaceOrientations~ipad"] as? [String] ?? []
        let required: Set<String> = [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
        ]
        XCTAssertTrue(
            required.isSubset(of: Set(orientations)),
            "iPad builds must declare all four orientations. Missing: \(required.subtracting(Set(orientations)))"
        )
    }

    func test_displayName_isPresent() {
        let name = infoPlist["CFBundleDisplayName"] as? String ?? ""
        XCTAssertFalse(name.isEmpty, "CFBundleDisplayName must be set for the home-screen label.")
    }

    func test_photoLibraryAddPurposeString_isPresent_andMeaningful() {
        let purpose = infoPlist["NSPhotoLibraryAddUsageDescription"] as? String ?? ""
        XCTAssertFalse(purpose.isEmpty, "Saving finished artwork to Photos requires a non-empty NSPhotoLibraryAddUsageDescription.")
        XCTAssertGreaterThan(
            purpose.count, 20,
            "Purpose string '\(purpose)' is too terse for App Review. Explain the user-visible reason in one sentence."
        )
    }

    func test_encryptionExemption_isDeclared() {
        let value = infoPlist["ITSAppUsesNonExemptEncryption"] as? Bool
        XCTAssertEqual(
            value, false,
            "ITSAppUsesNonExemptEncryption must be explicitly false. App uses only Apple-provided TLS, no custom crypto. Declaring this here avoids the per-upload TestFlight prompt."
        )
    }

    func test_requiresIPhoneOS_isTrue() {
        let value = infoPlist["LSRequiresIPhoneOS"] as? Bool
        XCTAssertEqual(value, true, "LSRequiresIPhoneOS must be true for iOS apps.")
    }

    // MARK: - Deprecated / migrated keys we must NOT carry

    func test_launchStoryboard_isAbsent() {
        XCTAssertNil(
            infoPlist["UILaunchStoryboardName"],
            "UILaunchStoryboardName is superseded by UILaunchScreen on iOS 14+. Having both causes undefined behaviour."
        )
    }
}
