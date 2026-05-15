import XCTest

final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 120
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

        XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.staticTexts.matching(identifier: "canvas.zoom").firstMatch.exists)
        XCTAssertTrue(app.buttons["canvas.undo"].exists)
        XCTAssertTrue(app.buttons["canvas.redo"].exists)
        XCTAssertTrue(app.buttons["canvas.clearArtwork"].exists)
        XCTAssertTrue(app.buttons["canvas.resetView"].exists)
        XCTAssertTrue(app.buttons["canvas.palette.essentials"].exists)
    }

    func test_canvasViewport_allowsPinchPanAndReset() throws {
        let app = launchSeededApp()

        app.buttons["home.continue.wildflowers"].tap()
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

        let initialProgress = progressLabel(in: app)
        app.buttons["canvas.tool.fill-bucket"].tap()
        app.buttons["canvas.color.ff2d78"].tap()
        tapCanvasUntilProgressChanges(canvas: canvas, app: app, initialProgress: initialProgress)
        let savedProgress = progressLabel(in: app)
        XCTAssertNotEqual(savedProgress, initialProgress)

        canvas.pinch(withScale: 1.5, velocity: 1.0)
        canvas.swipeLeft()
        app.buttons["canvas.resetView"].tap()
        app.buttons["canvas.save"].tap()

        tapBack(in: app)
        tapBack(in: app)

        let continueCard = app.buttons["home.continue.wildflowers"]
        XCTAssertTrue(continueCard.waitForExistence(timeout: 5))

        continueCard.tap()
        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(progressLabel(in: app), savedProgress)
    }

    func test_canvasFillUndoRedoSaveStateAndClearConfirmation() throws {
        let app = launchSeededApp()

        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 3))

        tapTemplate(slug: "lemon-branch", in: app)
        let canvas = canvasSurface(in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertEqual(progressLabel(in: app), "0%")
        XCTAssertEqual(saveStateLabel(in: app), "Saved")

        app.buttons["canvas.tool.fill-bucket"].tap()
        app.buttons["canvas.color.ff2d78"].tap()
        tapCanvasUntilProgressChanges(canvas: canvas, app: app, initialProgress: "0%")
        let filledProgress = progressLabel(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["canvas.fillFeedback"].waitForExistence(timeout: 1))
        XCTAssertTrue(waitForAnySaveState(in: app, labels: ["Unsaved changes", "Saved"]))

        app.buttons["canvas.undo"].tap()
        XCTAssertTrue(waitForProgress(in: app, toEqual: "0%"))
        XCTAssertTrue(waitForAnySaveState(in: app, labels: ["Unsaved changes", "Saved"]))

        app.buttons["canvas.redo"].tap()
        XCTAssertTrue(waitForProgress(in: app, toEqual: filledProgress))

        app.buttons["canvas.save"].tap()
        XCTAssertTrue(waitForSaveState(in: app, toEqual: "Saved"))

        app.buttons["canvas.clearArtwork"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        app.alerts.buttons["Clear Artwork"].tap()
        XCTAssertTrue(waitForProgress(in: app, toEqual: "0%"))
        XCTAssertTrue(waitForAnySaveState(in: app, labels: ["Unsaved changes", "Saved"]))
    }

    private func assertCanvasChrome(in app: XCUIApplication, title: String) {
        XCTAssertTrue(canvasSurface(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "canvas.progress").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["canvas.saveState"].exists)
        XCTAssertTrue(app.buttons["canvas.save"].exists)
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

    private func tapCanvasUntilProgressChanges(canvas: XCUIElement, app: XCUIApplication, initialProgress: String) {
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
            if waitForProgressChange(in: app, from: initialProgress) {
                return
            }
        }

        XCTFail("Expected at least one canvas tap to fill a region.")
    }

    private func progressLabel(in app: XCUIApplication) -> String {
        app.staticTexts.matching(identifier: "canvas.progress").firstMatch.label
    }

    private func saveStateLabel(in app: XCUIApplication) -> String {
        app.descendants(matching: .any)["canvas.saveState"].firstMatch.label
    }

    private func waitForProgressChange(in app: XCUIApplication, from initialProgress: String) -> Bool {
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            if progressLabel(in: app) != initialProgress {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func waitForProgress(in app: XCUIApplication, toEqual expected: String) -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if progressLabel(in: app) == expected {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func waitForSaveState(in app: XCUIApplication, toEqual expected: String) -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if saveStateLabel(in: app) == expected {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func waitForAnySaveState(in app: XCUIApplication, labels: Set<String>) -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if labels.contains(saveStateLabel(in: app)) {
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
