// SVGCatalogParityTests.swift
//
// Swift-side parity test: runs every SVG in Resources/Templates/ through
// SVGParser.parse and asserts success. This is the safety net that ensures
// the Python validator (Scripts/validate_template_svg.py) and the on-device
// parser stay in sync.
//
// If a new SVG is committed that the Python validator passes but SVGParser
// rejects, this test fails. Fix the SVG or the spec.
//
// As with the other A-phase test files, this requires the ColorFlowTests
// target to be wired in project.yml (follow-up F-05 from the A1 audit).

import XCTest
@testable import ColorFlow

final class SVGCatalogParityTests: XCTestCase {

    /// Discover all SVG files in the test-host bundle.
    ///
    /// The preBuildScript in project.yml copies all SVGs from
    /// `ColorFlow/Resources/Templates/` flat into the app bundle root.
    /// This mirrors what `Template.svgURL` does at runtime.
    private func allBundledSVGURLs() -> [URL] {
        let bundle = Bundle(for: type(of: self))
        // Under a UI test / unit test host, Bundle.main is the host app.
        let searchBundle = Bundle.main.bundleIdentifier?.contains("xctest") == true
            ? bundle
            : Bundle.main

        // Try the Templates subdirectory first, then bundle root (flat copy).
        var urls: [URL] = []
        if let dir = searchBundle.url(forResource: "Templates", withExtension: nil) {
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            ) {
                urls = contents.filter { $0.pathExtension.lowercased() == "svg" }
            }
        }
        // Also check bundle root for the flat-copy fallback path.
        if urls.isEmpty, let resourceURL = searchBundle.resourceURL {
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil
            ) {
                urls = contents.filter { $0.pathExtension.lowercased() == "svg" }
            }
        }
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Parity test

    func test_allBundledSVGs_parseSuccessfully() throws {
        let urls = allBundledSVGURLs()

        XCTAssertFalse(
            urls.isEmpty,
            "No SVG files found in the app bundle. Check that the preBuildScript in project.yml is copying templates."
        )

        var failures: [(filename: String, error: String)] = []

        for url in urls {
            let result = SVGParser.parse(url: url)
            switch result {
            case .success(let geometry):
                // Extra sanity: every successfully-parsed SVG should have
                // a non-zero viewBox and at least one path (region or decorative).
                XCTAssertTrue(
                    geometry.viewBox.width > 0 && geometry.viewBox.height > 0,
                    "\(url.lastPathComponent): parsed successfully but viewBox has zero dimensions"
                )
                XCTAssertFalse(
                    geometry.regions.isEmpty && geometry.decorativePaths.isEmpty,
                    "\(url.lastPathComponent): parsed successfully but contains no regions or decorative paths"
                )
            case .failure(let error):
                failures.append((url.lastPathComponent, error.localizedDescription))
            }
        }

        if !failures.isEmpty {
            let report = failures
                .map { "  \($0.filename): \($0.error)" }
                .joined(separator: "\n")
            XCTFail("The following SVG files failed to parse:\n\(report)\n\n" +
                    "Run `python3 Scripts/validate_template_svg.py` for detailed diagnostics.")
        }
    }

    // MARK: - Completeness check: templates.json ↔ bundle

    /// Every template referenced in templates.json must have a corresponding
    /// SVG file in the bundle. This prevents silent missing-asset failures.
    func test_templatesJSON_allSVGsPresent() throws {
        guard let jsonURL = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: jsonURL),
              let templates = try? JSONDecoder().decode([TemplateJSONEntry].self, from: data)
        else {
            // templates.json absent → app falls back to bundledTemplates; not a test failure here.
            // SVGCatalogParityTests still runs via allBundledSVGs test above.
            throw XCTSkip("templates.json not found in bundle; fallback catalogue in use.")
        }

        let bundleRoot = Bundle.main.resourceURL ?? URL(fileURLWithPath: "/dev/null")
        let _ = Bundle.main.url(forResource: "Templates", withExtension: nil)

        for entry in templates {
            let filename = entry.svgFilename
            let name = (filename as NSString).deletingPathExtension
            let ext  = (filename as NSString).pathExtension

            let foundInSubdir = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Templates") != nil
            let foundFlat     = Bundle.main.url(forResource: name, withExtension: ext) != nil
            let foundManual: Bool = {
                let u = bundleRoot.appendingPathComponent("Templates/\(filename)")
                return FileManager.default.fileExists(atPath: u.path)
            }()

            XCTAssertTrue(
                foundInSubdir || foundFlat || foundManual,
                "templates.json references '\(filename)' but no matching SVG was found in the app bundle."
            )
        }
    }

    // MARK: - UUID stability (guards against accidental re-generation)

    func test_existing11Templates_haveStableUUIDs() throws {
        // These UUIDs are load-bearing: changing them would corrupt any user
        // project created before the change. Never regenerate them.
        let stableIDs: [(uuid: String, name: String)] = [
            ("33333333-0000-0000-0000-000000000001", "Lotus Mandala"),
            ("33333333-0000-0000-0000-000000000006", "Owl Portrait"),
            ("33333333-0000-0000-0000-000000000009", "Butterfly Garden"),
            ("33333333-0000-0000-0000-000000000021", "Rose Bouquet"),
            ("33333333-0000-0000-0000-000000000017", "Wave Pattern"),
            ("33333333-0000-0000-0000-000000000016", "Hexagon Grid"),
            ("33333333-0000-0000-0000-000000000030", "Coffee Morning"),
            ("33333333-0000-0000-0000-000000000031", "Sleeping Cats"),
            ("33333333-0000-0000-0000-000000000032", "Cloud Sofa"),
            ("33333333-0000-0000-0000-000000000033", "Cat Fish Dinner"),
            ("33333333-0000-0000-0000-000000000034", "Kitchen Morning"),
        ]

        let allTemplates = Template.loadAll()
        let byID = Dictionary(uniqueKeysWithValues: allTemplates.map { ($0.id.uuidString.lowercased(), $0) })

        for (uuid, name) in stableIDs {
            let template = byID[uuid.lowercased()]
            XCTAssertNotNil(template,
                            "Template with UUID \(uuid) ('\(name)') is missing from the loaded template list. " +
                            "Never change existing template UUIDs — it would corrupt user projects.")
            if let t = template {
                XCTAssertEqual(t.name, name,
                               "Template UUID \(uuid) has name '\(t.name)' but expected '\(name)'. " +
                               "Name changes are fine but UUID changes are not.")
            }
        }
    }
}

// MARK: - Minimal JSON decoding type (avoids coupling to the full Template model)

private struct TemplateJSONEntry: Decodable {
    let id: String
    let name: String
    let svgFilename: String
}
