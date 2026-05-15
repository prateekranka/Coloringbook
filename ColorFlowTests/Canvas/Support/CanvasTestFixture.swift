import XCTest
import CoreGraphics
@testable import ColorFlow

/// Shared fixture for Canvas unit tests.
///
/// Loads a known-good SVG from the test-host bundle and returns parsed
/// geometry for lower-level clipping and rendering tests.
///
/// The SVG resolution mirrors `SVGCatalogParityTests` — under xctest, the host
/// app bundle is where the preBuildScript has copied `Templates/*.svg`.
enum CanvasTestFixture {

    /// Default fixture template with well-separated regions for hit-testing.
    static let defaultTemplateName = "wildflowers"

    /// Parse a bundled SVG into geometry, throwing if the SVG cannot be
    /// resolved or parsed.
    ///
    /// - Parameter templateName: filename stem (no `.svg`) to load from the
    ///   test-host bundle. Defaults to `wildflowers`.
    static func makeGeometry(
        templateName: String = defaultTemplateName
    ) throws -> TemplateGeometry {
        let filename = "\(templateName).svg"
        guard let url = resolveBundledSVGURL(filename: filename) else {
            throw FixtureError.svgNotInBundle(filename)
        }

        switch SVGParser.parse(url: url) {
        case .success(let geometry):
            return geometry
        case .failure(let error):
            throw FixtureError.parseFailed(templateName, error)
        }
    }

    /// Geometry fixture for stroke clipping tests. These tests care about
    /// boundary behavior, so they use simple non-overlapping regions instead
    /// of depending on the first region produced by generated catalog art.
    static func makeClippingGeometry() -> TemplateGeometry {
        TemplateGeometry(
            viewBox: CGRect(x: 0, y: 0, width: 200, height: 200),
            regions: [
                makeRectRegion(
                    id: "clip-region-a",
                    rect: CGRect(x: 40, y: 40, width: 80, height: 80),
                    zIndex: 0
                ),
                makeRectRegion(
                    id: "clip-region-b",
                    rect: CGRect(x: 150, y: 40, width: 40, height: 40),
                    zIndex: 1
                )
            ],
            decorativePaths: []
        )
    }

    /// Build a `Template` pointing at a bundled SVG. The `svgFilename` is the
    /// basename with `.svg`; the rest of the metadata is dummy data sufficient
    /// for service-level tests.
    static func makeTemplate(name: String = defaultTemplateName) throws -> Template {
        let filename = "\(name).svg"
        guard resolveBundledSVGURL(filename: filename) != nil else {
            throw FixtureError.svgNotInBundle(filename)
        }

        return Template(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: name,
            category: .botanicals,
            difficulty: .easy,
            svgFilename: filename,
            thumbnailFilename: "thumb_\(name).png",
            userTemplateDirectoryPath: nil
        )
    }

    /// Pick a doc-space point inside the given region by returning the
    /// centroid of its bounding box.
    static func interiorPoint(of region: RegionGeometry) -> CGPoint {
        CGPoint(x: region.bounds.midX, y: region.bounds.midY)
    }

    static func representativeFillPoint(in geometry: TemplateGeometry) -> CGPoint? {
        for region in geometry.regions {
            if let point = representativePoint(in: region),
               geometry.region(at: point) != nil {
                return point
            }
        }
        return nil
    }

    /// A doc-space point guaranteed to be outside every region in the
    /// default fixture.
    static var pointOutsideAllRegions: CGPoint {
        CGPoint(x: -10, y: -10)
    }

    private static func representativePoint(in region: RegionGeometry) -> CGPoint? {
        let fractions: [CGFloat] = [0.5, 0.35, 0.65, 0.2, 0.8]
        for yFraction in fractions {
            for xFraction in fractions {
                let point = CGPoint(
                    x: region.bounds.minX + region.bounds.width * xFraction,
                    y: region.bounds.minY + region.bounds.height * yFraction
                )
                if region.path.contains(point, using: region.fillRule) {
                    return point
                }
            }
        }
        return nil
    }

    private static func makeRectRegion(
        id: String,
        rect: CGRect,
        zIndex: Int
    ) -> RegionGeometry {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return RegionGeometry(
            id: id,
            path: path,
            bounds: path.boundingBoxOfPath,
            fillRule: .winding,
            zIndex: zIndex
        )
    }

    // MARK: - Errors

    enum FixtureError: Error, CustomStringConvertible {
        case svgNotInBundle(String)
        case parseFailed(String, Error)

        var description: String {
            switch self {
            case .svgNotInBundle(let filename):
                return "SVG '\(filename)' not found in test-host bundle. " +
                       "Verify the preBuildScript in project.yml is copying Templates/*.svg."
            case .parseFailed(let name, let error):
                return "SVGParser failed to parse '\(name)': \(error)"
            }
        }
    }

    // MARK: - Bundle resolution

    /// Mirrors `Template.svgURL`'s bundle lookup strategy so tests see the
    /// same assets the app would at runtime.
    private static func resolveBundledSVGURL(filename: String) -> URL? {
        let name = (filename as NSString).deletingPathExtension
        let ext  = (filename as NSString).pathExtension

        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Templates")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.resourceURL.flatMap {
                let url = $0.appendingPathComponent("Templates/\(filename)")
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
    }
}
