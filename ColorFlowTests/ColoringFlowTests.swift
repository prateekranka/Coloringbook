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
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let viewModel = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await viewModel.load()

        await viewModel.fill(atDocumentPoint: try representativeFillPoint())

        XCTAssertEqual(viewModel.filledRegionCount, 1)
        XCTAssertNotNil(viewModel.fillLayerImage)
        XCTAssertGreaterThan(viewModel.progress, 0)
        XCTAssertEqual(viewModel.saveState, .dirty)

        XCTAssertEqual(storage.loadPaintState(for: project).regionFills.count, 0)
        viewModel.save()
        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        XCTAssertGreaterThan(savedProject.completionPercentage, 0)
        XCTAssertEqual(storage.loadPaintState(for: savedProject).regionFills.count, 1)
        XCTAssertEqual(viewModel.saveState, .saved)
    }

    func test_coloringSession_reopeningProjectRestoresSavedFills() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let firstSession = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await firstSession.load()

        await firstSession.fill(atDocumentPoint: try representativeFillPoint())
        firstSession.save()

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

    func test_coloringSession_undoRedoRestoresTapFillsAndDirtyState() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let viewModel = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await viewModel.load()

        let point = try representativeFillPoint()

        let didFill = await viewModel.fill(atDocumentPoint: point)
        XCTAssertTrue(didFill)
        let filledProgress = viewModel.progress

        XCTAssertEqual(viewModel.filledRegionCount, 1)
        XCTAssertGreaterThan(filledProgress, 0)
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .dirty)

        await viewModel.undoLastFill()

        XCTAssertEqual(viewModel.filledRegionCount, 0)
        XCTAssertEqual(viewModel.progress, 0)
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertTrue(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .saved)

        await viewModel.redoFill()

        XCTAssertEqual(viewModel.filledRegionCount, 1)
        XCTAssertEqual(viewModel.progress, filledProgress, accuracy: 0.0001)
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .dirty)
    }

    func test_coloringSession_clearArtworkResetsProgressAfterConfirmationPathAndSavesBlankState() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let viewModel = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await viewModel.load()

        let didFill = await viewModel.fill(atDocumentPoint: try representativeFillPoint())
        XCTAssertTrue(didFill)
        viewModel.save()
        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        XCTAssertEqual(storage.loadPaintState(for: savedProject).regionFills.count, 1)

        await viewModel.clearArtwork()

        XCTAssertEqual(viewModel.filledRegionCount, 0)
        XCTAssertEqual(viewModel.progress, 0)
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .dirty)
        XCTAssertEqual(storage.loadPaintState(for: savedProject).regionFills.count, 1)

        viewModel.save()
        let resetProject = try XCTUnwrap(storage.loadProject(id: project.id))
        XCTAssertEqual(resetProject.completionPercentage, 0)
        XCTAssertEqual(storage.loadPaintState(for: resetProject).regionFills.count, 0)
        XCTAssertEqual(viewModel.saveState, .saved)
    }

    func test_coloringSession_essentialPaletteKeepsFastSwatchesReachable() throws {
        let template = try CanvasTestFixture.makeTemplate()
        let viewModel = ColoringSessionViewModel(
            project: Project(template: template),
            template: template,
            storageService: storage
        )

        XCTAssertEqual(viewModel.selectedPalette.name, "Essentials")
        XCTAssertTrue(viewModel.selectedSwatches.contains { $0.hex == SableTheme.progressPinkHex })
        XCTAssertTrue(viewModel.palettes.contains { $0.name == "Pastels" })
        XCTAssertEqual(ColoringSessionViewModel.SaveState.saving.label, "Saving...")
    }

    func test_allBundledTemplatesLoadInCanvasAndAcceptRepresentativeFill() async throws {
        let templates = Template.loadAll()
        XCTAssertFalse(templates.isEmpty)

        for template in templates {
            let viewModel = ColoringSessionViewModel(
                project: Project(template: template),
                template: template,
                storageService: storage
            )

            await viewModel.load()

            guard case .ready = viewModel.state else {
                XCTFail("\(template.name) did not load in Canvas: \(viewModel.state)")
                continue
            }

            guard let svgURL = template.svgURL,
                  case .success(let geometry) = SVGParser.parse(url: svgURL),
                  let point = CanvasTestFixture.representativeFillPoint(in: geometry) else {
                XCTFail("\(template.name) has no representative fillable region.")
                continue
            }

            let didFill = await viewModel.fill(atDocumentPoint: point)
            XCTAssertTrue(didFill, "\(template.name) should accept a tap fill at its representative fill point.")
            XCTAssertEqual(viewModel.filledRegionCount, 1, "\(template.name) should report one filled region.")
            XCTAssertEqual(viewModel.saveState, .dirty)
        }
    }

    private func representativeFillPoint() throws -> CGPoint {
        let geometry = try CanvasTestFixture.makeGeometry()
        return try XCTUnwrap(CanvasTestFixture.representativeFillPoint(in: geometry))
    }

    private func uniqueTemplate() throws -> Template {
        let base = try CanvasTestFixture.makeTemplate()
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
