import XCTest
import PencilKit
@testable import ColorFlow

final class StorageServiceTests: XCTestCase {

    // The service under test — uses the real documents directory.
    private var service: StorageService!

    // Projects created during each test; deleted in tearDown.
    private var createdProjects: [Project] = []

    override func setUp() {
        super.setUp()
        service = StorageService()
        createdProjects = []
    }

    override func tearDown() {
        for project in createdProjects {
            service.delete(project: project)
        }
        createdProjects = []
        super.tearDown()
    }

    // MARK: - Helpers

    private func freshProject() -> Project {
        let project = TestHelpers.makeProject()
        createdProjects.append(project)
        return project
    }

    private func saveProject(_ project: inout Project, drawing: PKDrawing = PKDrawing(), fillLayer: UIImage? = nil) {
        XCTAssertNoThrow(try service.save(project: &project, drawing: drawing, fillLayer: fillLayer))
        // Keep the updated (modifiedAt-stamped) copy so tearDown can delete it.
        let id = project.id
        if let idx = createdProjects.firstIndex(where: { $0.id == id }) {
            createdProjects[idx] = project
        }
    }

    // MARK: - loadAllProjects

    func test_loadAllProjects_afterCleanState_doesNotContainUnsavedProject() {
        let project = freshProject()
        let loaded = service.loadAllProjects()
        XCTAssertFalse(loaded.contains { $0.id == project.id },
                       "An unsaved project must not appear in the index")
    }

    // MARK: - save → loadAllProjects round-trip

    func test_saveAndLoad_projectAppearsInIndex() throws {
        var project = freshProject()
        saveProject(&project)

        let loaded = service.loadAllProjects()
        XCTAssertTrue(loaded.contains { $0.id == project.id },
                      "Project must appear in index after save")
    }

    func test_saveAndLoad_multipleProjects_allAppearInIndex() throws {
        var p1 = freshProject()
        var p2 = freshProject()
        saveProject(&p1)
        saveProject(&p2)

        let loaded = service.loadAllProjects()
        XCTAssertTrue(loaded.contains { $0.id == p1.id }, "First project must be in index")
        XCTAssertTrue(loaded.contains { $0.id == p2.id }, "Second project must be in index")
    }

    // MARK: - save creates subdirectories

    func test_save_createsDrawingsSubdirectory() throws {
        var project = freshProject()
        saveProject(&project)

        let drawingsDir = StorageService.documentsURL.appendingPathComponent("drawings")
        XCTAssertTrue(FileManager.default.fileExists(atPath: drawingsDir.path),
                      "save() must create the 'drawings' subdirectory")
    }

