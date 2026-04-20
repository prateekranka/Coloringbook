import XCTest

@MainActor
final class DeepColoristTests: XCTestCase {
    
    private var harness: PersonaHarness!
    
    override func setUpWithError() throws {
        try XCTSkipIf(!ProcessInfo.processInfo.arguments.contains("-personaRun"),
                      "Persona tests require -personaRun launch argument")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-personaRun", "-personaSeed=deep-colorist"]
        app.launch()
        let udid = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? ""
        harness = PersonaHarness(app: app, udid: udid)
    }
    
    override func tearDownWithError() throws {
        harness?.captureDiagnostics(testCase: self)
        harness = nil
    }
    
    func test_longPencilSession() throws {
        try harness.tap(id: "canvas.tool.pencil")
        
        let tree = try harness.describeUI()
        let steps: [PersonaHarness.BatchStep] = (0..<50).map { _ in
            let startX = Double.random(in: 100...700)
            let startY = Double.random(in: 100...700)
            let endX = Double.random(in: 100...700)
            let endY = Double.random(in: 100...700)
            return .swipe(from: startX, startY, to: endX, endY)
        }
        try harness.batch(steps)
        
        for _ in 0..<15 {
            try harness.tap(id: "canvas.undo")
        }
        for _ in 0..<5 {
            try harness.tap(id: "canvas.redo")
        }
        
        try harness.tap(id: "canvas.tool.eraser")
        let eraseSteps: [PersonaHarness.BatchStep] = (0..<10).map { _ in
            let startX = Double.random(in: 100...700)
            let startY = Double.random(in: 100...700)
            let endX = Double.random(in: 100...700)
            let endY = Double.random(in: 100...700)
            return .swipe(from: startX, startY, to: endX, endY)
        }
        try harness.batch(eraseSteps)
        
        try harness.tap(id: "canvas.tool.pencil")
        let moreSteps: [PersonaHarness.BatchStep] = (0..<20).map { _ in
            let startX = Double.random(in: 100...700)
            let startY = Double.random(in: 100...700)
            let endX = Double.random(in: 100...700)
            let endY = Double.random(in: 100...700)
            return .swipe(from: startX, startY, to: endX, endY)
        }
        try harness.batch(moreSteps)
        
        try harness.tap(id: "canvas.back")
        
        let projectsData = try harness.projectsJSONData()
        XCTAssertNotNil(projectsData, "projects.json should exist after deep colorist session")
    }
}