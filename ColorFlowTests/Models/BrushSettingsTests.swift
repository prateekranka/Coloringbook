import XCTest
import SwiftUI
import PencilKit
@testable import ColorFlow

final class BrushSettingsTests: XCTestCase {

    // MARK: - DrawingTool enum

    func test_drawingTool_allCases_count() {
        XCTAssertEqual(DrawingTool.allCases.count, 6)
    }

    func test_drawingTool_isPencilKitTool_trueForPencilMarkerWatercolorEraser() {
        XCTAssertTrue(DrawingTool.pencil.isPencilKitTool)
        XCTAssertTrue(DrawingTool.marker.isPencilKitTool)
        XCTAssertTrue(DrawingTool.watercolor.isPencilKitTool)
        XCTAssertTrue(DrawingTool.eraser.isPencilKitTool)
    }

    func test_drawingTool_isPencilKitTool_falseForFloodFillEyedropper() {
        XCTAssertFalse(DrawingTool.floodFill.isPencilKitTool)
        XCTAssertFalse(DrawingTool.eyedropper.isPencilKitTool)
    }

    func test_drawingTool_pkTool_pencilReturnsPKInkingTool() {
        let tool = DrawingTool.pencil.pkTool(color: .red, width: 8)
        XCTAssertTrue(tool is PKInkingTool)
    }

    func test_drawingTool_pkTool_eraserReturnsPKEraserTool() {
        let tool = DrawingTool.eraser.pkTool(color: .red, width: 8)
        XCTAssertTrue(tool is PKEraserTool)
    }

    func test_drawingTool_pkTool_floodFillReturnsFallbackPKInkingTool() {
        let tool = DrawingTool.floodFill.pkTool(color: .red, width: 8)
        XCTAssertTrue(tool is PKInkingTool)
        // The fallback uses .clear color
        if let inkTool = tool as? PKInkingTool {
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            inkTool.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            XCTAssertEqual(a, 0, accuracy: 0.01)
        }
    }

    func test_drawingTool_pkTool_eyedropperReturnsFallbackPKInkingTool() {
        let tool = DrawingTool.eyedropper.pkTool(color: .red, width: 8)
        XCTAssertTrue(tool is PKInkingTool)
    }

    func test_drawingTool_pkTool_watercolorReducesOpacity() {
        let inputColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1.0)
        let tool = DrawingTool.watercolor.pkTool(color: inputColor, width: 8)
        XCTAssertTrue(tool is PKInkingTool)
        if let inkTool = tool as? PKInkingTool {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            inkTool.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            XCTAssertEqual(a, 0.4, accuracy: 0.01)
        }
    }

    func test_drawingTool_rawValues() {
        XCTAssertEqual(DrawingTool.pencil.rawValue, "Pencil")
        XCTAssertEqual(DrawingTool.marker.rawValue, "Marker")
        XCTAssertEqual(DrawingTool.watercolor.rawValue, "Soft Brush")
        XCTAssertEqual(DrawingTool.eraser.rawValue, "Eraser")
        XCTAssertEqual(DrawingTool.floodFill.rawValue, "Fill")
        XCTAssertEqual(DrawingTool.eyedropper.rawValue, "Eyedropper")
    }

    func test_drawingTool_systemImageName_notEmpty() {
        for tool in DrawingTool.allCases {
            XCTAssertFalse(tool.systemImageName.isEmpty, "\(tool) has empty systemImageName")
        }
    }

    func test_drawingTool_accessibilityName_notEmpty() {
        for tool in DrawingTool.allCases {
            XCTAssertFalse(tool.accessibilityName.isEmpty, "\(tool) has empty accessibilityName")
        }
    }

    // MARK: - BrushSettings

    func test_brushSettings_defaultValues() {
        let settings = BrushSettings()
        XCTAssertEqual(settings.tool, .pencil)
        XCTAssertEqual(settings.size, 8.0)
        XCTAssertEqual(settings.opacity, 1.0)
        // Default color is .black
        let uiColor = UIColor(settings.color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0, accuracy: 0.01)
        XCTAssertEqual(g, 0, accuracy: 0.01)
        XCTAssertEqual(b, 0, accuracy: 0.01)
    }

    func test_brushSettings_sizeRange() {
        XCTAssertEqual(BrushSettings.sizeRange.lowerBound, 1)
        XCTAssertEqual(BrushSettings.sizeRange.upperBound, 50)
    }
}
