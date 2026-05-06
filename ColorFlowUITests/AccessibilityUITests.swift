import XCTest

final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSableProjects", "-sableUITestSeed"]
        app.launch()
        return app
    }

    private func canvasSurface(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["canvas.surface"]
    }

    func test_customTabBar_itemsAreReachable() throws {
        let app = launchSeededApp()

        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tab.explore"].exists)
        XCTAssertTrue(app.buttons["tab.library"].exists)
    }

    func test_home_sectionsAndRealCards_areReachable() throws {
        let app = launchSeededApp()

        XCTAssertTrue(app.staticTexts["CONTINUE"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.continue.sunflower-mandala"].exists)
        XCTAssertTrue(app.buttons["home.collection.koi-serenity"].exists)
        XCTAssertTrue(app.buttons["home.mood.calm"].exists)
    }

    func test_exploreAndLibraryTabs_showRealSurfaces() throws {
        let app = launchSeededApp()

        app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.staticTexts["Explore"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["template.sunflower-mandala"].waitForExistence(timeout: 3))

        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["My Library"].waitForExistence(timeout: 2))
    }

    func test_myLibrary_showsSavedProjectAndOpensCanvas() throws {
        let app = launchSeededApp()

        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["My Library"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(identifier: "library.savedCount").firstMatch.exists)

        let savedProject = app.buttons["library.project.sunflower-mandala"]
        XCTAssertTrue(savedProject.waitForExistence(timeout: 3))
        savedProject.tap()

        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sunflower Mandala"].exists)
    }

    func test_continueCard_opensSavedColoringCanvas() throws {
        let app = launchSeededApp()

        app.buttons["home.continue.sunflower-mandala"].tap()

        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sunflower Mandala"].exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "canvas.progress").firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "canvas.zoom").firstMatch.exists)
        XCTAssertTrue(app.buttons["canvas.resetView"].exists)
        XCTAssertTrue(app.buttons["canvas.save"].exists)
    }

    func test_canvasViewport_allowsPinchPanAndReset() throws {
        let app = launchSeededApp()

        app.buttons["home.continue.sunflower-mandala"].tap()
        let canvas = canvasSurface(in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        canvas.pinch(withScale: 1.8, velocity: 1.0)
        canvas.swipeLeft()
        app.buttons["canvas.resetView"].tap()

        XCTAssertTrue(canvas.exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "canvas.zoom").firstMatch.exists)
    }

    func test_collectionTemplate_opensCanvas() throws {
        let app = launchSeededApp()

        app.buttons["home.collection.botanical-bold"].tap()
        XCTAssertTrue(app.staticTexts["Botanical Bold"].waitForExistence(timeout: 3))

        app.buttons["template.rose-bouquet"].tap()
        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rose Bouquet"].exists)
    }

    func test_moodTemplate_opensCanvas() throws {
        let app = launchSeededApp()

        app.buttons["home.mood.calm"].tap()
        XCTAssertTrue(app.staticTexts["CALM"].waitForExistence(timeout: 3))

        app.buttons["template.lotus-mandala"].tap()
        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Lotus Mandala"].exists)
    }

    func test_browseFillSaveReturnAndReopenRestoresProgress() throws {
        let app = launchSeededApp()

        app.buttons["home.collection.botanical-bold"].tap()
        XCTAssertTrue(app.staticTexts["Botanical Bold"].waitForExistence(timeout: 3))

        app.buttons["template.rose-bouquet"].tap()
        let canvas = canvasSurface(in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        app.buttons["canvas.color.ff2d78"].tap()
        tapCanvasUntilProgressChanges(canvas: canvas, app: app)
        let savedProgress = progressLabel(in: app)
        XCTAssertNotEqual(savedProgress, "0%")

        canvas.pinch(withScale: 1.5, velocity: 1.0)
        canvas.swipeLeft()
        app.buttons["canvas.resetView"].tap()
        app.buttons["canvas.save"].tap()

        tapBack(in: app)
        tapBack(in: app)

        let continueCard = app.buttons["home.continue.rose-bouquet"]
        XCTAssertTrue(continueCard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.continue.rose-bouquet.thumbnail"].exists)

        continueCard.tap()
        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(progressLabel(in: app), savedProgress)
    }

    private func tapCanvasUntilProgressChanges(canvas: XCUIElement, app: XCUIApplication) {
        let offsets: [CGVector] = [
            CGVector(dx: 0.5, dy: 0.5),
            CGVector(dx: 0.42, dy: 0.42),
            CGVector(dx: 0.58, dy: 0.42),
            CGVector(dx: 0.42, dy: 0.58),
            CGVector(dx: 0.58, dy: 0.58),
            CGVector(dx: 0.35, dy: 0.5),
            CGVector(dx: 0.65, dy: 0.5)
        ]

        for offset in offsets {
            canvas.coordinate(withNormalizedOffset: offset).tap()
            if waitForProgressChange(in: app) {
                return
            }
        }

        XCTFail("Expected at least one canvas tap to fill a region.")
    }

    private func progressLabel(in app: XCUIApplication) -> String {
        app.staticTexts.matching(identifier: "canvas.progress").firstMatch.label
    }

    private func waitForProgressChange(in app: XCUIApplication) -> Bool {
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            if progressLabel(in: app) != "0%" {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func tapBack(in app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
    }
}
