// AccessibilityUITests.swift
//
// Minimum-viable UI-level accessibility coverage for the primary tabs and
// canvas. Assertions are deliberately terse: presence of accessibility
// identifiers and labels we've committed to in the source. Behavior is
// covered by unit tests; this file guards against accidental label removal.
//
// Requires a `ColorFlowUITests` target in project.yml — not wired today (F-05).

import XCTest

final class AccessibilityUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Tab bar

    func test_tabBar_itemsAreReachable() throws {
        let app = XCUIApplication()
        app.launch()

        // Dismiss onboarding if it appears on first launch.
        let onboardingContinue = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Get Started")
        ).firstMatch
        if onboardingContinue.waitForExistence(timeout: 2) {
            onboardingContinue.tap()
        }

        XCTAssertTrue(app.tabBars.buttons["Home"].exists,
                      "Home tab item must be reachable by accessibility label.")
        XCTAssertTrue(app.tabBars.buttons["Library"].exists,
                      "Library tab item must be reachable by accessibility label.")
        XCTAssertTrue(app.tabBars.buttons["My Work"].exists,
                      "My Work tab item must be reachable by accessibility label.")
    }

    // MARK: - Home

    func test_home_primaryActions_haveAccessibilityIdentifiers() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.tabBars.buttons["Home"].waitForExistence(timeout: 2)
        app.tabBars.buttons["Home"].tap()

        let plus = app.buttons["home.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2),
                      "Home '+' toolbar button missing identifier 'home.plus'.")
        XCTAssertFalse(plus.label.isEmpty,
                       "Home '+' button must have a non-empty accessibility label.")

        let browse = app.buttons["home.browseTemplates"]
        XCTAssertTrue(browse.waitForExistence(timeout: 2),
                      "Home 'Browse Templates' CTA missing identifier.")
    }

    // MARK: - Library

    func test_library_categoryBar_isReachable() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.tabBars.buttons["Library"].waitForExistence(timeout: 2)
        app.tabBars.buttons["Library"].tap()

        XCTAssertTrue(app.buttons["library.category.All"].waitForExistence(timeout: 2),
                      "Library 'All' category tab missing identifier.")
    }

    // MARK: - Canvas (exercises toolbar labels when a template is opened)
    // NOTE: This test requires a seeded template + project and is scaffolded
    // but left `skipIf` until the UI test host can seed one deterministically.

    func test_canvas_toolbar_hasLabeledActions() throws {
        throw XCTSkip("Requires seeded template fixture in the UI test host — tracked with A3 test-target wiring.")
    }
}
