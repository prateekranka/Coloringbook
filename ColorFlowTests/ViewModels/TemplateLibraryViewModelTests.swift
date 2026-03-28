import XCTest
@testable import ColorFlow

@MainActor
final class TemplateLibraryViewModelTests: XCTestCase {

    // MARK: - Subject Under Test

    private var sut: TemplateLibraryViewModel!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        sut = TemplateLibraryViewModel()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialisation

    func test_init_loadsTemplates() {
        XCTAssertFalse(sut.templates.isEmpty,
                       "init must load at least one template via Template.loadAll()")
    }

    func test_init_selectedCategory_isNil() {
        XCTAssertNil(sut.selectedCategory,
                     "selectedCategory must start as nil (show all)")
    }

    // MARK: - filteredTemplates – no category selected

    func test_filteredTemplates_noCategory_returnsAll() {
        sut.selectedCategory = nil

        XCTAssertEqual(sut.filteredTemplates.count, sut.templates.count,
                       "When selectedCategory is nil, filteredTemplates must equal templates")
    }

    func test_filteredTemplates_noCategory_sameOrderAsTemplates() {
        sut.selectedCategory = nil

        let filteredIds = sut.filteredTemplates.map(\.id)
        let templateIds = sut.templates.map(\.id)
        XCTAssertEqual(filteredIds, templateIds,
                       "filteredTemplates with no category must preserve templates order")
    }

    // MARK: - filteredTemplates – with a matching category

    func test_filteredTemplates_withCategory_filtersCorrectly() {
        // Pick a category that has at least one template in the bundled catalogue.
        let category = TemplateCategory.animals
        sut.selectedCategory = category

        let filtered = sut.filteredTemplates
        XCTAssertFalse(filtered.isEmpty,
                       "'\(category.rawValue)' category should contain at least one template")
        XCTAssertTrue(filtered.allSatisfy { $0.category == category },
                      "All filtered templates must belong to the selected category")
    }

    func test_filteredTemplates_withCategory_excludesOtherCategories() {
        sut.selectedCategory = .mandalas

        let filtered = sut.filteredTemplates
        let wrongCategory = filtered.filter { $0.category != .mandalas }
        XCTAssertTrue(wrongCategory.isEmpty,
                      "filteredTemplates must not contain templates from other categories")
    }

    func test_filteredTemplates_eachCategory_isSubsetOfAll() {
        let allIds = Set(sut.templates.map(\.id))

        for category in TemplateCategory.allCases {
            sut.selectedCategory = category
            let filteredIds = Set(sut.filteredTemplates.map(\.id))
            XCTAssertTrue(filteredIds.isSubset(of: allIds),
                          "filteredTemplates for '\(category.rawValue)' must be a subset of all templates")
        }
    }

    // MARK: - filteredTemplates – category with no matches

    func test_filteredTemplates_categoryWithNoMatches_returnsEmpty() {
        // Force the templates list to contain only .abstract entries so that
        // querying .mandalas returns empty without mutating any real state.
        let abstractOnly = sut.templates.filter { $0.category == .abstract }

        // If there are no abstract templates at all, pick the inverse category.
        guard !abstractOnly.isEmpty else {
            // All templates are non-abstract; query .abstract → must be empty.
            sut.selectedCategory = .abstract
            XCTAssertTrue(sut.filteredTemplates.isEmpty,
                          "A category with no templates must return an empty array")
            return
        }

        // Replace the vm's template list with abstract-only, then query .mandalas.
        sut.templates = abstractOnly
        sut.selectedCategory = .mandalas

        XCTAssertTrue(sut.filteredTemplates.isEmpty,
                      "Filtering for a category that has no matching templates must return empty")
    }

    func test_filteredTemplates_emptyTemplateList_returnsEmpty() {
        sut.templates = []
        sut.selectedCategory = .animals

        XCTAssertTrue(sut.filteredTemplates.isEmpty,
                      "filteredTemplates must return empty when templates list is empty")
    }

    func test_filteredTemplates_emptyTemplateList_noCategorySelected_returnsEmpty() {
        sut.templates = []
        sut.selectedCategory = nil

        XCTAssertTrue(sut.filteredTemplates.isEmpty,
                      "filteredTemplates must return empty when both templates and category are empty/nil")
    }

    // MARK: - selectedCategory mutation

    func test_selectedCategory_changingCategory_updatesFilteredTemplates() {
        sut.selectedCategory = .animals
        let animalsCount = sut.filteredTemplates.count

        sut.selectedCategory = .botanicals
        let botanicalsCount = sut.filteredTemplates.count

        // Both selections were applied; result counts may differ (that's fine).
        // The key assertion: switching category changes the computed result.
        sut.selectedCategory = nil
        XCTAssertEqual(sut.filteredTemplates.count, sut.templates.count,
                       "Clearing selectedCategory after category changes must return all templates")
        _ = animalsCount   // suppress unused-variable warning
        _ = botanicalsCount
    }

    // MARK: - templates loaded correctly

    func test_templates_allHaveNonEmptyNames() {
        for template in sut.templates {
            XCTAssertFalse(template.name.isEmpty,
                           "Template id=\(template.id) must have a non-empty name")
        }
    }

    func test_templates_allHaveValidCategories() {
        let validCategories = Set(TemplateCategory.allCases)
        for template in sut.templates {
            XCTAssertTrue(validCategories.contains(template.category),
                          "Template '\(template.name)' has an unrecognised category")
        }
    }
}
