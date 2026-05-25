import XCTest

@MainActor
final class ScreenshotUITests: XCTestCase {
    
    private var app: XCUIApplication!
    private var screenshotConfig: ScreenshotConfig!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        screenshotConfig = ScreenshotConfig.load()
        app = XCUIApplication()
        app.launchArguments = ["-screenshotMode"]
        if let theme = ProcessInfo.processInfo.environment["SCREENSHOT_THEME"] ?? screenshotConfig.theme {
            app.launchArguments += ["-gouacheTheme", theme]
        }
    }
    
    func test_captureHome() throws {
        launchForScreenshot()

        let heroText = app.staticTexts["Gouache"]
        XCTAssertTrue(heroText.waitForExistence(timeout: 10))

        sleep(3)
        try recordScreenshot()
    }

    func test_captureCanvas() throws {
        launchForScreenshot()

        XCTAssertTrue(app.buttons["home.collection.fresh-botanicals"].waitForExistence(timeout: 5))
        app.buttons["home.collection.fresh-botanicals"].tap()
        XCTAssertTrue(app.staticTexts["Fresh Botanicals"].waitForExistence(timeout: 5))
        tapTemplate(slug: "wildflowers")
        let canvas = app.descendants(matching: .any)["canvas.surface"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        selectCanvasTool("canvas.tool.fill-bucket")
        addSampleFills(to: canvas)
        sleep(2)
        try recordScreenshot()
    }

    func test_captureLibrary() throws {
        launchForScreenshot()

        XCTAssertTrue(app.buttons["tab.library"].waitForExistence(timeout: 5))
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))
        sleep(2)
        try recordScreenshot()
    }

    func test_captureProfile() throws {
        launchForScreenshot()

        XCTAssertTrue(app.buttons["tab.profile"].waitForExistence(timeout: 5))
        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 5))
        sleep(2)
        try recordScreenshot()
    }

    func test_captureCollection() throws {
        launchForScreenshot()

        XCTAssertTrue(app.buttons["home.collection.fresh-botanicals"].waitForExistence(timeout: 5))
        app.buttons["home.collection.fresh-botanicals"].tap()
        XCTAssertTrue(app.staticTexts["Fresh Botanicals"].waitForExistence(timeout: 5))
        sleep(2)
        try recordScreenshot()
    }

    private func launchForScreenshot() {
        applyRequestedOrientation()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        applyRequestedOrientation()
        waitForRequestedOrientation()
    }

    private func applyRequestedOrientation() {
        if requestedOrientation == .landscapeLeft || requestedOrientation == .landscapeRight {
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 0.4)
        }

        XCUIDevice.shared.orientation = requestedOrientation
        Thread.sleep(forTimeInterval: 0.6)
    }

    private var requestedOrientation: UIDeviceOrientation {
        switch ProcessInfo.processInfo.environment["SCREENSHOT_ORIENTATION"] ?? screenshotConfig.orientation {
        case "landscapeRight":
            return .landscapeRight
        case "landscapeLeft":
            return .landscapeLeft
        default:
            return .portrait
        }
    }

    private func waitForRequestedOrientation() {
        let wantsLandscape = requestedOrientation == .landscapeLeft || requestedOrientation == .landscapeRight
        let deadline = Date().addingTimeInterval(4)
        var matched = false

        while Date() < deadline {
            let frame = app.frame
            if wantsLandscape, frame.width > frame.height {
                matched = true
                return
            }
            if !wantsLandscape, frame.height >= frame.width {
                matched = true
                return
            }
            Thread.sleep(forTimeInterval: 0.15)
        }

        XCTAssertTrue(
            matched,
            "Expected screenshot orientation \(requestedOrientation), got app frame \(app.frame)."
        )
    }

    private func recordScreenshot() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_PATH"] ?? screenshotConfig.outputPath,
              !outputPath.isEmpty else {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "gouache-screenshot"
            attachment.lifetime = .keepAlways
            add(attachment)
            return
        }

        let url = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let readyPath = ProcessInfo.processInfo.environment["SCREENSHOT_READY_PATH"] ?? screenshotConfig.readyPath {
            try "ready".write(toFile: readyPath, atomically: true, encoding: .utf8)
        }

        if let holdValue = ProcessInfo.processInfo.environment["SCREENSHOT_EXTERNAL_HOLD_SECONDS"] ?? screenshotConfig.holdSeconds,
           let holdSeconds = TimeInterval(holdValue) {
            Thread.sleep(forTimeInterval: holdSeconds)
            return
        }

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "gouache-screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)
        try screenshot.pngRepresentation.write(to: url, options: .atomic)
    }

    private func tapTemplate(slug: String) {
        let button = app.buttons["template.\(slug)"]
        if button.waitForExistence(timeout: 1), tapTemplateButtonIfVisible(button) {
            return
        }

        for _ in 0..<8 {
            app.swipeUp()
            if button.waitForExistence(timeout: 0.6), tapTemplateButtonIfVisible(button) {
                return
            }
        }

        for _ in 0..<8 {
            app.swipeDown()
            if button.waitForExistence(timeout: 0.6), tapTemplateButtonIfVisible(button) {
                return
            }
        }

        XCTFail("Expected template.\(slug) to be reachable.")
    }

    private func tapTemplateButtonIfVisible(_ button: XCUIElement) -> Bool {
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

    private func addSampleFills(to canvas: XCUIElement) {
        let points = [
            CGVector(dx: 0.50, dy: 0.50),
            CGVector(dx: 0.42, dy: 0.42),
            CGVector(dx: 0.58, dy: 0.42),
            CGVector(dx: 0.42, dy: 0.60),
            CGVector(dx: 0.60, dy: 0.58),
            CGVector(dx: 0.35, dy: 0.52),
            CGVector(dx: 0.65, dy: 0.50),
            CGVector(dx: 0.50, dy: 0.35)
        ]

        for point in points {
            canvas.coordinate(withNormalizedOffset: point).tap()
            Thread.sleep(forTimeInterval: 0.12)
        }
    }

    private func selectCanvasTool(_ identifier: String) {
        app.buttons["canvas.tools"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["canvas.settings.sheet"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 2))
        app.buttons[identifier].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["canvas.tools"].waitForExistence(timeout: 2))
    }
}

private struct ScreenshotConfig {
    var theme: String?
    var orientation: String?
    var outputPath: String?
    var readyPath: String?
    var holdSeconds: String?

    static func load() -> ScreenshotConfig {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".gouache-screenshot-config")
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return ScreenshotConfig()
        }

        var config = ScreenshotConfig()
        for line in contents.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "theme":
                config.theme = parts[1]
            case "orientation":
                config.orientation = parts[1]
            case "outputPath":
                config.outputPath = parts[1]
            case "readyPath":
                config.readyPath = parts[1]
            case "holdSeconds":
                config.holdSeconds = parts[1]
            default:
                continue
            }
        }
        return config
    }
}
