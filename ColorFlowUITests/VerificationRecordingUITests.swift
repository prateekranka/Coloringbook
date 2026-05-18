import XCTest

final class VerificationRecordingUITests: XCTestCase {
    private var app: XCUIApplication!
    private var recordingConfig: RecordingConfig!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        let config = RecordingConfig.load()
        try XCTSkipUnless(
            config.isEnabled,
            "Verification recording tests run only through Scripts/record_verification_matrix.sh"
        )
        recordingConfig = config
        XCUIDevice.shared.orientation = requestedOrientation
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func test_recordCanvasFastColoring() throws {
        launchSeededApp()
        openTemplate(slug: "wildflowers")

        let canvas = requireCanvas()
        dismissGestureTipIfNeeded()
        selectTool("canvas.tool.fill-bucket")
        rapidRegionTaps(on: canvas)
        canvas.tap(withNumberOfTaps: 1, numberOfTouches: 2)
        Thread.sleep(forTimeInterval: 0.4)
        canvas.tap(withNumberOfTaps: 1, numberOfTouches: 3)
        chooseColor(identifier: "canvas.color.2bbcb3")
        selectTool("canvas.tool.crayon")
        rapidCleanStrokes(on: canvas)
        Thread.sleep(forTimeInterval: 2.0)
    }

