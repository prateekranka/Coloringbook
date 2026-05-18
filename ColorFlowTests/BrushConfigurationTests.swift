import XCTest
@testable import ColorFlow

final class BrushConfigurationTests: XCTestCase {

    func testDefaultInitialization() {
        let config = BrushConfiguration(brushType: .pencil)
        XCTAssertEqual(config.brushType, .pencil)
        XCTAssertEqual(config.size, 1.0)
        XCTAssertEqual(config.opacity, 1.0)
        XCTAssertEqual(config.softness, 0.5)
        XCTAssertEqual(config.noiseIntensity, 0.0)
        XCTAssertEqual(config.pressureResponse, 1.0)
        XCTAssertEqual(config.vertexSpacing, 1.0)
    }

    func testClamping() {
        let config = BrushConfiguration(
            brushType: .marker,
            size: -5.0,
            opacity: 2.0,
            softness: -1.0,
            noiseIntensity: 5.0,
            pressureResponse: 3.0,
            vertexSpacing: 0.1
        )
        XCTAssertEqual(config.size, 0.1)
        XCTAssertEqual(config.opacity, 1.0)
        XCTAssertEqual(config.softness, 0.0)
        XCTAssertEqual(config.noiseIntensity, 1.0)
        XCTAssertEqual(config.pressureResponse, 1.0)
        XCTAssertEqual(config.vertexSpacing, 0.5)
    }

    func testAllBrushTypes() {
        for brushType in BrushType.allCases {
            let config = BrushConfiguration(brushType: brushType)
            XCTAssertEqual(config.brushType, brushType)
        }
    }

    func testSIMDFromHex() {
        let color = BrushConfiguration.simdFromHex("#FF0000")
        XCTAssertEqual(color.x, 1.0)
        XCTAssertEqual(color.y, 0.0)
        XCTAssertEqual(color.z, 0.0)
        XCTAssertEqual(color.w, 1.0)
    }

    func testSIMDFromHexInvalid() {
        let color = BrushConfiguration.simdFromHex("not-a-color")
        XCTAssertEqual(color.x, 0.0)
        XCTAssertEqual(color.y, 0.0)
        XCTAssertEqual(color.z, 0.0)
        XCTAssertEqual(color.w, 1.0)
    }

    func testFromToolTypeCrayon() {
        let settings = ToolSettings(tool: .crayon, size: 18, opacity: 0.78, textureAmount: 0.62)
        let config = BrushConfiguration(from: .crayon, settings: settings, colorHex: "#FF0000")
        XCTAssertEqual(config.brushType, .pencil)
        XCTAssertEqual(config.size, 18)
        XCTAssertEqual(config.opacity, 0.78)
        XCTAssertEqual(config.color.x, 1.0)
    }

    func testFromToolTypeEraser() {
        let settings = ToolSettings(tool: .eraser, size: 30, opacity: 1, textureAmount: 0)
        let config = BrushConfiguration(from: .eraser, settings: settings, colorHex: "#000000")
        XCTAssertEqual(config.brushType, .marker)
        XCTAssertEqual(config.opacity, 1.0)
        XCTAssertEqual(config.noiseIntensity, 0.0)
    }
}
