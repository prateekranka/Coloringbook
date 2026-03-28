import XCTest
@testable import ColorFlow

final class ProjectTests: XCTestCase {

    func test_init_fromTemplate_setsCorrectFields() {
        let template = TestHelpers.makeTemplate(name: "My Template", category: .animals)
        let project = Project(template: template)
        XCTAssertEqual(project.templateId, template.id)
        XCTAssertEqual(project.templateName, template.name)
        XCTAssertNil(project.completionFraction)
    }

    func test_init_pathScheme_drawingDataPath() {
        let project = TestHelpers.makeProject()
        XCTAssertTrue(project.drawingDataPath.hasPrefix("drawings/"))
        XCTAssertTrue(project.drawingDataPath.hasSuffix(".pkdata"))
        XCTAssertTrue(project.drawingDataPath.contains(project.id.uuidString))
    }

    func test_init_pathScheme_fillLayerPath() {
        let project = TestHelpers.makeProject()
        XCTAssertTrue(project.fillLayerPath.hasPrefix("fills/"))
        XCTAssertTrue(project.fillLayerPath.hasSuffix(".png"))
        XCTAssertTrue(project.fillLayerPath.contains(project.id.uuidString))
    }

    func test_init_pathScheme_thumbnailPath() {
        let project = TestHelpers.makeProject()
        XCTAssertTrue(project.thumbnailPath.hasPrefix("thumbnails/"))
        XCTAssertTrue(project.thumbnailPath.hasSuffix(".png"))
        XCTAssertTrue(project.thumbnailPath.contains(project.id.uuidString))
    }

    func test_codable_roundTrip() throws {
        let template = TestHelpers.makeTemplate()
        var project = Project(template: template)
        project.completionFraction = 0.75
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(decoded.id, project.id)
        XCTAssertEqual(decoded.templateId, project.templateId)
        XCTAssertEqual(decoded.templateName, project.templateName)
        XCTAssertEqual(decoded.completionFraction, 0.75)
    }

    func test_codable_backwardCompat_missingCompletionFraction() throws {
        // Simulate JSON from an older version that doesn't have completionFraction
        let template = TestHelpers.makeTemplate()
        let project = Project(template: template)
        var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as! [String: Any]
        dict.removeValue(forKey: "completionFraction")
        let dataWithoutFraction = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(Project.self, from: dataWithoutFraction)
        XCTAssertNil(decoded.completionFraction)
    }

    func test_codable_withCompletionFraction() throws {
        let template = TestHelpers.makeTemplate()
        var project = Project(template: template)
        project.completionFraction = 0.42
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(decoded.completionFraction, 0.42, accuracy: 0.001)
    }

    func test_identifiable_conformance() {
        let t = TestHelpers.makeTemplate()
        let p1 = Project(template: t)
        let p2 = Project(template: t)
        XCTAssertNotEqual(p1.id, p2.id)
    }

    func test_init_createdAtAndModifiedAtAreClose() {
        let project = TestHelpers.makeProject()
        let diff = abs(project.createdAt.timeIntervalSince(project.modifiedAt))
        XCTAssertLessThan(diff, 1.0)
    }
}
