import Foundation
import Combine

class TemplateLibraryViewModel: ObservableObject {
    @Published var templates: [Template] = []
    @Published var selectedCategory: TemplateCategory? = nil

    var filteredTemplates: [Template] {
        guard let category = selectedCategory else { return templates }
        return templates.filter { $0.category == category }
    }

    init() {
        templates = Template.loadAll()
    }
}
