import XCTest
@testable import ColorFlow

final class TemplateTests: XCTestCase {

    // MARK: - Codable

    func test_codable_roundTrip() throws {
        let original = TestHelpers.makeTemplate(
            id: UUID(),
            name: "Lotus Mandala",
            category: .mandalas,
            difficulty: .hard,
            svgFilename: "lotus_mandala.svg"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Template.self, from: data)

        XCTAssertEqual(decoded.id,                original.id)
        XCTAssertEqual(decoded.name,              original.name)
        XCTAssertEqual(decoded.category,          original.category)
        XCTAssertEqual(decoded.difficulty,        original.difficulty)
        XCTAssertEqual(decoded.svgFilename,       original.svgFilename)
        XCTAssertEqual(decoded.thumbnailFilename, original.thumbnailFilename)
    }

    // MARK: - TemplateCategory

    func test_templateCategory_allCases_count() {
        XCTAssertEqual(TemplateCategory.allCases.count, 5,
                       "TemplateCategory should have exactly 5 cases")
    }

    func test_templateCategory_allCases_containsExpectedValues() {
        let expected: Set<TemplateCategory> = [.mandalas, .animals, .abstract, .botanicals, .lifestyle]
        XCTAssertEqual(Set(TemplateCategory.allCases), expected)
    }

    func test_templateCategory_rawValues() {
        XCTAssertEqual(TemplateCategory.mandalas.rawValue,  "Mandalas")
        XCTAssertEqual(TemplateCategory.animals.rawValue,   "Animals")
        XCTAssertEqual(TemplateCategory.abstract.rawValue,  "Abstract")
        XCTAssertEqual(TemplateCategory.botanicals.rawValue,"Botanicals")
        XCTAssertEqual(TemplateCategory.lifestyle.rawValue, "Lifestyle")
    }

    func test_templateCategory_systemImageName_nonEmpty() {
        for category in TemplateCategory.allCases {
            XCTAssertFalse(category.systemImageName.isEmpty,
                           "systemImageName for '\(category)' should not be empty")
        }
    }

    // MARK: - Difficulty

    func test_difficulty_allCases_count() {
        XCTAssertEqual(Difficulty.allCases.count, 3,
                       "Difficulty should have exactly 3 cases")
    }

    func test_difficulty_allCases_containsExpectedValues() {
        let expected: Set<Difficulty> = [.easy, .medium, .hard]
        XCTAssertEqual(Set(Difficulty.allCases), expected)
    }

    func test_difficulty_rawValues() {
        XCTAssertEqual(Difficulty.easy.rawValue,   "Easy")
        XCTAssertEqual(Difficulty.medium.rawValue, "Medium")
        XCTAssertEqual(Difficulty.hard.rawValue,   "Hard")
    }

    func test_difficulty_color_nonEmpty() {
        for difficulty in Difficulty.allCases {
            XCTAssertFalse(difficulty.color.isEmpty,
                           "color string for '\(difficulty)' should not be empty")
        }
    }

    // MARK: - Equatable (by ID)

    func test_equality_byID_sameId_areEqual() {
        let sharedId = UUID()
        let t1 = TestHelpers.makeTemplate(id: sharedId, name: "Alpha", category: .animals)
        let t2 = TestHelpers.makeTemplate(id: sharedId, name: "Beta",  category: .mandalas)
        // Different names/categories but same id → must be equal.
        XCTAssertEqual(t1, t2,
                       "Two templates with the same id must be equal regardless of other fields")
    }

    func test_equality_byID_differentId_areNotEqual() {
        let t1 = TestHelpers.makeTemplate(id: UUID(), name: "Same Name")
        let t2 = TestHelpers.makeTemplate(id: UUID(), name: "Same Name")
        XCTAssertNotEqual(t1, t2,
                          "Templates with different ids must not be equal")
    }

    // MARK: - Hashable (by ID)

    func test_hash_byID_sameId_sameHash() {
        let sharedId = UUID()
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        TestHelpers.makeTemplate(id: sharedId).hash(into: &hasher1)
        TestHelpers.makeTemplate(id: sharedId).hash(into: &hasher2)
        XCTAssertEqual(hasher1.finalize(), hasher2.finalize(),
                       "Templates with the same id must produce the same hash")
    }

    func test_hash_usableInSet() {
        let sharedId = UUID()
        let t1 = TestHelpers.makeTemplate(id: sharedId)
        let t2 = TestHelpers.makeTemplate(id: sharedId)
        let set: Set<Template> = [t1, t2]
        XCTAssertEqual(set.count, 1,
                       "A Set<Template> should deduplicate by id")
    }

    // MARK: - loadAll

    func test_loadAll_returnsNonEmptyArray() {
        let templates = Template.loadAll()
        XCTAssertFalse(templates.isEmpty,
                       "Template.loadAll() must return at least one template")
    }

    func test_loadAll_allHaveNonEmptyNames() {
        for template in Template.loadAll() {
            XCTAssertFalse(template.name.isEmpty,
                           "Template id=\(template.id) has an empty name")
        }
    }

    func test_loadAll_allHaveNonEmptySVGFilename() {
        for template in Template.loadAll() {
            XCTAssertFalse(template.svgFilename.isEmpty,
                           "Template '\(template.name)' has an empty svgFilename")
        }
    }

    func test_loadAll_uniqueIds() {
        let templates = Template.loadAll()
        let ids = templates.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count,
                       "All templates returned by loadAll() must have unique ids")
    }
}
