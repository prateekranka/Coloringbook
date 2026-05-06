import XCTest
@testable import ColorFlow

final class ProjectModelTests: XCTestCase {
    func test_projectDecoding_defaultsMissingStatusForBackwardCompatibility() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "templateId": "22222222-2222-2222-2222-222222222222",
          "templateName": "Legacy Template",
          "createdAt": 0,
          "modifiedAt": 0,
          "drawingDataPath": "drawings/legacy.pkdata",
          "fillLayerPath": "fills/legacy.png",
          "thumbnailPath": "thumbnails/legacy.png"
        }
        """.data(using: .utf8)!

        let project = try JSONDecoder().decode(Project.self, from: json)

        XCTAssertEqual(project.status, .inProgress)
        XCTAssertEqual(project.completionPercentage, 0)
    }

    func test_projectStatusAndCompletion_roundTripThroughJSON() throws {
        var project = Project(template: Template(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Round Trip Template",
            category: .mandalas,
            difficulty: .medium,
            svgFilename: "lotus_mandala.svg",
            thumbnailFilename: "thumb_lotus_mandala.png"
        ))
        project.updateCompletion(filledRegionCount: 3, totalRegionCount: 4)

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.status, .inProgress)
        XCTAssertEqual(decoded.completionPercentage, 0.75)
    }
}
