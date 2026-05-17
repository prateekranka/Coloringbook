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

    func test_watercolorMarkerAndPencilStayInsideFirstTouchedRegion() throws {
        try assertCleanStrokeContained(tool: .watercolor)
        try assertCleanStrokeContained(tool: .marker)
        try assertCleanStrokeContained(tool: .coloredPencil)
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

    func test_cleanModeEraserStartingOutsideFillableRegionIsRejected() {
        let patch = engine.renderCleanStroke(
            tool: .eraser,
            colorHex: "#FFFFFF",
            points: [CanvasTestFixture.pointOutsideAllRegions, CGPoint(x: 80, y: 80)],
            size: 18,
            opacity: 1
        )
        XCTAssertNil(patch)
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
        XCTAssertLessThan(reopened.image.alpha(at: interior), 40)

        let export = TemplateRenderer.renderExport(
            geometry: geometry,
            fills: [:],
            pigmentLayer: reopened.image,
            pencilImage: nil,
            backgroundColor: .white,
            size: geometry.viewBox.size
        )
        XCTAssertGreaterThan(export.alpha(at: interior), 240)
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
}

private extension UIImage {
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
