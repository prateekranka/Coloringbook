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

enum TemplateCollectionCatalog {
    struct Definition: Hashable {
        let id: UUID
        let name: String
        let category: TemplateCategory
        let templateFilenames: [String]
    }

    static let definitions: [Definition] = [
        Definition(
            id: UUID(uuidString: "44444444-0000-0000-0000-000000000101")!,
            name: "Fresh Botanicals",
            category: .botanicals,
            templateFilenames: ["wildflowers.svg", "lemon-branch.svg", "florist-window.svg"]
        ),
        Definition(
            id: UUID(uuidString: "44444444-0000-0000-0000-000000000102")!,
            name: "Sunlit Places",
            category: .architecture,
            templateFilenames: ["amalfi-afternoon.svg", "lemon-balcony.svg", "mediterranean-kitchen-window.svg"]
        ),
        Definition(
            id: UUID(uuidString: "44444444-0000-0000-0000-000000000103")!,
            name: "Quiet Rooms",
            category: .lifestyle,
            templateFilenames: ["sunday-light.svg", "quiet-balcony-room.svg", "rainy-library.svg"]
        ),
        Definition(
            id: UUID(uuidString: "44444444-0000-0000-0000-000000000104")!,
            name: "Canopy Color",
            category: .animals,
            templateFilenames: ["toucan-canopy.svg"]
        )
    ]

    static func collections(from allTemplates: [Template]) -> [PageCollection] {
        definitions.map { definition in
            let collectionTemplates = templates(for: definition, in: allTemplates)
            return PageCollection(
                id: definition.id,
                name: definition.name,
                category: definition.category,
                pageCount: collectionTemplates.count,
                templateFilenames: definition.templateFilenames,
                previewTemplates: Array(collectionTemplates.prefix(3))
            )
        }
    }

    static func templates(for collection: PageCollection, in templates: [Template]) -> [Template] {
        let filenames = collection.templateFilenames.isEmpty
            ? definitions.first { $0.id == collection.id || $0.name == collection.name }?.templateFilenames ?? []
            : collection.templateFilenames

        guard !filenames.isEmpty else {
            return templates
                .filter { $0.category == collection.category }
                .sorted { $0.name < $1.name }
        }

        return filenames.compactMap { filename in
            templates.first { $0.svgFilename == filename }
        }
    }

    private static func templates(for definition: Definition, in templates: [Template]) -> [Template] {
        definition.templateFilenames.compactMap { filename in
            templates.first { $0.svgFilename == filename }
        }
    }
}
