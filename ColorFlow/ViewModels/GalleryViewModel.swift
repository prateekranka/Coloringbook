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
        storageService.delete(project: project)
        projects.removeAll { $0.id == project.id }
    }
}
