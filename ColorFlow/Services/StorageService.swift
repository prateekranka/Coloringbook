import UIKit
import PencilKit

/// Manages all persistence: project metadata (JSON), PKDrawing data, fill layer PNGs, and thumbnails.
/// Also manages user-generated templates (Documents/UserTemplates/).
class StorageService {

    /// Serial queue that serializes all file I/O and index mutations, preventing
    /// concurrent writes from corrupting projects.json or user_templates.json.
    private let queue = DispatchQueue(label: "com.colorflow.storage")

    // MARK: - URLs

    /// Resolves to the iCloud ubiquity container's `Documents/` subdirectory
    /// when available, otherwise the local `~/Documents`. `CloudStorage`
    /// decides at launch; path logic elsewhere doesn't need to branch.
    static var documentsURL: URL {
        CloudStorage.shared.documentsURL
    }

    private static var usingICloud: Bool {
        CloudStorage.shared.isUsingICloud
    }

    private var projectsURL: URL {
        Self.documentsURL.appendingPathComponent("projects.json")
    }

    private var userTemplatesIndexURL: URL {
        Self.documentsURL.appendingPathComponent("user_templates.json")
    }

    // MARK: - Project Metadata

    func loadAllProjects() -> [Project] {
        queue.sync { _loadAllProjects() }
    }