    func test_recordCanvasZoomStress() throws {
        launchSeededApp(openTemplateSlug: "wildflowers")
        exerciseZoomAndFit(compact: true)

        relaunchSeededApp(openTemplateSlug: "lemon-balcony")
        exerciseZoomAndFit(compact: true)
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_recordHighResolutionTemplateZoom() throws {
        launchSeededApp(openTemplateSlug: "lemon-branch")
        exerciseZoomAndFit(compact: true)

        relaunchSeededApp(openTemplateSlug: "lemon-balcony")
        exerciseZoomAndFit(compact: true)
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_recordFocusMode() throws {
        launchSeededApp(openTemplateSlug: "wildflowers")

        let canvas = requireCanvas()
        dismissGestureTipIfNeeded()
        app.buttons["canvas.more"].tap()
        XCTAssertTrue(app.buttons["Focus Mode"].waitForExistence(timeout: 2))
        app.buttons["Focus Mode"].tap()
        XCTAssertTrue(app.buttons["canvas.showControls"].waitForExistence(timeout: 2))
        rapidCleanStrokes(on: canvas)
        app.buttons["canvas.showControls"].tap()
        XCTAssertTrue(app.buttons["canvas.tools"].waitForExistence(timeout: 2))
        app.buttons["canvas.tools"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["canvas.settings.sheet"].waitForExistence(timeout: 2))
        Thread.sleep(forTimeInterval: 0.8)
    }

    func test_recordHomeFlow() throws {
        launchSeededApp()

        XCTAssertTrue(app.staticTexts["Gouache"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.5)
        if app.buttons["home.collection.fresh-botanicals"].waitForExistence(timeout: 1) {
            app.buttons["home.collection.fresh-botanicals"].swipeLeft()
        }
        app.swipeUp()
        Thread.sleep(forTimeInterval: 4.8)
    }

    func test_recordLibraryMasonry() throws {
        launchSeededApp()

        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        for _ in 0..<5 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.8)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        Thread.sleep(forTimeInterval: 4.0)
    }

    func test_recordProfileAndTheme() throws {
        launchSeededApp()

        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        tapThemeSegment("System")
        tapThemeSegment("Light")
        tapThemeSegment("Dark")
        tapThemeSegment(requestedTheme.capitalized)
        Thread.sleep(forTimeInterval: 0.8)

        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.staticTexts["Gouache"].waitForExistence(timeout: 3))
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 3))
        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["About Gouache"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 4.5)
    }

    private var requestedTheme: String {
        recordingConfig.theme
    }

    private var requestedOrientation: UIDeviceOrientation {
        recordingConfig.orientation == "landscape" ? .landscapeLeft : .portrait
    }

    private func launchSeededApp(openTemplateSlug: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = [
            "-resetSableProjects",
            "-sableUITestSeed",
            "-disableAnimations",
            "-disableTemplateThumbnailRendering",
            "-gouacheTheme",
            requestedTheme
        ]
        if let openTemplateSlug {
            app.launchArguments += ["-gouacheOpenTemplate", openTemplateSlug]
        }
        app.launch()
    }

    private func relaunchSeededApp(openTemplateSlug: String? = nil) {
        app.terminate()
        launchSeededApp(openTemplateSlug: openTemplateSlug)
    }

    private func requireCanvas() -> XCUIElement {
        let canvas = app.descendants(matching: .any)["canvas.surface"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 6))
        return canvas
    }

    private func dismissGestureTipIfNeeded() {
        let tip = app.descendants(matching: .any)["canvas.gestureTip"]
        if tip.waitForExistence(timeout: 1), tip.isHittable {
            tip.tap()
        }
    }

    private func openTemplate(slug: String, alreadyInLibrary: Bool = false) {
        if !alreadyInLibrary {
            app.buttons["tab.library"].tap()
            XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))
        }

        let button = app.buttons["template.\(slug)"]
        if tapIfVisible(button) { return }

        for _ in 0..<8 {
            app.swipeUp()
            if tapIfVisible(button) { return }
        }

        for _ in 0..<8 {
            app.swipeDown()
            if tapIfVisible(button) { return }
        }

        XCTFail("Could not open template.\(slug)")
    }

    private func tapIfVisible(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 0.6), element.isHittable else { return false }
        let tapY = element.frame.midY
        guard tapY > app.frame.minY + 78, tapY < app.frame.maxY - 150 else { return false }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        return true
    }

    private func closeCanvas() {
        let libraryTitle = app.staticTexts["Library"]
        for _ in 0..<3 {
            if app.buttons["canvas.back"].waitForExistence(timeout: 1), app.buttons["canvas.back"].isHittable {
                app.buttons["canvas.back"].tap()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.035, dy: 0.075)).tap()
            }

            if libraryTitle.waitForExistence(timeout: 2) {
                return
            }

            if app.buttons["tab.library"].waitForExistence(timeout: 1), app.buttons["tab.library"].isHittable {
                app.buttons["tab.library"].tap()
                if libraryTitle.waitForExistence(timeout: 2) {
                    return
                }
            }
        }
        XCTAssertTrue(libraryTitle.exists)
    }

    private func selectTool(_ identifier: String) {
        app.buttons["canvas.tools"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["canvas.settings.sheet"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 2))
        app.buttons[identifier].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["canvas.tools"].waitForExistence(timeout: 2))
    }

    private func chooseColor(identifier: String) {
        app.buttons["canvas.color.compact"].tap()
        let colorButton = app.buttons[identifier]
        XCTAssertTrue(colorButton.waitForExistence(timeout: 2))
        colorButton.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22)).tap()
        XCTAssertTrue(app.buttons["canvas.tools"].waitForExistence(timeout: 2))
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func rapidRegionTaps(on canvas: XCUIElement, limit: Int? = nil) {
        let allPoints = [
            CGVector(dx: 0.50, dy: 0.50),
            CGVector(dx: 0.42, dy: 0.42),
            CGVector(dx: 0.58, dy: 0.42),
            CGVector(dx: 0.42, dy: 0.60),
            CGVector(dx: 0.60, dy: 0.58),
            CGVector(dx: 0.35, dy: 0.52),
            CGVector(dx: 0.65, dy: 0.50),
            CGVector(dx: 0.50, dy: 0.35)
        ]

        let points = limit.map { Array(allPoints.prefix($0)) } ?? allPoints
        for point in points {
            canvas.coordinate(withNormalizedOffset: point).tap()
            Thread.sleep(forTimeInterval: 0.08)
        }
    }

    private func rapidCleanStrokes(on canvas: XCUIElement) {
        let strokes: [(CGVector, CGVector)] = [
            (CGVector(dx: 0.30, dy: 0.34), CGVector(dx: 0.72, dy: 0.42)),
            (CGVector(dx: 0.36, dy: 0.54), CGVector(dx: 0.70, dy: 0.62)),
            (CGVector(dx: 0.44, dy: 0.72), CGVector(dx: 0.64, dy: 0.30)),
            (CGVector(dx: 0.26, dy: 0.48), CGVector(dx: 0.74, dy: 0.56))
        ]

        for stroke in strokes {
            let start = canvas.coordinate(withNormalizedOffset: stroke.0)
            let end = canvas.coordinate(withNormalizedOffset: stroke.1)
            start.press(forDuration: 0.03, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.08)
        }
    }

    private func exerciseZoomAndFit(compact: Bool = false) {
        let canvas = requireCanvas()
        dismissGestureTipIfNeeded()
        selectTool("canvas.tool.fill-bucket")
        Thread.sleep(forTimeInterval: compact ? 0.2 : 0.4)
        canvas.pinch(withScale: 2.7, velocity: 1.4)
        Thread.sleep(forTimeInterval: compact ? 0.2 : 0.4)
        rapidRegionTaps(on: canvas, limit: compact ? 3 : nil)
        canvas.swipeLeft()
        Thread.sleep(forTimeInterval: compact ? 0.15 : 0.3)
        canvas.swipeRight()
        Thread.sleep(forTimeInterval: compact ? 0.15 : 0.3)
        app.buttons["canvas.more"].tap()
        XCTAssertTrue(app.buttons["Fit Artwork"].waitForExistence(timeout: 2))
        app.buttons["Fit Artwork"].tap()
        Thread.sleep(forTimeInterval: compact ? 0.5 : 1.0)
    }

    private func tapThemeSegment(_ title: String) {
        let segment = app.buttons[title]
        if segment.waitForExistence(timeout: 1), segment.isHittable {
            segment.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}

private struct RecordingConfig {
    var isEnabled = false
    var theme = "light"
    var orientation = "portrait"

    static func load() -> RecordingConfig {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".gouache-recording-config")
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return RecordingConfig()
        }

        var config = RecordingConfig(isEnabled: true)
        for line in contents.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "theme":
                config.theme = parts[1]
            case "orientation":
                config.orientation = parts[1]
            default:
                continue
            }
        }
        return config
    }
}
