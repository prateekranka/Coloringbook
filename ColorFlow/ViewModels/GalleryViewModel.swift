import Foundation
import SwiftUI
import Observation

struct OpenedProjectItem: Identifiable {
    let id = UUID()
    let project: Project
    let template: Template
}

@MainActor
@Observable
final class GalleryViewModel {
    var projects: [Project] = []
    var openedProject: OpenedProjectItem?

    private let storageService = StorageService()
    private let allTemplates: [Template]
    private var cachedSuggestions: [Template] = []

    init() {
        allTemplates = Template.loadAll()
        reload()
    }

    func reload() {
        let oldStartedIds = Set(projects.map(\.templateId))
        projects = storageService.loadAllProjects().sorted { $0.modifiedAt > $1.modifiedAt }
        let newStartedIds = Set(projects.map(\.templateId))
        if newStartedIds != oldStartedIds {
            cachedSuggestions = []
        }
    }

    func open(_ project: Project) {
        guard let template = allTemplates.first(where: { $0.id == project.templateId }) else { return }
        openedProject = OpenedProjectItem(project: project, template: template)
    }

    func delete(_ project: Project) {
        storageService.delete(project: project)
        projects.removeAll { $0.id == project.id }
    }

    /// Creates a new project from the given template and opens it immediately.
    func startProject(from template: Template) {
        let project = Project(template: template)
        openedProject = OpenedProjectItem(project: project, template: template)
        // Note: StorageService.save is called by CanvasViewModel on first auto-save.
        reload()
    }

    /// Open a user-generated template as a new project.
    func startProject(from userTemplate: UserTemplate) {
        startProject(from: userTemplate.asTemplate())
    }

    // MARK: - Home Screen Helpers

    /// The 6 most recently modified projects.
    var recentProjects: [Project] {
        Array(projects.prefix(6))
    }

    /// Up to 8 templates that don't yet have a project started.
    var suggestedTemplates: [Template] {
        if !cachedSuggestions.isEmpty {
            return cachedSuggestions
        }
        let startedTemplateIds = Set(projects.map(\.templateId))
        let unstarted = allTemplates.filter { !startedTemplateIds.contains($0.id) }
        cachedSuggestions = Array(unstarted.shuffled().prefix(8))
        return cachedSuggestions
    }

    // MARK: - My Work Stats

    var completedCount: Int {
        // Treat any project that has a fill layer as "started" — we have no explicit
        // "completed" flag yet, so count all projects as completed for now.
        projects.count
    }

    var inProgressCount: Int {
        // Placeholder: will differentiate once we add a project status field.
        0
    }
}
