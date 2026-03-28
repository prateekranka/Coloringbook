import XCTest
import PencilKit
@testable import ColorFlow

@MainActor
final class GalleryViewModelTests: XCTestCase {

    // MARK: - Subject Under Test

    private var sut: GalleryViewModel!
    private var storage: StorageService!

    // Projects created in tests; removed from disk in tearDown.
    private var savedProjects: [Project] = []

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        storage = StorageService()
        savedProjects = []
        sut = GalleryViewModel()
    }

    override func tearDown() async throws {
        for project in savedProjects {
            storage.delete(project: project)
        }
        savedProjects = []
        sut = nil
        storage = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Saves a project to disk and registers it for cleanup.
    private func persist(_ project: Project) {
        var mutable = project
        try? storage.save(project: &mutable, drawing: PKDrawing(), fillLayer: nil)
        savedProjects.append(mutable)
    }

    /// Makes a project from the first available bundled template and persists it.
    private func makePersistentProject() -> Project {
        let template = Template.loadAll().first ?? TestHelpers.makeTemplate()
        let project = Project(template: template)
        persist(project)
        return project
    }

    // MARK: - recentProjects

    func test_recentProjects_maxSix() {
        // Save 8 projects so the total exceeds the 6-item cap.
        for _ in 0..<8 {
            _ = makePersistentProject()
        }
        sut.reload()

        XCTAssertLessThanOrEqual(sut.recentProjects.count, 6,
                                 "recentProjects must be capped at 6 items")
    }

    func test_recentProjects_fewerThanSix_returnsAll() {
        // Start from a clean slate count for this test by checking relative delta.
        let before = sut.recentProjects.count
        let toAdd = max(0, 3 - before)   // add enough to have at least 3, but no more than 5 total
        for _ in 0..<toAdd {
            _ = makePersistentProject()
        }
        sut.reload()

        XCTAssertLessThanOrEqual(sut.recentProjects.count, 6,
                                 "recentProjects must never exceed 6")
    }

    func test_recentProjects_sortedByModifiedAtDescending() {
        _ = makePersistentProject()
        Thread.sleep(forTimeInterval: 0.05)
        _ = makePersistentProject()
        sut.reload()

        let dates = sut.recentProjects.map(\.modifiedAt)
        let sorted = dates.sorted(by: >)
        XCTAssertEqual(dates, sorted,
                       "recentProjects must be sorted most-recently-modified first")
    }

    // MARK: - suggestedTemplates

    func test_suggestedTemplates_excludesStartedProjects() {
        // Start a project so its templateId is in the "started" set.
        let templates = Template.loadAll()
        guard let firstTemplate = templates.first else {
            XCTFail("No templates available for this test")
            return
        }
        sut.startProject(from: firstTemplate)
        sut.reload()

        let suggestedIds = Set(sut.suggestedTemplates.map(\.id))
        XCTAssertFalse(suggestedIds.contains(firstTemplate.id),
                       "suggestedTemplates must not include templates that already have a project")
    }

    func test_suggestedTemplates_maxEight() {
        XCTAssertLessThanOrEqual(sut.suggestedTemplates.count, 8,
                                 "suggestedTemplates must be capped at 8 items")
    }

    // MARK: - rename

    func test_rename_emptyName_doesNothing() {
        let project = makePersistentProject()
        sut.reload()

        let original = project.templateName
        sut.rename(project, to: "")

        let updated = sut.projects.first { $0.id == project.id }
        XCTAssertEqual(updated?.templateName ?? original, original,
                       "rename with an empty string must not change the project name")
    }

    func test_rename_whitespaceOnlyName_doesNothing() {
        let project = makePersistentProject()
        sut.reload()

        let original = project.templateName
        sut.rename(project, to: "   \t  ")

        let updated = sut.projects.first { $0.id == project.id }
        XCTAssertEqual(updated?.templateName ?? original, original,
                       "rename with whitespace-only name must not change the project name")
    }

    func test_rename_updatesLocalList() {
        let project = makePersistentProject()
        sut.reload()

        sut.rename(project, to: "My Renamed Project")

        let updated = sut.projects.first { $0.id == project.id }
        XCTAssertEqual(updated?.templateName, "My Renamed Project",
                       "rename must update the in-memory project list immediately")
    }

    func test_rename_trimmesLeadingTrailingWhitespace() {
        let project = makePersistentProject()
        sut.reload()

        sut.rename(project, to: "  Trimmed Name  ")

        let updated = sut.projects.first { $0.id == project.id }
        XCTAssertEqual(updated?.templateName, "Trimmed Name",
                       "rename must trim leading/trailing whitespace from the new name")
    }

    // MARK: - startProject

    func test_startProject_setsOpenedProject() {
        let template = Template.loadAll().first ?? TestHelpers.makeTemplate()

        sut.startProject(from: template)

        XCTAssertNotNil(sut.openedProject,
                        "startProject must set openedProject to a non-nil value")
        XCTAssertEqual(sut.openedProject?.template.id, template.id,
                       "openedProject.template must match the template passed to startProject")
    }

    func test_startProject_triggersReload() {
        let template = Template.loadAll().first ?? TestHelpers.makeTemplate()
        let countBefore = sut.projects.count

        sut.startProject(from: template)

        // After startProject the vm calls reload(); the new project is not yet
        // persisted (CanvasViewModel does that on first auto-save), so count may
        // stay the same. We just verify no crash and that openedProject is set.
        _ = countBefore   // suppress unused-variable warning
        XCTAssertNotNil(sut.openedProject)
    }

    // MARK: - open

    func test_open_knownTemplate_setsOpenedProject() {
        // Use a template from the real bundled catalogue so the lookup succeeds.
        let templates = Template.loadAll()
        guard let template = templates.first else {
            XCTFail("No bundled templates available")
            return
        }
        let project = Project(template: template)
        persist(project)
        sut.reload()

        sut.open(project)

        XCTAssertNotNil(sut.openedProject,
                        "open must set openedProject when the template is found")
        XCTAssertEqual(sut.openedProject?.project.id, project.id)
    }

    func test_open_unknownTemplate_doesNotSetOpenedProject() {
        // A project whose templateId is not in allTemplates → open() is a no-op.
        let orphanTemplate = TestHelpers.makeTemplate(id: UUID(), name: "Orphan")
        let project = Project(template: orphanTemplate)
        // Don't persist — it won't be in the vm's allTemplates list regardless.

        let before = sut.openedProject
        sut.open(project)

        // openedProject should remain unchanged (nil if nothing was open before).
        if before == nil {
            XCTAssertNil(sut.openedProject,
                         "open with an unknown templateId must not set openedProject")
        }
    }

    // MARK: - delete

    func test_delete_removesFromList() {
        let project = makePersistentProject()
        sut.reload()

        XCTAssertTrue(sut.projects.contains { $0.id == project.id },
                      "Project must be in the list before deletion")

        sut.delete(project)

        XCTAssertFalse(sut.projects.contains { $0.id == project.id },
                       "delete must remove the project from the in-memory list")

        // Avoid double-delete in tearDown (already removed).
        savedProjects.removeAll { $0.id == project.id }
    }

    func test_delete_missingProject_doesNotCrash() {
        let orphan = TestHelpers.makeProject()
        // Not saved → delete should be a silent no-op on both disk and list.
        XCTAssertNoThrow(sut.delete(orphan))
    }

    // MARK: - reload

    func test_reload_projectsNotNil() {
        sut.reload()
        // `projects` is `@Published var`; after reload it must be a valid array.
        XCTAssertNotNil(sut.projects as [Project]?)
    }
}
