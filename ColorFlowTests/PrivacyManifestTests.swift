// PrivacyManifestTests.swift
//
// Validates the PrivacyInfo.xcprivacy bundled into the app matches what
// `ce:plan` A2 committed to. Keep this test and
// `docs/solutions/2026-04-privacy-manifest-audit.md` in sync: whenever the
// audit doc changes, this test must change too.
//
// As with InfoPlistValidationTests.swift, this file runs only once the
// `ColorFlowTests` target is wired in `project.yml` (tracked as F-05 in
// the A1 audit).

import XCTest

final class PrivacyManifestTests: XCTestCase {

    private func manifest() throws -> [String: Any] {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
            XCTFail("PrivacyInfo.xcprivacy missing from app bundle. Check project.yml resources.")
            return [:]
        }
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dict = plist as? [String: Any] else {
            XCTFail("PrivacyInfo.xcprivacy is not a dictionary")
            return [:]
        }
        return dict
    }

    // MARK: - Top-level contract

    func test_privacyManifest_declaresNoTracking() throws {
        let dict = try manifest()
        XCTAssertEqual(
            dict["NSPrivacyTracking"] as? Bool, false,
            "ColorFlow does not track. Flipping this to true requires product + legal review."
        )
        let domains = dict["NSPrivacyTrackingDomains"] as? [String] ?? []
        XCTAssertTrue(domains.isEmpty, "No tracking domains expected.")
    }

    func test_privacyManifest_declaresNoDataCollection() throws {
        let dict = try manifest()
        let collected = dict["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        XCTAssertTrue(
            collected.isEmpty,
            "ColorFlow does not collect any data today. If this changes, update the App Privacy questionnaire first."
        )
    }

    // MARK: - Required Reason API categories

    func test_requiredReasonAPI_userDefaults_declaredWithCA92_1() throws {
        let dict = try manifest()
        let apis = dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []

        let userDefaults = apis.first { entry in
            (entry["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        XCTAssertNotNil(
            userDefaults,
            "App uses @AppStorage (UserDefaults). Category must be declared."
        )
        let reasons = userDefaults?["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
        XCTAssertTrue(
            reasons.contains("CA92.1"),
            "CA92.1 is the correct reason for same-app UserDefaults access."
        )
    }

    func test_requiredReasonAPI_categoriesAreBoundedToAuditedSet() throws {
        // Guardrail: adding a new Required Reason category without updating the
        // audit doc is a bug. If this test fails, update both this test and
        // docs/solutions/2026-04-privacy-manifest-audit.md together.
        let expected: Set<String> = [
            "NSPrivacyAccessedAPICategoryUserDefaults",
        ]
        let dict = try manifest()
        let apis = dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        let actual = Set(apis.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
        XCTAssertEqual(
            actual, expected,
            "Required Reason API categories drifted from the audit. Actual: \(actual). Expected: \(expected)."
        )
    }

    // MARK: - Purpose string coverage (Info.plist, not manifest, but adjacent)

    func test_infoPlist_carriesAllPurposeStringsWeExpectToSubmit() {
        let info = Bundle.main.infoDictionary ?? [:]
        let expectedKeys = [
            "NSPhotoLibraryAddUsageDescription",     // save artwork
            "NSPhotoLibraryUsageDescription",        // import photo → coloring page (Phase C)
            "NSCameraUsageDescription",              // camera capture → coloring page (Phase C)
        ]
        for key in expectedKeys {
            let value = info[key] as? String ?? ""
            XCTAssertFalse(
                value.isEmpty,
                "\(key) must be present and non-empty before App Store submission."
            )
        }
    }
}
