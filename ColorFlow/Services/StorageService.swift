import UIKit
import PencilKit

/// Manages all persistence: project metadata (JSON), PKDrawing data, fill layer PNGs, and thumbnails.
class StorageService {

    // MARK: - URLs

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var projectsURL: URL {
        Self.documentsURL.appendingPathComponent("projects.json")
    }

    // MARK: - Project Metadata

    func loadAllProjects() -> [Project] {
        guard let data = try? Data(contentsOf: projectsURL),
              let projects = try? JSONDecoder().decode([Project].self, from: data) else {
            return []
        }
        return projects
    }

    private func saveProjectIndex(_ projects: [Project]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: projectsURL, options: .atomic)
    }

    // MARK: - Save

    func save(project: inout Project, drawing: PKDrawing, fillLayer: UIImage?) throws {
        project.modifiedAt = Date()

        // Ensure subdirectories exist
        createSubdirectories()

        // Save PKDrawing
        let drawingURL = Self.documentsURL.appendingPathComponent(project.drawingDataPath)
        let drawingData = drawing.dataRepresentation()
        try drawingData.write(to: drawingURL, options: .atomic)

        // Save fill layer PNG
        if let fill = fillLayer, let data = fill.pngData() {
            let fillURL = Self.documentsURL.appendingPathComponent(project.fillLayerPath)
            try data.write(to: fillURL, options: .atomic)
        }

        // Update index (non-critical — keep silent)
        var projects = loadAllProjects()
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        } else {
            projects.append(project)
        }
        saveProjectIndex(projects)
    }

    // MARK: - Load

    func loadDrawing(for project: Project) -> PKDrawing? {
        let url = Self.documentsURL.appendingPathComponent(project.drawingDataPath)
        guard let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else { return nil }
        return drawing
    }

    func loadFillLayer(for project: Project) -> UIImage? {
        let url = Self.documentsURL.appendingPathComponent(project.fillLayerPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    func delete(project: Project) {
        let docs = Self.documentsURL
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(project.drawingDataPath))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(project.fillLayerPath))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(project.thumbnailPath))

        var projects = loadAllProjects()
        projects.removeAll { $0.id == project.id }
        saveProjectIndex(projects)
    }

    // MARK: - Helpers

    private func createSubdirectories() {
        let fm = FileManager.default
        let docs = Self.documentsURL
        for sub in ["drawings", "fills", "thumbnails"] {
            try? fm.createDirectory(at: docs.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
    }
}
