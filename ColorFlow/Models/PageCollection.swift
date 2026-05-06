import Foundation

struct PageCollection: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: TemplateCategory
    let pageCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory,
        pageCount: Int
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.pageCount = pageCount
    }

    var pageCountLabel: String {
        "\(pageCount) PAGES"
    }
}
