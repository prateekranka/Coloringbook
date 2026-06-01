import XCTest
import UIKit
@testable import ColorFlow

@MainActor
final class RegionPigmentEngineTests: XCTestCase {
    private var geometry: TemplateGeometry!
    private var engine: RegionPigmentEngine!

    override func setUp() {
        geometry = CanvasTestFixture.makeClippingGeometry()
        engine = RegionPigmentEngine(geometry: geometry)
    }

    override func tearDown() {
        geometry = nil
        engine = nil
    }

    func test_regionMaskGeneration_containsRegionInterior() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let mask = engine.mask(for: region)
        let point = CanvasTestFixture.interiorPoint(of: region)
        XCTAssertGreaterThan(mask.image.alpha(at: point), 0)
        XCTAssertEqual(mask.image.alpha(at: CanvasTestFixture.pointOutsideAllRegions), 0)
    }

    func test_fillWritesSolidColorIntoPigmentBitmapThroughRegionMask() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        _ = engine.fill(regionID: region.id, colorHex: "#FF0000")

        let interior = CanvasTestFixture.interiorPoint(of: region)
        XCTAssertGreaterThan(engine.image.alpha(at: interior), 200)
        XCTAssertEqual(engine.image.alpha(at: CanvasTestFixture.pointOutsideAllRegions), 0)
    }

    func test_highResolutionBitmapFillsTransformedRegionMask() throws {
        engine = RegionPigmentEngine(geometry: geometry, bitmapSize: CGSize(width: 1000, height: 1000))
        let region = try XCTUnwrap(geometry.regions.first)
        let documentInterior = CanvasTestFixture.interiorPoint(of: region)
        let bitmapInterior = documentInterior.applying(documentToBitmapTransform(for: engine))
        let outside = CanvasTestFixture.pointOutsideAllRegions.applying(documentToBitmapTransform(for: engine))

        let patch = try XCTUnwrap(engine.fill(regionID: region.id, colorHex: "#FF0000"))

        XCTAssertEqual(engine.image.size, CGSize(width: 1000, height: 1000))
        XCTAssertGreaterThan(engine.image.alpha(at: bitmapInterior), 200)
        XCTAssertEqual(engine.image.alpha(at: outside), 0)
        XCTAssertTrue(patch.rect.intersects(region.bounds))
    }

    func test_highResolutionBitmapScalesCleanStrokeAndKeepsItClipped() throws {
        engine = RegionPigmentEngine(geometry: geometry, bitmapSize: CGSize(width: 1000, height: 1000))
        let regionA = try XCTUnwrap(geometry.regions.first)
        let regionB = try XCTUnwrap(geometry.regions.dropFirst().first)
        let start = CanvasTestFixture.interiorPoint(of: regionA)
        let end = CanvasTestFixture.interiorPoint(of: regionB)
        let transform = documentToBitmapTransform(for: engine)

        let patch = engine.renderCleanStroke(
            tool: .marker,
            colorHex: "#00FF00",
            points: [start, end],
            size: 18,
            opacity: 1
        )

        XCTAssertNotNil(patch)
        XCTAssertGreaterThan(engine.image.alpha(at: start.applying(transform)), 0)
        XCTAssertEqual(engine.image.alpha(at: end.applying(transform)), 0)
    }

    func test_eraserPartiallyErasesTapFillOnlyWhereItTouches() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let untouched = CGPoint(x: region.bounds.minX + 8, y: region.bounds.minY + 8)

        _ = engine.fill(regionID: region.id, colorHex: "#FF0000")
        _ = engine.renderCleanStroke(
            tool: .eraser,
            colorHex: "#FFFFFF",
            points: [CGPoint(x: interior.x - 8, y: interior.y), CGPoint(x: interior.x + 8, y: interior.y)],
            size: 24,
            opacity: 1
        )

        XCTAssertLessThan(engine.image.alpha(at: interior), 30)
        XCTAssertGreaterThan(engine.image.alpha(at: untouched), 180)
    }

    func test_cleanEraserStartingOutsideRegionErasesAfterEnteringRegion() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let outside = CGPoint(x: region.bounds.minX - 12, y: interior.y)

        _ = engine.fill(regionID: region.id, colorHex: "#FF0000")
        let patch = engine.renderCleanStroke(
            tool: .eraser,
            colorHex: "#000000",
            points: [outside, CGPoint(x: region.bounds.minX + 8, y: interior.y), interior],
            size: 24,
            opacity: 1
        )

        XCTAssertNotNil(patch)
        XCTAssertLessThan(engine.image.alpha(at: interior), 30)
    }

    func test_cleanPaintStartingOutsideRegionStillDoesNotCommit() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let outside = CGPoint(x: region.bounds.minX - 12, y: interior.y)

        let patch = engine.renderCleanStroke(
            tool: .marker,
            colorHex: "#00AAFF",
            points: [outside, interior],
            size: 24,
            opacity: 1
        )

        XCTAssertNil(patch)
        XCTAssertEqual(engine.image.alpha(at: interior), 0)
    }

    func test_regionNearAcceptsNearBoundaryFillTap() {
        let geometry = CanvasTestFixture.makeClippingGeometry()
        let outsideBoundary = CGPoint(x: 38, y: 80)

        XCTAssertNil(geometry.region(at: outsideBoundary))
        XCTAssertEqual(geometry.region(near: outsideBoundary, radius: 4)?.id, "clip-region-a")
    }

    func test_eraserDoesNotCreateGrayPixelsInErasedArea() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)

        _ = engine.fill(regionID: region.id, colorHex: "#FF0000")
        _ = engine.renderCleanStroke(
            tool: .eraser,
            colorHex: "#000000",
            points: [CGPoint(x: interior.x - 8, y: interior.y), CGPoint(x: interior.x + 8, y: interior.y)],
            size: 24,
            opacity: 1
        )

        let pigmentPixel = try XCTUnwrap(engine.image.rgba(at: interior))
        XCTAssertLessThan(pigmentPixel.a, 30)

        let export = CanvasSnapshotRenderer().render(
            lineArtImage: nil,
            pigmentLayer: engine.image,
            backgroundColor: .white,
            size: geometry.viewBox.size
        )
        let exportPixel = try XCTUnwrap(export.rgba(at: interior))
        XCTAssertGreaterThan(exportPixel.r, 245)
        XCTAssertGreaterThan(exportPixel.g, 245)
        XCTAssertGreaterThan(exportPixel.b, 245)
    }

    func test_eraserDoesNotEraseLineArtOrBackgroundInExport() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        _ = engine.fill(regionID: region.id, colorHex: "#FF0000")
        _ = engine.renderCleanStroke(tool: .eraser, colorHex: "#FFFFFF", points: [interior, CGPoint(x: interior.x + 10, y: interior.y)], size: 20, opacity: 1)

        let export = TemplateRenderer.renderExport(
            geometry: geometry,
            fills: [:],
            pigmentLayer: engine.image,
            pencilImage: nil,
            backgroundColor: .white,
            size: geometry.viewBox.size
        )

        XCTAssertGreaterThan(export.alpha(at: interior), 240)
        XCTAssertGreaterThan(export.alpha(at: CGPoint(x: region.bounds.minX, y: region.bounds.minY)), 240)
    }

    func test_watercolorMarkerAndCrayonStayInsideFirstTouchedRegion() throws {
        try assertCleanStrokeContained(tool: .watercolor)
        try assertCleanStrokeContained(tool: .marker)
        try assertCleanStrokeContained(tool: .crayon)
    }

    func test_cleanModeStrokeStartingOutsideFillableRegionIsRejected() {
        let patch = engine.renderCleanStroke(
            tool: .marker,
            colorHex: "#00FF00",
            points: [CanvasTestFixture.pointOutsideAllRegions, CGPoint(x: 80, y: 80)],
            size: 18,
            opacity: 1
        )
        XCTAssertNil(patch)
    }

    func test_cleanModeEraserStartingOutsideCanvasErasesAfterEnteringRegion() {
        _ = engine.fill(regionID: "clip-region-a", colorHex: "#FF0000")
        let interior = CGPoint(x: 80, y: 80)

        let patch = engine.renderCleanStroke(
            tool: .eraser,
            colorHex: "#FFFFFF",
            points: [CanvasTestFixture.pointOutsideAllRegions, interior],
            size: 18,
            opacity: 1
        )

        XCTAssertNotNil(patch)
        XCTAssertLessThan(engine.image.alpha(at: interior), 30)
    }

    func test_freeModeAllowsUnrestrictedDrawing() {
        let patch = engine.renderFreeStroke(
            tool: .marker,
            colorHex: "#00FF00",
            points: [CanvasTestFixture.pointOutsideAllRegions, CGPoint(x: 20, y: 20)],
            size: 18,
            opacity: 1
        )
        XCTAssertNotNil(patch)
        XCTAssertGreaterThan(engine.image.alpha(at: CGPoint(x: 10, y: 10)), 0)
    }

    func test_fillRemainsSeparateTool() {
        XCTAssertEqual(ToolType.fillBucket.systemImageName, "drop.fill")
    }

    func test_undoAndRedoRestoreErasedTapFillPixels() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        _ = engine.fill(regionID: region.id, colorHex: "#FF0000")
        let erasePatch = try XCTUnwrap(engine.renderCleanStroke(tool: .eraser, colorHex: "#FFFFFF", points: [interior, CGPoint(x: interior.x + 5, y: interior.y)], size: 20, opacity: 1))

        XCTAssertLessThan(engine.image.alpha(at: interior), 40)
        engine.restore(erasePatch.before)
        XCTAssertGreaterThan(engine.image.alpha(at: interior), 200)
        engine.restore(erasePatch.after)
        XCTAssertLessThan(engine.image.alpha(at: interior), 40)
    }

    func test_saveReopenAndExportPreservePartiallyErasedFill() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        _ = engine.fill(regionID: region.id, colorHex: "#FF0000")
        _ = engine.renderCleanStroke(tool: .eraser, colorHex: "#FFFFFF", points: [interior, CGPoint(x: interior.x + 5, y: interior.y)], size: 20, opacity: 1)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pigment-\(UUID().uuidString).png")
        engine.bitmap.savePNG(to: url)
        let reopened = RegionPigmentEngine(geometry: geometry, existingImage: UIImage(contentsOfFile: url.path))
        XCTAssertEqual(reopened.image.pngData(), engine.image.pngData())
        XCTAssertLessThan(reopened.image.alpha(at: interior), 40)

        let export = CanvasSnapshotRenderer().render(
            lineArtImage: TemplateRenderer.renderLineArt(geometry: geometry, size: geometry.viewBox.size),
            pigmentLayer: reopened.image,
            backgroundColor: .white,
            size: geometry.viewBox.size
        )
        XCTAssertGreaterThan(export.alpha(at: interior), 240)
    }

    func test_exportUsesCanonicalPigmentBitmapWithErasedFillStripe() throws {
        let region = try XCTUnwrap(geometry.regions.first)
        let erased = CanvasTestFixture.interiorPoint(of: region)
        let colored = CGPoint(x: region.bounds.minX + 8, y: region.bounds.minY + 8)

        _ = engine.fill(regionID: region.id, colorHex: "#00AAFF")
        _ = engine.renderCleanStroke(tool: .eraser, colorHex: "#000000", points: [erased, CGPoint(x: erased.x + 12, y: erased.y)], size: 18, opacity: 1)

        let lineArt = makeLineArtImage(size: geometry.viewBox.size)
        let export = CanvasSnapshotRenderer().render(
            lineArtImage: lineArt,
            pigmentLayer: engine.image,
            backgroundColor: .white,
            size: geometry.viewBox.size
        )

        let erasedPixel = try XCTUnwrap(export.rgba(at: erased))
        let coloredPixel = try XCTUnwrap(export.rgba(at: colored))
        let linePixel = try XCTUnwrap(export.rgba(at: CGPoint(x: 10, y: 10)))

        XCTAssertGreaterThan(erasedPixel.r, 245)
        XCTAssertGreaterThan(erasedPixel.g, 245)
        XCTAssertGreaterThan(erasedPixel.b, 245)
        XCTAssertGreaterThan(coloredPixel.b, 180)
        XCTAssertLessThan(linePixel.r, 20)
        XCTAssertLessThan(linePixel.g, 20)
        XCTAssertLessThan(linePixel.b, 20)
    }

    func test_paletteAndToolPickerChangeInstantly() throws {
        let template = try CanvasTestFixture.makeTemplate()
        let viewModel = ColoringSessionViewModel(project: Project(template: template), template: template)
        viewModel.selectTool(.marker)
        XCTAssertEqual(viewModel.selectedTool, .marker)
        viewModel.selectColor(hex: "#123456")
        XCTAssertEqual(viewModel.selectedColorHex, "#123456")
    }

    private func assertCleanStrokeContained(tool: ToolType) throws {
        engine = RegionPigmentEngine(geometry: geometry)
        let regionA = try XCTUnwrap(geometry.regions.first)
        let regionB = try XCTUnwrap(geometry.regions.dropFirst().first)
        let start = CanvasTestFixture.interiorPoint(of: regionA)
        let end = CanvasTestFixture.interiorPoint(of: regionB)

        let patch = engine.renderCleanStroke(tool: tool, colorHex: "#00FF00", points: [start, end], size: 18, opacity: 1)
        XCTAssertNotNil(patch)
        XCTAssertGreaterThan(engine.image.alpha(at: start), 0)
        XCTAssertEqual(engine.image.alpha(at: end), 0)
    }

    private func makeLineArtImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cgContext = context.cgContext
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(3)
            cgContext.move(to: CGPoint(x: 10, y: 0))
            cgContext.addLine(to: CGPoint(x: 10, y: size.height))
            cgContext.strokePath()
        }
    }

    private func documentToBitmapTransform(for engine: RegionPigmentEngine) -> CGAffineTransform {
        TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: engine.bitmap.size
        )
    }
}

private extension UIImage {
    func rgba(at point: CGPoint) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard point.x >= 0, point.y >= 0, point.x < size.width, point.y < size.height else {
            return nil
        }
        guard let cgImage else { return nil }
        let x = min(max(Int(point.x), 0), cgImage.width - 1)
        let y = min(max(Int(point.y), 0), cgImage.height - 1)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: -x, y: y - cgImage.height + 1, width: cgImage.width, height: cgImage.height))
        return (pixel[0], pixel[1], pixel[2], pixel[3])
    }

    func alpha(at point: CGPoint) -> UInt8 {
        guard point.x >= 0, point.y >= 0, point.x < size.width, point.y < size.height else {
            return 0
        }
        guard let cgImage else { return 0 }
        let x = min(max(Int(point.x), 0), cgImage.width - 1)
        let y = min(max(Int(point.y), 0), cgImage.height - 1)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: -x, y: y - cgImage.height + 1, width: cgImage.width, height: cgImage.height))
        return pixel[3]
    }
}
