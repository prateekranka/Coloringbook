import PencilKit
import XCTest
@testable import ColorFlow

@MainActor
final class ColoringFlowTests: XCTestCase {
    private var storage: StorageService!
    private var projectsToDelete: [Project] = []

    override func setUp() {
        super.setUp()
        storage = StorageService()
        projectsToDelete = []
    }

    override func tearDown() {
        for project in projectsToDelete {
            storage.delete(project: project)
        }
        projectsToDelete = []
        storage = nil
        super.tearDown()
    }

    func test_storage_openOrCreateProject_reusesLatestProjectForTemplate() throws {
        let template = try uniqueTemplate()

        let first = storage.openOrCreateProject(for: template)
        projectsToDelete.append(first)
        let second = storage.openOrCreateProject(for: template)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.templateId, template.id)
        XCTAssertNotNil(storage.loadProject(id: first.id))
    }

    func test_sableRepository_continuePagesResumeMatchingSavedProject() async throws {
        let template = try uniqueTemplate()
        var project = Project(template: template)
        project.updateCompletion(filledRegionCount: 3, totalRegionCount: 4)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let repository = SableHomeRepository(storageService: storage, templates: [template])
        let pages = await repository.fetchContinuePages()
        let libraryPages = await repository.fetchLibraryPages()

        let page = try XCTUnwrap(pages.first { $0.projectId == project.id })
        XCTAssertEqual(page.templateId, template.id)
        XCTAssertEqual(page.title, template.name)
        XCTAssertEqual(page.progress, 0.75)
        XCTAssertEqual(page.thumbnailPath, project.thumbnailPath)
        XCTAssertEqual(page.fillLayerPath, project.fillLayerPath)
        XCTAssertTrue(libraryPages.contains { $0.projectId == project.id })

        let resolved = await repository.resolveProject(projectId: page.projectId, templateId: page.templateId)
        XCTAssertEqual(resolved?.project.id, project.id)
        XCTAssertEqual(resolved?.template.id, template.id)
    }

    func test_coloringSession_fillPersistsPaintStateAndProjectProgress() async throws {
        let template = try CanvasTestFixture.makeTemplate(name: "sunflower_mandala")
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let viewModel = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await viewModel.load()

        let geometry = try CanvasTestFixture.makeGeometry(templateName: "sunflower_mandala")
        let firstRegion = try XCTUnwrap(geometry.regions.first)
        await viewModel.fill(atDocumentPoint: CanvasTestFixture.interiorPoint(of: firstRegion))

        XCTAssertEqual(viewModel.filledRegionCount, 1)
        XCTAssertNotNil(viewModel.fillLayerImage)
        XCTAssertGreaterThan(viewModel.progress, 0)

        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        XCTAssertGreaterThan(savedProject.completionPercentage, 0)
        XCTAssertEqual(storage.loadPaintState(for: savedProject).regionFills.count, 1)
    }

    func test_coloringSession_reopeningProjectRestoresSavedFills() async throws {
        let template = try CanvasTestFixture.makeTemplate(name: "sunflower_mandala")
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let firstSession = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await firstSession.load()

        let geometry = try CanvasTestFixture.makeGeometry(templateName: "sunflower_mandala")
        let firstRegion = try XCTUnwrap(geometry.regions.first)
        await firstSession.fill(atDocumentPoint: CanvasTestFixture.interiorPoint(of: firstRegion))

        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        let repository = SableHomeRepository(storageService: storage, templates: [template])
        let reopenedSession = ColoringSessionViewModel(
            projectId: savedProject.id,
            templateId: template.id,
            fallbackTitle: template.name,
            repository: repository,
            storageService: storage
        )

        await reopenedSession.load()

        XCTAssertEqual(reopenedSession.filledRegionCount, 1)
        XCTAssertEqual(reopenedSession.progress, savedProject.completionPercentage)
        XCTAssertNotNil(reopenedSession.fillLayerImage)
    }

    private func uniqueTemplate() throws -> Template {
        let base = try CanvasTestFixture.makeTemplate(name: "sunflower_mandala")
        return Template(
            id: UUID(),
            name: "Sunflower \(UUID().uuidString.prefix(8))",
            category: base.category,
            difficulty: base.difficulty,
            svgFilename: base.svgFilename,
            thumbnailFilename: base.thumbnailFilename,
            userTemplateDirectoryPath: base.userTemplateDirectoryPath
        )
    }
}
