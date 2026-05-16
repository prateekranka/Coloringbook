import XCTest


final class DeepColoristTests: XCTestCase {
    
    private var harness: PersonaHarness!
    
    override func setUpWithError() throws {
        try XCTSkipIf(!ProcessInfo.processInfo.arguments.contains("-personaRun"),
                      "Persona tests require -personaRun launch argument")
        continueAfterFailure = false
        let app = MainActor.assumeIsolated { XCUIApplication() }
        MainActor.assumeIsolated {
            app.launchArguments += ["-skipOnboarding", "-personaRun", "-personaSeed=deep-colorist"]
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
    func test_longPencilSession() throws {
        try harness.tap(id: "canvas.tool.pencil")
        
        let _ = try harness.describeUI()
        let steps: [PersonaHarness.BatchStep] = (0..<50).map { _ in
            let startX = Double.random(in: 100...700)
            let startY = Double.random(in: 100...700)
            let endX = Double.random(in: 100...700)
            let endY = Double.random(in: 100...700)
            return .swipe(from: startX, startY, to: endX, endY)
        }
        let drawLatency = try harness.measureBatch(steps, name: "deep colorist draw burst", testCase: self)
        XCTAssertLessThan(drawLatency, 20, "Axe-driven draw burst should stay responsive enough for persona coverage.")
        
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
        let eraseLatency = try harness.measureBatch(eraseSteps, name: "deep colorist erase burst", testCase: self)
        XCTAssertLessThan(eraseLatency, 8, "Axe-driven erase burst should stay responsive enough for persona coverage.")
        
        try harness.tap(id: "canvas.tool.pencil")
        let moreSteps: [PersonaHarness.BatchStep] = (0..<20).map { _ in
            let startX = Double.random(in: 100...700)
            let startY = Double.random(in: 100...700)
            let endX = Double.random(in: 100...700)
            let endY = Double.random(in: 100...700)
            return .swipe(from: startX, startY, to: endX, endY)
        }
        let finalDrawLatency = try harness.measureBatch(moreSteps, name: "deep colorist final draw burst", testCase: self)
        XCTAssertLessThan(finalDrawLatency, 10, "Final axe-driven draw burst should stay responsive enough for persona coverage.")
        
        try harness.tap(id: "canvas.back")
        
        let projectsData = try harness.projectsJSONData()
        XCTAssertNotNil(projectsData, "projects.json should exist after deep colorist session")
    }
}
