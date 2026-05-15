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

import UIKit
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

    func test_allBundledSVGs_haveAtLeastOneFillableRegion() throws {
        let urls = allBundledSVGURLs()
        XCTAssertFalse(urls.isEmpty)

        for url in urls {
            guard case .success(let geometry) = SVGParser.parse(url: url) else {
                XCTFail("\(url.lastPathComponent) should parse before checking fillable regions.")
                continue
            }

            XCTAssertFalse(
                geometry.regions.isEmpty,
                "\(url.lastPathComponent) must expose at least one fillable region."
            )
            XCTAssertNotNil(
                CanvasTestFixture.representativeFillPoint(in: geometry),
                "\(url.lastPathComponent) should have a hittable point inside a fillable region."
            )
        }
    }

    // MARK: - Completeness check: templates.json ↔ bundle

    /// Every template referenced in templates.json must have a corresponding
    /// SVG file in the bundle. This prevents silent missing-asset failures.
    func test_templatesJSON_allSVGsPresent() throws {
        let templates = try loadManifestEntries()

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

    func test_templatesJSON_hasExactSVGParityWithBundle() throws {
        let manifestFilenames = Set(try loadManifestEntries().map(\.svgFilename))
        let bundledFilenames = Set(allBundledSVGURLs().map(\.lastPathComponent))

        XCTAssertEqual(
            manifestFilenames,
            bundledFilenames,
            "templates.json and bundled SVG resources must stay in one-to-one parity."
        )
    }

    func test_templatesJSON_matchesEmbeddedFallbackCatalogue() throws {
        let manifestEntries = Set(try loadManifestEntries().map(CatalogEntry.init))
        let fallbackEntries = Set(Template.bundledTemplates.map(CatalogEntry.init))

        XCTAssertEqual(
            manifestEntries,
            fallbackEntries,
            "templates.json and Template.bundledTemplates must remain interchangeable."
        )
    }

    func test_allBundledTemplateThumbnailsRenderNonBlankArtwork() async throws {
        let templates = Template.loadAll()
        XCTAssertFalse(templates.isEmpty)

        for template in templates {
            let image = await TemplateRenderer.thumbnail(for: template)
            let thumbnail = try XCTUnwrap(image, "\(template.name) should render a thumbnail.")

            XCTAssertEqual(thumbnail.size.width, 400, accuracy: 0.1)
            XCTAssertEqual(thumbnail.size.height, 400, accuracy: 0.1)
            XCTAssertTrue(
                thumbnail.hasVisibleArtwork,
                "\(template.name) thumbnail should contain visible line art, not just a blank background."
            )
        }
    }

    // MARK: - UUID stability (guards against accidental re-generation)

    func test_currentBundledTemplates_haveStableUUIDs() throws {
        // These UUIDs are load-bearing for projects created against the
        // current bundled catalog. Never regenerate them casually.
        let stableIDs: [(uuid: String, name: String)] = [
            ("33333333-0000-0000-0000-000000000101", "Wildflowers"),
            ("33333333-0000-0000-0000-000000000102", "Lemon Branch"),
            ("33333333-0000-0000-0000-000000000103", "Sunday Light"),
            ("33333333-0000-0000-0000-000000000104", "Amalfi Afternoon"),
            ("33333333-0000-0000-0000-000000000105", "Toucan Canopy"),
            ("33333333-0000-0000-0000-000000000106", "Lemon Balcony"),
            ("33333333-0000-0000-0000-000000000107", "Quiet Balcony Room"),
            ("33333333-0000-0000-0000-000000000108", "Rainy Library"),
            ("33333333-0000-0000-0000-000000000109", "Mediterranean Kitchen Window"),
            ("33333333-0000-0000-0000-000000000110", "Florist Window"),
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

    private func loadManifestEntries() throws -> [TemplateJSONEntry] {
        guard let jsonURL = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: jsonURL),
              let templates = try? JSONDecoder().decode([TemplateJSONEntry].self, from: data)
        else {
            XCTFail("templates.json not found in bundle; manifest parity cannot be verified.")
            return []
        }
        return templates
    }
}

// MARK: - Minimal JSON decoding type (avoids coupling to the full Template model)

private struct TemplateJSONEntry: Decodable {
    let id: String
    let name: String
    let category: TemplateCategory
    let difficulty: Difficulty
    let svgFilename: String
    let thumbnailFilename: String
}

private struct CatalogEntry: Hashable {
    let id: UUID
    let name: String
    let category: TemplateCategory
    let difficulty: Difficulty
    let svgFilename: String
    let thumbnailFilename: String

    init(_ entry: TemplateJSONEntry) {
        id = UUID(uuidString: entry.id) ?? UUID()
        name = entry.name
        category = entry.category
        difficulty = entry.difficulty
        svgFilename = entry.svgFilename
        thumbnailFilename = entry.thumbnailFilename
    }

    init(_ template: Template) {
        id = template.id
        name = template.name
        category = template.category
        difficulty = template.difficulty
        svgFilename = template.svgFilename
        thumbnailFilename = template.thumbnailFilename
    }
}

private extension UIImage {
    var hasVisibleArtwork: Bool {
        let width = 24
        let height = 24
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        return pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return false
            }

            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            UIGraphicsPushContext(context)
            draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            UIGraphicsPopContext()

            let bytes = buffer.bindMemory(to: UInt8.self)
            let background = (r: bytes[0], g: bytes[1], b: bytes[2])

            for index in stride(from: 0, to: bytes.count, by: 4) {
                let delta = abs(Int(bytes[index]) - Int(background.r))
                    + abs(Int(bytes[index + 1]) - Int(background.g))
                    + abs(Int(bytes[index + 2]) - Int(background.b))
                if delta > 24 {
                    return true
                }
            }

            return false
        }
    }
}