    private func _loadAllProjects() -> [Project] {
        var indexed: [Project] = []
        if let data = try? Data(contentsOf: projectsURL),
           let projects = try? JSONDecoder().decode([Project].self, from: data) {
            indexed = projects
        }

        // Also scan per-project manifests. Merged in on top of the index so a
        // freshly-synced-from-iCloud project shows up even if the aggregate
        // index file hasn't synced yet. Index entries are authoritative when
        // both exist (their `modifiedAt` is updated on save).
        let projectsDir = Self.documentsURL.appendingPathComponent("projects", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(at: projectsDir,
                                                                          includingPropertiesForKeys: nil) else {
            return indexed
        }
        var merged = indexed
        for dir in contents where dir.hasDirectoryPath {
            let manifest = dir.appendingPathComponent("project.json")
            guard let data = try? Data(contentsOf: manifest),
                  let project = try? JSONDecoder().decode(Project.self, from: data) else { continue }
            if !merged.contains(where: { $0.id == project.id }) {
                merged.append(project)
            }
        }
        return merged
    }

    private func saveProjectIndex(_ projects: [Project]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        coordinatedWrite(data, to: projectsURL)
    }

    /// Emits `Documents/projects/<id>/project.json` alongside the aggregate
    /// index. Cheap insurance against iCloud delivering artwork files before
    /// the index file has synced.
    private func writePerProjectManifest(_ project: Project) {
        let dir = Self.documentsURL.appendingPathComponent("projects/\(project.id.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(project) else { return }
        coordinatedWrite(data, to: dir.appendingPathComponent("project.json"))
    }

    /// `NSFileCoordinator`-wrapped write. No-op if `documentsURL` is local;
    /// the coordinator still works correctly there so the call is always safe.
    private func coordinatedWrite(_ data: Data, to url: URL) {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
            do {
                try data.write(to: writeURL, options: .atomic)
            } catch {
                AppLog.error(AppLog.storage, "coordinatedWrite failed at \(writeURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            AppLog.error(AppLog.storage, "coordinator error for \(url.lastPathComponent): \(coordinatorError.localizedDescription)")
        }
    }

    // MARK: - Save

    func save(project: inout Project, drawing: PKDrawing, fillLayer: UIImage?) {
        project.modifiedAt = Date()
        let snapshot = project
        let drawingData = drawing.dataRepresentation()
        let fillData = fillLayer?.pngData()

        queue.sync {
            createSubdirectories()

            let drawingURL = Self.documentsURL.appendingPathComponent(snapshot.drawingDataPath)
            coordinatedWrite(drawingData, to: drawingURL)

            if let data = fillData {
                let fillURL = Self.documentsURL.appendingPathComponent(snapshot.fillLayerPath)
                coordinatedWrite(data, to: fillURL)
            }

            var projects = _loadAllProjects()
            if let idx = projects.firstIndex(where: { $0.id == snapshot.id }) {
                projects[idx] = snapshot
            } else {
                projects.append(snapshot)
            }
            saveProjectIndex(projects)
            // Per-project manifest — lets iCloud sync expose each project
            // independently, so a device can hydrate state even before the
            // aggregate `projects.json` index has finished downloading.
            writePerProjectManifest(snapshot)
        }
    }

    // MARK: - Load

    func loadDrawing(for project: Project) -> PKDrawing? {
        queue.sync {
            let url = Self.documentsURL.appendingPathComponent(project.drawingDataPath)
            guard let data = try? Data(contentsOf: url),
                  let drawing = try? PKDrawing(data: data) else { return nil }
            return drawing
        }
    }

    func loadFillLayer(for project: Project) -> UIImage? {
        queue.sync {
            let url = Self.documentsURL.appendingPathComponent(project.fillLayerPath)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }

    // MARK: - Delete

    func delete(project: Project) {
        queue.sync {
            let docs = Self.documentsURL
            coordinatedRemove(docs.appendingPathComponent(project.drawingDataPath))
            coordinatedRemove(docs.appendingPathComponent(project.fillLayerPath))
            coordinatedRemove(docs.appendingPathComponent(project.thumbnailPath))
            coordinatedRemove(docs.appendingPathComponent("projects/\(project.id.uuidString)"))

            var projects = _loadAllProjects()
            projects.removeAll { $0.id == project.id }
            saveProjectIndex(projects)
        }
    }

    private func coordinatedRemove(_ url: URL) {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { writeURL in
            try? FileManager.default.removeItem(at: writeURL)
        }
    }

    // MARK: - Helpers

    private func createSubdirectories() {
        let fm = FileManager.default
        let docs = Self.documentsURL
        for sub in ["drawings", "fills", "thumbnails"] {
            try? fm.createDirectory(at: docs.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
    }

    // MARK: - User Template Persistence

    /// Save a user-generated template atomically.
    ///
    /// Directory layout:
    /// ```
    /// Documents/UserTemplates/<id>/
    ///   template.svg      ← SVG line art
    ///   thumbnail.png     ← 400×400 preview
    /// Documents/user_templates.json   ← index
    /// ```
    func saveUserTemplate(_ template: UserTemplate, svgString: String, thumbnail: UIImage?) throws {
        let thumbnailData = thumbnail?.pngData()
        var thrownError: Error?

        queue.sync {
            let fm   = FileManager.default
            let docs = Self.documentsURL
            let dir  = docs.appendingPathComponent(template.directoryPath)

            do {
                // Write to a staging directory, then rename atomically.
                // Ensure the UserTemplates root exists before creating the staging subdirectory.
                try fm.createDirectory(
                    at: docs.appendingPathComponent("UserTemplates"),
                    withIntermediateDirectories: true
                )
                let staging = docs.appendingPathComponent("UserTemplates/.staging-\(template.id.uuidString)")
                try fm.createDirectory(at: staging, withIntermediateDirectories: true)

                // Write SVG
                let svgURL = staging.appendingPathComponent(template.svgFilename)
                try svgString.write(to: svgURL, atomically: false, encoding: .utf8)

                // Write thumbnail
                if let data = thumbnailData {
                    try data.write(to: staging.appendingPathComponent(template.thumbnailFilename))
                }

                // Atomic rename: remove any prior version, then move staging into place.
                if fm.fileExists(atPath: dir.path) {
                    try fm.removeItem(at: dir)
                }
                try fm.moveItem(at: staging, to: dir)

                // Update index
                var templates = _loadUserTemplates()
                if let idx = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[idx] = template
                } else {
                    templates.append(template)
                }
                saveUserTemplateIndex(templates)
            } catch {
                thrownError = error
            }
        }

        if let error = thrownError { throw error }
    }

    func loadUserTemplates() -> [UserTemplate] {
        queue.sync { _loadUserTemplates() }
    }

    private func _loadUserTemplates() -> [UserTemplate] {
        guard let data = try? Data(contentsOf: userTemplatesIndexURL),
              let templates = try? JSONDecoder().decode([UserTemplate].self, from: data) else {
            return []
        }
        // Filter out entries whose directory was deleted externally.
        return templates.filter { t in
            FileManager.default.fileExists(
                atPath: Self.documentsURL.appendingPathComponent(t.directoryPath).path
            )
        }
    }

    func deleteUserTemplate(_ template: UserTemplate) {
        queue.sync {
            let dir = Self.documentsURL.appendingPathComponent(template.directoryPath)
            try? FileManager.default.removeItem(at: dir)

            var templates = _loadUserTemplates()
            templates.removeAll { $0.id == template.id }
            saveUserTemplateIndex(templates)
        }
    }

    private func saveUserTemplateIndex(_ templates: [UserTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        try? data.write(to: userTemplatesIndexURL, options: .atomic)
    }
}
