import XCTest

@MainActor
final class ScreenshotUITests: XCTestCase {
    
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-screenshotMode"]
    }
    
    func test_captureHome() throws {
        app.launch()

        let heroText = app.staticTexts["Gouache"]
        XCTAssertTrue(heroText.waitForExistence(timeout: 10))

        sleep(3)
    }

    func test_captureExplore() throws {
        app.launch()

        XCTAssertTrue(app.buttons["tab.library"].waitForExistence(timeout: 5))
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))
        sleep(2)
    }

    func test_captureCanvas() throws {
        app.launch()

        XCTAssertTrue(app.buttons["tab.library"].waitForExistence(timeout: 5))
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.buttons["template.wildflowers"].waitForExistence(timeout: 5))
        app.buttons["template.wildflowers"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["canvas.surface"].waitForExistence(timeout: 5))
        sleep(2)
    }

    func test_captureLibrary() throws {
        app.launch()

        XCTAssertTrue(app.buttons["tab.profile"].waitForExistence(timeout: 5))
        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 5))
        sleep(2)
    }

    func test_captureCollection() throws {
        app.launch()

        XCTAssertTrue(app.buttons["home.collection.fresh-botanicals"].waitForExistence(timeout: 5))
        app.buttons["home.collection.fresh-botanicals"].tap()
        XCTAssertTrue(app.staticTexts["Fresh Botanicals"].waitForExistence(timeout: 5))
        sleep(2)
    }
}
