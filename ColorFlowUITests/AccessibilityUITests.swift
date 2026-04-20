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

    /// iPadOS 26.4+ renders TabView as a top segmented control instead of a bottom
    /// tab bar. This helper finds the tab element across all possible layouts.
    private func tabElement(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        // SwiftUI TabView doesn't honor accessibility identifiers on tab
        // buttons (iOS 18+ framework limitation), so we query by label. Scope
        // to the tab bar first to avoid collisions with section headers that
        // may share the same text (e.g., "Home" tab + "Home" screen title).
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists, tabBar.buttons[label].exists { return tabBar.buttons[label] }
        // iPadOS 26.4+ top-segmented-control variant exposes tabs as
        // descendants of the first otherElement whose buttons include all
        // three tab labels. Fall back to boundBy to avoid ambiguity.
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", label))
        if buttons.count == 1 { return buttons.firstMatch }
        if buttons.count > 1 { return buttons.element(boundBy: 0) }
        // Sidebar/outline variant
        if app.cells[label].exists { return app.cells[label] }
        return app.buttons[label]
    }

    func test_tabBar_itemsAreReachable() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()

        XCTAssertTrue(tabElement(app, "Home").waitForExistence(timeout: 3),
                      "Home tab item must be reachable by accessibility label.")
        XCTAssertTrue(tabElement(app, "Library").exists,
                      "Library tab item must be reachable by accessibility label.")
        XCTAssertTrue(tabElement(app, "My Work").exists,
                      "My Work tab item must be reachable by accessibility label.")
    }

    // MARK: - Home

    func test_home_primaryActions_haveAccessibilityIdentifiers() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        _ = tabElement(app, "Home").waitForExistence(timeout: 3)
        tabElement(app, "Home").tap()

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
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        let libraryTab = tabElement(app, "Library")
        _ = libraryTab.waitForExistence(timeout: 3)
        libraryTab.firstMatch.tap()

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
