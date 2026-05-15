import Foundation

struct PageCollection: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: TemplateCategory
    let pageCount: Int
    let templateFilenames: [String]
    let previewTemplates: [Template]

    init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory,
        pageCount: Int,
        templateFilenames: [String] = [],
        previewTemplates: [Template] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.pageCount = pageCount
        self.templateFilenames = templateFilenames
        self.previewTemplates = previewTemplates
    }

    var pageCountLabel: String {
        "\(pageCount) PAGES"
    }
}
