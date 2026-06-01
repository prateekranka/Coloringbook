import XCTest


final class TabSwitcherTests: XCTestCase {
    
    private var harness: PersonaHarness!
    
    override func setUpWithError() throws {
        try XCTSkipIf(!ProcessInfo.processInfo.arguments.contains("-personaRun"),
                      "Persona tests require -personaRun launch argument")
        continueAfterFailure = false
        let app = MainActor.assumeIsolated { XCUIApplication() }
        MainActor.assumeIsolated {
            app.launchArguments += ["-skipOnboarding", "-personaRun", "-personaSeed=tab-switcher"]
            app.launch()
        }
        let udid = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? ""
        harness = MainActor.assumeIsolated { PersonaHarness(app: app, udid: udid) }
    }
    
    override func tearDownWithError() throws {
        MainActor.assumeIsolated {
            harness?.captureDiagnostics(testCase: self)
        }
        harness = nil
    }
    
    @MainActor
    func test_rapidTabSwitching() throws {
        let tabLabels = ["Home", "Gallery", "My Work"]
        
        for i in 0..<30 {
            let tab = tabLabels[i % tabLabels.count]
            try harness.tap(label: tab)
            
            if i % 2 == 0 {
                let tree = try harness.describeUI()
                if tree.contains("library.reference.template.") {
                    let firstTemplate = extractFirstMatch(from: tree, prefix: "library.reference.template.")
                    if let templateId = firstTemplate {
                        try harness.tap(id: templateId)
                        try harness.tap(id: "canvas.pigmentWell")
                        try harness.tap(label: "Close palette")
                        try harness.tap(id: "canvas.back")
                    }
                }
            }
            
            if i == 15 {
                try harness.rotate(to: .landscapeLeft)
            }
            if i == 22 {
                try harness.rotate(to: .portrait)
            }
        }
        
        let tree = try harness.describeUI()
        XCTAssertTrue(tree.contains("Home"), "Home tab should be present after rotation")
        XCTAssertTrue(tree.contains("Gallery"), "Gallery tab should be present after rotation")
        XCTAssertTrue(tree.contains("My Work"), "My Work tab should be present after rotation")
        
        let projectsData = try harness.projectsJSONData()
        if let data = projectsData {
            let json = try JSONSerialization.jsonObject(with: data)
            XCTAssertTrue(json is [Any], "projects.json should be valid JSON after tab switching")
        }
    }
    
    private func extractFirstMatch(from tree: String, prefix: String) -> String? {
        guard let range = tree.range(of: prefix) else { return nil }
        let start = range.lowerBound
        let end = tree[start...].firstIndex(where: { $0 == "\"" || $0 == "'" || $0.isWhitespace }) ?? tree.endIndex
        return String(tree[start..<end])
    }
}
