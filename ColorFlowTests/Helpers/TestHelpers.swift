import Foundation
import XCTest
@testable import ColorFlow

/// Shared test utilities.
enum TestHelpers {

    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "com.colorflow.test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    static func makeTempDirectory() -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func makeTemplate(
        id: UUID = UUID(),
        name: String = "Test Template",
        category: TemplateCategory = .abstract,
        difficulty: Difficulty = .easy,
        svgFilename: String = "test.svg"
    ) -> Template {
        Template(
            id: id,
            name: name,
            category: category,
            difficulty: difficulty,
            svgFilename: svgFilename,
            thumbnailFilename: "thumb_\(svgFilename.replacingOccurrences(of: ".svg", with: ".png"))"
        )
    }

    static func makeProject(template: Template? = nil) -> Project {
        let t = template ?? makeTemplate()
        return Project(template: t)
    }
}
