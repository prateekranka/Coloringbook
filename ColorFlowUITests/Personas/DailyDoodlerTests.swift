import XCTest

@MainActor
final class DailyDoodlerTests: XCTestCase {
    
    private var harness: PersonaHarness!
    
    override func setUpWithError() throws {
        try XCTSkipIf(!ProcessInfo.processInfo.arguments.contains("-personaRun"),
                      "Persona tests require -personaRun launch argument")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-personaRun", "-personaSeed=daily-doodler"]
        app.launch()
        let udid = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? ""
        harness = PersonaHarness(app: app, udid: udid)
    }
    
    override func tearDownWithError() throws {
        harness?.captureDiagnostics(testCase: self)
        harness = nil
    }
    
    func test_shortSessions() throws {
        let sessionCount = 20
        
        for i in 0..<sessionCount {
            try harness.tap(id: "library.category.All")
            
            let tree = try harness.describeUI()
            if tree.contains("library.template.") {
                let firstTemplate = extractFirstMatch(from: tree, prefix: "library.template.")
                if let templateId = firstTemplate {
                    try harness.tap(id: templateId)
                    
                    try harness.tap(id: "canvas.tool.fill")
                    try harness.tap(id: "canvas.colorWell")
                    
                    let pickerTree = try harness.describeUI()
                    if pickerTree.contains("picker.recent.0") {
                        try harness.tap(id: "picker.recent.0")
                    }
                    try harness.tap(id: "picker.close")
                    
                    try harness.tap(id: "canvas.back")
                }
            }
            
            if i % 5 == 0 {
                let snapshot = try harness.documentsSnapshot()
                XCTAssertTrue(snapshot.count < 100, "Documents directory should not grow unbounded after \(i) sessions")
            }
        }
        
        let projectsData = try harness.projectsJSONData()
        if let data = projectsData {
            let json = try JSONSerialization.jsonObject(with: data)
            XCTAssertTrue(json is [Any], "projects.json should be a valid JSON array")
        }
    }
    
    private func extractFirstMatch(from tree: String, prefix: String) -> String? {
        guard let range = tree.range(of: prefix) else { return nil }
        let start = range.lowerBound
        let end = tree[start...].firstIndex(where: { $0 == "\"" || $0 == "'" || $0.isWhitespace }) ?? tree.endIndex
        return String(tree[start..<end])
    }
}