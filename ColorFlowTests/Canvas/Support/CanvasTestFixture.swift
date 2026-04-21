import XCTest
import CoreGraphics
@testable import ColorFlow

/// Shared fixture for Canvas unit tests.
///
/// Loads a known-good SVG from the test-host bundle, constructs a `Project` +
/// `Template` pair, builds a fully-initialized `CanvasViewModel`, and awaits
/// `loadTemplate()` so geometry + rendered layers are ready to query.
///
/// The SVG resolution mirrors `SVGCatalogParityTests` — under xctest, the host
/// app bundle is where the preBuildScript has copied `Templates/*.svg`.
enum CanvasTestFixture {

    /// Default fixture template: sunflower_mandala has 27 regions with
    /// well-separated centroids — good for hit-testing tests.
    static let defaultTemplateName = "sunflower_mandala"

    /// Build a `CanvasViewModel` loaded with the given template. Returns nil
    /// if the SVG cannot be resolved or parsing fails.
    ///
    /// - Parameter templateName: filename stem (no `.svg`) to load from the
    ///   test-host bundle. Defaults to `sunflower_mandala`.
    @MainActor
    static func makeLoadedViewModel(
        templateName: String = defaultTemplateName
    ) async throws -> CanvasViewModel {
        let template = try makeTemplate(name: templateName)
        let project = Project(template: template)
        let viewModel = CanvasViewModel(project: project, template: template)
        await viewModel.loadTemplate()

        guard viewModel.templateGeometry != nil else {
            throw FixtureError.templateNotLoaded(templateName)
        }
        return viewModel
    }

    /// Build a `Template` pointing at a bundled SVG. The `svgFilename` is the
    /// basename with `.svg`; the rest of the metadata is dummy data sufficient
    /// for the viewmodel to load and render.
    static func makeTemplate(name: String = defaultTemplateName) throws -> Template {
        let filename = "\(name).svg"
        guard resolveBundledSVGURL(filename: filename) != nil else {
            throw FixtureError.svgNotInBundle(filename)
        }

        return Template(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: name,
            category: .mandalas,
            difficulty: .easy,
            svgFilename: filename,
            thumbnailFilename: "thumb_\(name).png",
            userTemplateDirectoryPath: nil
        )
    }

    /// Pick a doc-space point guaranteed to be inside the given region by
    /// returning the centroid of its bounding box. Adequate for all the
    /// regions in `sunflower_mandala` because their bboxes are convex enough
    /// that the centroid falls inside the path itself.
    static func interiorPoint(of region: RegionGeometry) -> CGPoint {
        CGPoint(x: region.bounds.midX, y: region.bounds.midY)
    }

    /// A doc-space point guaranteed to be outside every region in the
    /// default fixture. `sunflower_mandala` has viewBox 800×800 with its
    /// outermost region bbox ending at y=740; (10,10) is in blank whitespace.
    static var pointOutsideAllRegions: CGPoint {
        CGPoint(x: 10, y: 10)
    }

    // MARK: - Errors

    enum FixtureError: Error, CustomStringConvertible {
        case svgNotInBundle(String)
        case templateNotLoaded(String)

        var description: String {
            switch self {
            case .svgNotInBundle(let filename):
                return "SVG '\(filename)' not found in test-host bundle. " +
                       "Verify the preBuildScript in project.yml is copying Templates/*.svg."
            case .templateNotLoaded(let name):
                return "CanvasViewModel.loadTemplate did not produce geometry for '\(name)'."
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
