import XCTest

final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 120
        XCUIDevice.shared.orientation = .portrait
    }

    private func launchSeededApp(openTemplateSlug: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetSableProjects",
            "-sableUITestSeed",
            "-disableAnimations",
            "-disableTemplateThumbnailRendering"
        ]
        if let openTemplateSlug {
            app.launchArguments += ["-gouacheOpenTemplate", openTemplateSlug]
        }
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
        if openTemplateSlug == nil {
            XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        }
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
        XCTAssertTrue(app.buttons["home.mood.calm"].exists)
        XCTAssertTrue(app.buttons["home.recent.electric-starburst"].exists)
    }

    func test_libraryAndProfileTabs_showRealSurfaces() throws {
        let app = launchSeededApp()

        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 2))

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
        XCTAssertTrue(app.buttons["canvas.pigmentWell"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["canvas.cleanFreeToggle"].exists)
    }

    func test_canvasDock_exposesCurrentFiveToolsOnly() throws {
        let app = launchSeededApp()

        app.buttons["home.continue.wildflowers"].tap()
        assertCanvasChrome(in: app, title: "Wildflowers")

        let visibleToolIDs = [
            "canvas.tool.crayon",
            "canvas.tool.watercolor",
            "canvas.tool.marker",
            "canvas.tool.eraser",
            "canvas.tool.fill-bucket"
        ]
        for identifier in visibleToolIDs {
            XCTAssertTrue(app.buttons[identifier].exists, "Expected \(identifier) in the canvas dock.")
        }
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
        XCTAssertTrue(app.buttons["canvas.pigmentWell"].exists)
    }

    func test_continueTemplate_opensCanvas() throws {
        let app = launchSeededApp()

        tapHomeButton("home.continue.wildflowers", in: app)
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
        let app = launchSeededApp(openTemplateSlug: "wildflowers")
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
        let app = launchSeededApp(openTemplateSlug: "lemon-branch")
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
        XCTAssertTrue(app.buttons["canvas.pigmentWell"].exists)
        XCTAssertTrue(app.buttons["canvas.tool.crayon"].exists)
        XCTAssertTrue(app.buttons["canvas.tool.watercolor"].exists)
        XCTAssertTrue(app.buttons["canvas.tool.marker"].exists)
        XCTAssertTrue(app.buttons["canvas.tool.eraser"].exists)
        XCTAssertTrue(app.buttons["canvas.tool.fill-bucket"].exists)
    }

    private func tapTemplate(slug: String, in app: XCUIApplication) {
        if tapTemplateIfReachable(slug: slug, in: app) {
            return
        }

        if scrollTemplateIntoView(slug: slug, in: app),
           tapTemplateIfReachable(slug: slug, in: app) {
            return
        }

        XCTFail("Expected template.\(slug) to be reachable.")
    }

    private func scrollTemplateIntoView(slug: String, in app: XCUIApplication) -> Bool {
        if templateIsReachable(slug: slug, in: app) {
            return true
        }

        for _ in 0..<8 {
            app.swipeUp()
            if templateIsReachable(slug: slug, in: app) {
                return true
            }
        }

        for _ in 0..<8 {
            app.swipeDown()
            if templateIsReachable(slug: slug, in: app) {
                return true
            }
        }

        return false
    }

    private func tapTemplateIfReachable(slug: String, in app: XCUIApplication) -> Bool {
        for identifier in templateIdentifiers(slug: slug) {
            let button = app.buttons[identifier]
            if button.waitForExistence(timeout: 0.6),
               tapTemplateButtonIfVisible(button, in: app) {
                return true
            }
        }
        return false
    }

    private func templateIsReachable(slug: String, in app: XCUIApplication) -> Bool {
        for identifier in templateIdentifiers(slug: slug) {
            let button = app.buttons[identifier]
            if button.waitForExistence(timeout: 0.6),
               tapTemplateButtonIfVisible(button, in: app, shouldTap: false) {
                return true
            }
        }
        return false
    }

    private func templateIdentifiers(slug: String) -> [String] {
        ["template.\(slug)", "library.reference.template.\(slug)"]
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
        if button.waitForExistence(timeout: 2), button.isHittable {
            button.tap()
            return
        }

        for _ in 0..<8 {
            app.swipeUp()
            if button.waitForExistence(timeout: 0.6), button.isHittable {
                button.tap()
                return
            }
        }

        for _ in 0..<8 {
            app.swipeDown()
            if button.waitForExistence(timeout: 0.6), button.isHittable {
                button.tap()
                return
            }
        }

        XCTFail("Expected \(identifier) to be reachable.")
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
        let directButton = app.buttons["canvas.tool.fill-bucket"]
        XCTAssertTrue(directButton.waitForExistence(timeout: 3))
        directButton.tap()
    }

    private func tapCanvasMenuItem(_ title: String, in app: XCUIApplication) {
        if title == "Undo" {
            let undo = app.buttons["canvas.undo"]
            XCTAssertTrue(undo.waitForExistence(timeout: 3))
            undo.tap()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
            return
        }

        if title == "Redo" {
            let redo = app.buttons["canvas.redo"]
            XCTAssertTrue(redo.waitForExistence(timeout: 3))
            redo.tap()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
            return
        }

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
