import Foundation
import Observation

@MainActor
@Observable
final class TemplateLibraryViewModel {
    var templates: [Template] = []
    var selectedCategory: TemplateCategory? = nil
    var userTemplates: [UserTemplate] = []

    private let storage = StorageService()

    var filteredTemplates: [Template] {
        guard let category = selectedCategory else { return templates }
        return templates.filter { $0.category == category }
    }

    init() {
        templates = Template.loadAll()
        userTemplates = storage.loadUserTemplates()
    }

    /// Triggers a remote manifest refetch; awaits the result and rebinds
    /// `templates` so pull-to-refresh feels snappy.
    func refreshRemoteCatalogue() async {
        await ContentService.shared.fetchManifest()
        templates = Template.loadAll()
    }

    func reloadUserTemplates() {
        userTemplates = storage.loadUserTemplates()
    }

    func deleteUserTemplate(_ template: UserTemplate) {
        storage.deleteUserTemplate(template)
        userTemplates.removeAll { $0.id == template.id }
    }
}
