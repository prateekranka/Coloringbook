import Foundation
import SwiftUI

struct OpenedProjectItem: Identifiable {
    let id = UUID()
    let project: Project
    let template: Template
}

@MainActor
class GalleryViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var openedProject: OpenedProjectItem?

    private let storageService = StorageService()
    private let allTemplates: [Template]

    init() {
        allTemplates = Template.loadAll()
        reload()
    }

    func reload() {
        projects = storageService.loadAllProjects().sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func open(_ project: Project) {
        guard let template = allTemplates.first(where: { $0.id == project.templateId }) else { return }
        openedProject = OpenedProjectItem(project: project, template: template)
    }

    func delete(_ project: Project) {
        HapticService.shared.impact(.medium)
        storageService.delete(project: project)
        projects.removeAll { $0.id == project.id }
    }

    func rename(_ project: Project, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        storageService.renameProject(id: project.id, to: trimmed)
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].templateName = trimmed
        }
    }

    /// Creates a new project from the given template and opens it immediately.
    func startProject(from template: Template) {
        let project = Project(template: template)
        openedProject = OpenedProjectItem(project: project, template: template)
        // Note: StorageService.save is called by CanvasViewModel on first auto-save.
        reload()
    }

    // MARK: - Home Screen Helpers

    /// The 6 most recently modified projects.
    var recentProjects: [Project] {
        Array(projects.prefix(6))
    }

    /// Up to 8 templates that don't yet have a project started.
    var suggestedTemplates: [Template] {
        let startedTemplateIds = Set(projects.map(\.templateId))
        let unstarted = allTemplates.filter { !startedTemplateIds.contains($0.id) }
        // Shuffle so suggestions feel fresh across launches.
        return Array(unstarted.shuffled().prefix(8))
    }

}
