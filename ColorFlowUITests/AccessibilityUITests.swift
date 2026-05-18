import XCTest

final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 120
        XCUIDevice.shared.orientation = .portrait
    }

    private func launchSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetSableProjects",
            "-sableUITestSeed",
            "-disableAnimations",
            "-disableTemplateThumbnailRendering"
        ]
        app.launch()
        return app
    }

    private func canvasSurface(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["canvas.surface"]
    }

    func test_customTabBar_itemsAreReachable() throws {
        let app = launchSeededApp()

        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tab.library"].exists)
        XCTAssertTrue(app.buttons["tab.profile"].exists)
    }

    func test_home_sectionsAndRealCards_areReachable() throws {
        let app = launchSeededApp()

        XCTAssertTrue(app.staticTexts["Continue Coloring"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.continue.wildflowers"].exists)
        XCTAssertTrue(app.buttons["home.collection.fresh-botanicals"].exists)
        XCTAssertTrue(app.buttons["home.mood.calm"].exists)
    }

    func test_libraryAndProfileTabs_showRealSurfaces() throws {
        let app = launchSeededApp()

        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["template.wildflowers"].waitForExistence(timeout: 3))

        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["My Work"].exists)
    }

    func test_profile_showsSavedProjectAndOpensCanvas() throws {
        let app = launchSeededApp()

        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 2))

        let savedProject = app.buttons["profile.project.wildflowers"]
        XCTAssertTrue(savedProject.waitForExistence(timeout: 3))
        savedProject.tap()

        assertCanvasChrome(in: app, title: "Wildflowers")
    }

    func test_continueCard_opensSavedColoringCanvas() throws {
        let app = launchSeededApp()

        app.buttons["home.continue.wildflowers"].tap()

        assertCanvasChrome(in: app, title: "Wildflowers")
        XCTAssertTrue(app.buttons["canvas.more"].exists)
        XCTAssertTrue(app.buttons["canvas.tools"].exists)
        XCTAssertTrue(app.buttons["canvas.color.compact"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["canvas.cleanFreeToggle"].exists)
    }

    func test_canvasViewport_allowsPinchPanAndReset() throws {
        let app = launchSeededApp()

        app.buttons["home.continue.wildflowers"].tap()
        let canvas = canvasSurface(in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        canvas.pinch(withScale: 1.8, velocity: 1.0)
        canvas.swipeLeft()
        tapCanvasMenuItem("Fit Artwork", in: app)

        XCTAssertTrue(canvas.exists)
        XCTAssertTrue(app.buttons["canvas.tools"].exists)
    }

    func test_collectionTemplate_opensCanvas() throws {
        let app = launchSeededApp()

        app.buttons["home.collection.fresh-botanicals"].tap()
        XCTAssertTrue(app.staticTexts["Fresh Botanicals"].waitForExistence(timeout: 3))

        tapTemplate(slug: "wildflowers", in: app)
        assertCanvasChrome(in: app, title: "Wildflowers")
    }

    func test_moodTemplate_opensCanvas() throws {
        let app = launchSeededApp()

        app.buttons["home.mood.calm"].tap()
        XCTAssertTrue(app.staticTexts["CALM"].waitForExistence(timeout: 3))

        tapTemplate(slug: "wildflowers", in: app)
        assertCanvasChrome(in: app, title: "Wildflowers")
    }

    func test_browseFillSaveReturnAndReopenRestoresProgress() throws {
        let app = launchSeededApp()

        app.buttons["home.collection.fresh-botanicals"].tap()
        XCTAssertTrue(app.staticTexts["Fresh Botanicals"].waitForExistence(timeout: 3))

        tapTemplate(slug: "wildflowers", in: app)
        let canvas = canvasSurface(in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        selectFillBucket(in: app)
        tapCanvasUntilFillFeedback(canvas: canvas, app: app)

        canvas.pinch(withScale: 1.5, velocity: 1.0)
        canvas.swipeLeft()
        tapCanvasMenuItem("Fit Artwork", in: app)
        tapCanvasMenuItem("Save", in: app)

        XCTAssertTrue(canvas.exists)
    }

    func test_canvasFillUndoRedoSaveStateAndClearConfirmation() throws {
        let app = launchSeededApp()

        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 3))

        tapTemplate(slug: "lemon-branch", in: app)
        let canvas = canvasSurface(in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        selectFillBucket(in: app)
        tapCanvasUntilFillFeedback(canvas: canvas, app: app)
        XCTAssertTrue(app.descendants(matching: .any)["canvas.fillFeedback"].waitForExistence(timeout: 1))

        tapCanvasMenuItem("Undo", in: app)
        XCTAssertTrue(canvas.exists)

        tapCanvasMenuItem("Redo", in: app)
        XCTAssertTrue(canvas.exists)

        tapCanvasMenuItem("Save", in: app)
        XCTAssertTrue(canvas.exists)

        tapCanvasMenuItem("Clear Artwork", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        app.alerts.buttons["Clear Artwork"].tap()
        XCTAssertTrue(canvas.exists)
    }

    private func assertCanvasChrome(in app: XCUIApplication, title: String) {
        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertTrue(app.buttons["canvas.more"].exists)
        XCTAssertTrue(app.buttons["canvas.tools"].exists)
        XCTAssertTrue(app.buttons["canvas.color.compact"].exists)
    }

    private func tapTemplate(slug: String, in app: XCUIApplication) {
        let button = app.buttons["template.\(slug)"]
        if button.waitForExistence(timeout: 1), tapTemplateButtonIfVisible(button, in: app) {
            return
        }

        for _ in 0..<8 {
            app.swipeUp()
            if button.waitForExistence(timeout: 0.6), tapTemplateButtonIfVisible(button, in: app) {
                return
            }
        }

        for _ in 0..<8 {
            app.swipeDown()
            if button.waitForExistence(timeout: 0.6), tapTemplateButtonIfVisible(button, in: app) {
                return
            }
        }

        XCTFail("Expected template.\(slug) to be reachable.")
    }

    private func tapTemplateButtonIfVisible(_ button: XCUIElement, in app: XCUIApplication) -> Bool {
        guard button.isHittable else { return false }
        let tabBarClearance: CGFloat = 170
        let headerClearance: CGFloat = 80
        let tapOffset = CGVector(dx: 0.5, dy: 0.22)
        let tapY = button.frame.minY + button.frame.height * tapOffset.dy
        guard tapY > app.frame.minY + headerClearance,
              tapY < app.frame.maxY - tabBarClearance else {
            return false
        }

        button.coordinate(withNormalizedOffset: tapOffset).tap()
        return true
    }

    private func tapCanvasUntilFillFeedback(canvas: XCUIElement, app: XCUIApplication) {
        let offsets: [CGVector] = [
            CGVector(dx: 0.5, dy: 0.5),
            CGVector(dx: 0.42, dy: 0.42),
            CGVector(dx: 0.58, dy: 0.42),
            CGVector(dx: 0.42, dy: 0.58),
            CGVector(dx: 0.58, dy: 0.58),
            CGVector(dx: 0.35, dy: 0.5),
            CGVector(dx: 0.65, dy: 0.5),
            CGVector(dx: 0.5, dy: 0.35),
            CGVector(dx: 0.5, dy: 0.65)
        ]

        for offset in offsets {
            canvas.coordinate(withNormalizedOffset: offset).tap()
            if app.descendants(matching: .any)["canvas.fillFeedback"].waitForExistence(timeout: 0.8) {
                return
            }
        }

        XCTFail("Expected at least one canvas tap to fill a region.")
    }

    private func selectFillBucket(in app: XCUIApplication) {
        app.buttons["canvas.tools"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["canvas.settings.sheet"].waitForExistence(timeout: 2))
        app.buttons["canvas.tool.fill-bucket"].tap()
        app.buttons["Done"].tap()
    }

    private func tapCanvasMenuItem(_ title: String, in app: XCUIApplication) {
        app.buttons["canvas.more"].tap()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 2))
        app.buttons[title].tap()
    }

    private func tapBack(in app: XCUIApplication) {
        let canvasBackButton = app.buttons["canvas.back"]
        if canvasBackButton.waitForExistence(timeout: 1) {
            canvasBackButton.tap()
            return
        }

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
    }
}