    func test_save_createsFillsSubdirectory() throws {
        var project = freshProject()
        saveProject(&project)

        let fillsDir = StorageService.documentsURL.appendingPathComponent("fills")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fillsDir.path),
                      "save() must create the 'fills' subdirectory")
    }

    func test_save_createsThumbnailsSubdirectory() throws {
        var project = freshProject()
        saveProject(&project)

        let thumbsDir = StorageService.documentsURL.appendingPathComponent("thumbnails")
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbsDir.path),
                      "save() must create the 'thumbnails' subdirectory")
    }

    // MARK: - save updates modifiedAt

    func test_save_updatesModifiedAt() throws {
        var project = freshProject()
        let before = project.modifiedAt

        // Small sleep so timestamps differ; save() calls Date() internally.
        Thread.sleep(forTimeInterval: 0.05)
        saveProject(&project)

        XCTAssertGreaterThan(project.modifiedAt, before,
                             "save() must update modifiedAt to a later timestamp")
    }

    // MARK: - saving same project twice doesn't duplicate in index

    func test_saveSameProjectTwice_doesNotDuplicate() throws {
        var project = freshProject()
        saveProject(&project)
        saveProject(&project)

        let loaded = service.loadAllProjects()
        let matches = loaded.filter { $0.id == project.id }
        XCTAssertEqual(matches.count, 1, "Saving the same project twice must not create duplicates")
    }

    // MARK: - loadDrawing

    func test_loadDrawing_afterSave_returnsNonNilDrawing() throws {
        var project = freshProject()
        saveProject(&project, drawing: PKDrawing())

        let drawing = service.loadDrawing(for: project)
        XCTAssertNotNil(drawing, "loadDrawing must return a drawing after save")
    }

    func test_loadDrawing_forUnsavedProject_returnsNil() {
        let project = freshProject()  // registered for cleanup but never saved
        let drawing = service.loadDrawing(for: project)
        XCTAssertNil(drawing, "loadDrawing must return nil for a project that was never saved")
    }

    // MARK: - loadFillLayer

    func test_loadFillLayer_afterSaveWithImage_returnsNonNilImage() throws {
        var project = freshProject()
        let fillImage = makeTestImage(size: CGSize(width: 10, height: 10), color: .red)
        saveProject(&project, drawing: PKDrawing(), fillLayer: fillImage)

        let loaded = service.loadFillLayer(for: project)
        XCTAssertNotNil(loaded, "loadFillLayer must return an image when one was saved")
    }

    func test_loadFillLayer_afterSaveWithoutImage_returnsNil() throws {
        var project = freshProject()
        saveProject(&project, drawing: PKDrawing(), fillLayer: nil)

        let loaded = service.loadFillLayer(for: project)
        XCTAssertNil(loaded, "loadFillLayer must return nil when no fill layer was saved")
    }

    // MARK: - delete removes from index

    func test_delete_removesProjectFromIndex() throws {
        var project = freshProject()
        saveProject(&project)

        service.delete(project: project)
        // Remove from tearDown list since we already deleted it.
        createdProjects.removeAll { $0.id == project.id }

        let loaded = service.loadAllProjects()
        XCTAssertFalse(loaded.contains { $0.id == project.id },
                       "delete() must remove the project from the index")
    }

    // MARK: - delete removes files

    func test_delete_removesDrawingFile() throws {
        var project = freshProject()
        saveProject(&project)

        let drawingURL = StorageService.documentsURL.appendingPathComponent(project.drawingDataPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: drawingURL.path),
                      "Drawing file must exist before delete")

        service.delete(project: project)
        createdProjects.removeAll { $0.id == project.id }

        XCTAssertFalse(FileManager.default.fileExists(atPath: drawingURL.path),
                       "delete() must remove the drawing file")
    }

    func test_delete_removesFillLayerFile() throws {
        var project = freshProject()
        let fillImage = makeTestImage(size: CGSize(width: 10, height: 10), color: .blue)
        saveProject(&project, drawing: PKDrawing(), fillLayer: fillImage)

        let fillURL = StorageService.documentsURL.appendingPathComponent(project.fillLayerPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fillURL.path),
                      "Fill layer file must exist before delete")

        service.delete(project: project)
        createdProjects.removeAll { $0.id == project.id }

        XCTAssertFalse(FileManager.default.fileExists(atPath: fillURL.path),
                       "delete() must remove the fill layer file")
    }

    // MARK: - rename updates name

    func test_rename_updatesTemplateName() throws {
        var project = freshProject()
        saveProject(&project)

        service.renameProject(id: project.id, to: "My Renamed Project")

        let loaded = service.loadAllProjects()
        let updated = loaded.first { $0.id == project.id }
        XCTAssertEqual(updated?.templateName, "My Renamed Project",
                       "renameProject must update templateName in the index")
    }

    // MARK: - rename updates modifiedAt

    func test_rename_updatesModifiedAt() throws {
        var project = freshProject()
        saveProject(&project)

        let beforeRename = service.loadAllProjects().first(where: { $0.id == project.id })?.modifiedAt
        XCTAssertNotNil(beforeRename)

        Thread.sleep(forTimeInterval: 0.05)
        service.renameProject(id: project.id, to: "Another Name")

        let afterRename = service.loadAllProjects().first(where: { $0.id == project.id })?.modifiedAt
        XCTAssertNotNil(afterRename)
        XCTAssertGreaterThan(afterRename!, beforeRename!,
                             "renameProject must update modifiedAt to a later timestamp")
    }

    // MARK: - rename unknown ID is a no-op

    func test_rename_unknownID_doesNotCrashOrCorruptIndex() {
        var p = freshProject()
        saveProject(&p)
        let countBefore = service.loadAllProjects().count

        service.renameProject(id: UUID(), to: "Ghost")

        let countAfter = service.loadAllProjects().count
        XCTAssertEqual(countBefore, countAfter,
                       "renameProject with an unknown ID must not alter the project count")
    }

    // MARK: - Utility

    private func makeTestImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
