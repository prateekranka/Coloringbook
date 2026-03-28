import XCTest
import SwiftUI
import PencilKit
@testable import ColorFlow

@MainActor
final class CanvasViewModelTests: XCTestCase {

    // MARK: - Subject Under Test

    var sut: CanvasViewModel!
    var template: Template!
    var project: Project!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        template = TestHelpers.makeTemplate()
        project = TestHelpers.makeProject(template: template)
        sut = CanvasViewModel(project: project, template: template)
    }

    override func tearDown() async throws {
        sut = nil
        template = nil
        project = nil
        try await super.tearDown()
    }

    // MARK: - Initialisation

    func test_init_setsProjectAndTemplate() {
        XCTAssertEqual(sut.project.id, project.id)
        XCTAssertEqual(sut.template.id, template.id)
    }

    func test_init_defaultBrushSettings() {
        XCTAssertEqual(sut.brushSettings.tool, .pencil)
        XCTAssertEqual(sut.brushSettings.size, 8.0, accuracy: 0.001)
        XCTAssertEqual(sut.brushSettings.opacity, 1.0, accuracy: 0.001)
        // Color.black resolves to UIColor.black
        XCTAssertEqual(UIColor(sut.brushSettings.color), UIColor.black)
    }

    // MARK: - completionPercentage

    func test_completionPercentage_noGeometry_staysZero() {
        // templateGeometry is nil until loadTemplate() succeeds, so completion
        // stays at its initial value of 0.
        XCTAssertEqual(sut.completionPercentage, 0.0, accuracy: 0.001)
    }

    // MARK: - Undo / Redo

    func test_undo_emptyStack_doesNotCrash() {
        // Both fill undo stack and PencilKit stack are empty; must not throw.
        XCTAssertNoThrow(sut.undo())
    }

    func test_redo_emptyStack_doesNotCrash() {
        XCTAssertNoThrow(sut.redo())
    }

    // MARK: - Fit to Screen

    func test_fitToScreen_togglesTrigger() {
        let initial = sut.fitToScreenTrigger
        sut.fitToScreen()
        XCTAssertEqual(sut.fitToScreenTrigger, !initial)
    }

    func test_fitToScreen_togglesTriggerTwice_returnsToInitial() {
        let initial = sut.fitToScreenTrigger
        sut.fitToScreen()
        sut.fitToScreen()
        XCTAssertEqual(sut.fitToScreenTrigger, initial)
    }

    // MARK: - Recent Colors

    func test_addRecentColor_addsToFront() {
        let red = Color.red
        let blue = Color.blue
        sut.addRecentColor(red)
        sut.addRecentColor(blue)
        XCTAssertEqual(sut.recentColors.first, blue,
                       "Most recently added color should be at index 0")
    }

    func test_addRecentColor_maxTwelve() {
        // Add 13 distinct colours; the list must not exceed 12.
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .mint, .teal,
            .cyan, .blue, .indigo, .purple, .pink, .brown, .gray
        ]
        for color in colors {
            sut.addRecentColor(color)
        }
        XCTAssertLessThanOrEqual(sut.recentColors.count, 12,
                                 "recentColors must be capped at 12")
    }

    func test_addRecentColor_deduplicates() {
        let red = Color.red
        sut.addRecentColor(red)
        sut.addRecentColor(Color.blue)
        sut.addRecentColor(red)   // re-add red — it should move to front, not duplicate

        let redCount = sut.recentColors.filter { $0 == red }.count
        XCTAssertEqual(redCount, 1, "Duplicate colors should not appear more than once")
        XCTAssertEqual(sut.recentColors.first, red,
                       "Re-added color should move to the front")
    }

    // MARK: - Favorite Colors

    func test_toggleFavoriteColor_addsIfAbsent() {
        let green = Color.green
        XCTAssertFalse(sut.favoriteColors.contains(green))
        sut.toggleFavoriteColor(green)
        XCTAssertTrue(sut.favoriteColors.contains(green))
    }

    func test_toggleFavoriteColor_removesIfPresent() {
        let green = Color.green
        sut.toggleFavoriteColor(green)   // add
        XCTAssertTrue(sut.favoriteColors.contains(green))
        sut.toggleFavoriteColor(green)   // remove
        XCTAssertFalse(sut.favoriteColors.contains(green))
    }

    func test_toggleFavoriteColor_addsToFront() {
        sut.toggleFavoriteColor(Color.red)
        sut.toggleFavoriteColor(Color.blue)
        XCTAssertEqual(sut.favoriteColors.first, Color.blue,
                       "Most recently toggled-on color should appear at index 0")
    }

    // MARK: - currentPKTool

    func test_currentPKTool_pencil_returnsPKInkingTool() {
        sut.brushSettings.tool = .pencil
        let tool = sut.currentPKTool
        XCTAssertTrue(tool is PKInkingTool,
                      "Pencil tool should produce a PKInkingTool")
        if let inkingTool = tool as? PKInkingTool {
            XCTAssertEqual(inkingTool.inkType, .pencil)
        }
    }

    func test_currentPKTool_eraser_returnsPKEraserTool() {
        sut.brushSettings.tool = .eraser
        let tool = sut.currentPKTool
        XCTAssertTrue(tool is PKEraserTool,
                      "Eraser tool should produce a PKEraserTool")
    }

    func test_currentPKTool_marker_returnsPKInkingTool() {
        sut.brushSettings.tool = .marker
        let tool = sut.currentPKTool
        XCTAssertTrue(tool is PKInkingTool)
        if let inkingTool = tool as? PKInkingTool {
            XCTAssertEqual(inkingTool.inkType, .marker)
        }
    }

    // MARK: - showLineArt / effectiveTemplateImage

    func test_showLineArt_toggle_affectsEffectiveTemplateImage() {
        // Inject a synthetic template image so we can observe the computed property.
        let dummyImage = UIImage()
        sut.templateImage = dummyImage

        sut.showLineArt = true
        XCTAssertNotNil(sut.effectiveTemplateImage,
                        "effectiveTemplateImage should be non-nil when showLineArt is true")

        sut.showLineArt = false
        XCTAssertNil(sut.effectiveTemplateImage,
                     "effectiveTemplateImage should be nil when showLineArt is false")
    }

    // MARK: - loadTemplate (async)

    func test_loadTemplate_nilSvgURL_setsLoadError() async {
        // A template whose svgFilename has no matching bundle resource will
        // resolve to a nil svgURL (or a non-existent path), which must set loadError.
        let badTemplate = TestHelpers.makeTemplate(svgFilename: "nonexistent_file_xyz.svg")
        let badProject  = TestHelpers.makeProject(template: badTemplate)
        let vm = CanvasViewModel(project: badProject, template: badTemplate)

        XCTAssertNil(vm.loadError, "loadError should be nil before loading")

        await vm.loadTemplate()

        XCTAssertNotNil(vm.loadError,
                        "loadError should be set when the SVG file cannot be found")
    }

    func test_loadTemplate_nilSvgURL_doesNotSetTemplateImage() async {
        let badTemplate = TestHelpers.makeTemplate(svgFilename: "nonexistent_file_xyz.svg")
        let badProject  = TestHelpers.makeProject(template: badTemplate)
        let vm = CanvasViewModel(project: badProject, template: badTemplate)

        await vm.loadTemplate()

        XCTAssertNil(vm.templateImage,
                     "templateImage should remain nil when loading fails")
    }

    // MARK: - Initial published-state sanity checks

    func test_init_fitToScreenTrigger_isFalse() {
        XCTAssertFalse(sut.fitToScreenTrigger)
    }

    func test_init_completionPercentage_isZero() {
        XCTAssertEqual(sut.completionPercentage, 0.0, accuracy: 0.001)
    }

    func test_init_showLineArt_isTrue() {
        XCTAssertTrue(sut.showLineArt)
    }

    func test_init_templateImage_isNil() {
        XCTAssertNil(sut.templateImage)
    }

    func test_init_loadError_isNil() {
        XCTAssertNil(sut.loadError)
    }
}
