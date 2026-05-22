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
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 5)
        app.launch()
        if !app.wait(for: .runningForeground, timeout: 10) {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
            Thread.sleep(forTimeInterval: 1)
            app.launch()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(scrollTemplateIntoView(slug: "wildflowers", in: app))

        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["My Work"].exists)
    }

    func test_profile_showsSavedProjectAndOpensCanvas() throws {
        let app = launchSeededApp()

        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 2))

        tapProfileProject(slug: "wildflowers", in: app)

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

        tapHomeButton("home.mood.calm", in: app)
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

        if scrollTemplateIntoView(slug: slug, in: app),
           tapTemplateButtonIfVisible(button, in: app) {
            return
        }

        XCTFail("Expected template.\(slug) to be reachable.")
    }

    private func scrollTemplateIntoView(slug: String, in app: XCUIApplication) -> Bool {
        let button = app.buttons["template.\(slug)"]
        if button.waitForExistence(timeout: 1), tapTemplateButtonIfVisible(button, in: app, shouldTap: false) {
            return true
        }

        for _ in 0..<8 {
            app.swipeUp()
            if button.waitForExistence(timeout: 0.6),
               tapTemplateButtonIfVisible(button, in: app, shouldTap: false) {
                return true
            }
        }

        for _ in 0..<8 {
            app.swipeDown()
            if button.waitForExistence(timeout: 0.6),
               tapTemplateButtonIfVisible(button, in: app, shouldTap: false) {
                return true
            }
        }

        return false
    }

    private func tapTemplateButtonIfVisible(_ button: XCUIElement, in app: XCUIApplication, shouldTap: Bool = true) -> Bool {
        guard button.isHittable else { return false }
        let tabBarClearance: CGFloat = 170
        let headerClearance: CGFloat = 80
        let tapOffset = CGVector(dx: 0.5, dy: 0.22)
        let tapY = button.frame.minY + button.frame.height * tapOffset.dy
        guard tapY > app.frame.minY + headerClearance,
              tapY < app.frame.maxY - tabBarClearance else {
            return false
        }

        if shouldTap {
            button.coordinate(withNormalizedOffset: tapOffset).tap()
        }
        return true
    }

    private func tapProfileProject(slug: String, in app: XCUIApplication) {
        let button = app.buttons["profile.project.\(slug)"]
        if button.waitForExistence(timeout: 1), button.isHittable {
            button.tap()
            return
        }

        for _ in 0..<6 {
            app.swipeUp()
            if button.waitForExistence(timeout: 0.6), button.isHittable {
                button.tap()
                return
            }
        }

        XCTFail("Expected profile.project.\(slug) to be reachable.")
    }

    private func tapHomeButton(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
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
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        let menu = app.buttons["canvas.more"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        if menu.isHittable {
            menu.tap()
        } else {
            menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
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
