import Foundation

protocol HomeRepositoryProtocol {
    func fetchContinuePages() async -> [ColoringPage]
    func fetchRecentlyAddedPages() async -> [ColoringPage]
    func fetchLibraryPages() async -> [ColoringPage]
    func fetchCollections() async -> [PageCollection]
    func fetchMoodCategories() async -> [MoodCategory]
}

protocol ColoringFlowRepositoryProtocol {
    func fetchExploreTemplates() async -> [Template]
    func fetchCollections() async -> [PageCollection]
    func fetchTemplates(for collection: PageCollection) async -> [Template]
    func fetchTemplates(for mood: MoodCategory) async -> [Template]
    func openOrCreateProject(for template: Template) async -> Project
    func resolveProject(projectId: UUID?, templateId: UUID?) async -> (project: Project, template: Template)?
}

struct SableHomeRepository: HomeRepositoryProtocol, ColoringFlowRepositoryProtocol {
    private let storageService: StorageService
    private let templates: [Template]

    init(
        storageService: StorageService = StorageService(),
        templates: [Template] = Template.loadAll()
    ) {
        self.storageService = storageService
        self.templates = templates
    }

    func fetchContinuePages() async -> [ColoringPage] {
        storageService.loadAllProjects()
            .filter { $0.status != .completed }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(6)
            .map(coloringPage)
    }

    func fetchRecentlyAddedPages() async -> [ColoringPage] {
        templates
            .sorted { lhs, rhs in
                if lhs.addedSortIndex == rhs.addedSortIndex {
                    return lhs.name < rhs.name
                }
                return lhs.addedSortIndex > rhs.addedSortIndex
            }
            .prefix(8)
            .map(coloringPage)
    }

    func fetchLibraryPages() async -> [ColoringPage] {
        storageService.loadAllProjects()
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map(coloringPage)
    }

    func fetchCollections() async -> [PageCollection] {
        TemplateCollectionCatalog.collections(from: templates)
    }

    func fetchMoodCategories() async -> [MoodCategory] {
        MoodCategory.allCases
    }

    func fetchExploreTemplates() async -> [Template] {
        templates.sorted { $0.name < $1.name }
    }

    func fetchTemplates(for collection: PageCollection) async -> [Template] {
        TemplateCollectionCatalog.templates(for: collection, in: templates)
    }

    func fetchTemplates(for mood: MoodCategory) async -> [Template] {
        templates
            .filter { mood.includes(template: $0) }
            .sorted { $0.name < $1.name }
    }

    func openOrCreateProject(for template: Template) async -> Project {
        storageService.openOrCreateProject(for: template)
    }

    func resolveProject(projectId: UUID?, templateId: UUID?) async -> (project: Project, template: Template)? {
        if let projectId,
           let project = storageService.loadProject(id: projectId),
           let template = templates.first(where: { $0.id == project.templateId }) {
            return (project, template)
        }

        if let templateId,
           let template = templates.first(where: { $0.id == templateId }) {
            let project = storageService.openOrCreateProject(for: template)
            return (project, template)
        }

        return nil
    }

    private func accentHex(for category: TemplateCategory?) -> String {
        switch category {
        case .animals:
            return MoodCategory.wild.accentHex
        case .architecture:
            return MoodCategory.noir.accentHex
        case .abstract:
            return MoodCategory.bold.accentHex
        case .botanicals:
            return MoodCategory.calm.accentHex
        case .lifestyle:
            return MoodCategory.playful.accentHex
        case .mandalas:
            return MoodCategory.dreamy.accentHex
        case nil:
            return SableTheme.progressPinkHex
        }
    }

    private func coloringPage(for project: Project) -> ColoringPage {
        let template = templates.first { $0.id == project.templateId }
        return ColoringPage(
            id: project.id,
            projectId: project.id,
            templateId: project.templateId,
            title: template?.name ?? project.templateName,
            progress: completionProgress(for: project, template: template),
            thumbnailColorHex: accentHex(for: template?.category),
            thumbnailPath: project.thumbnailPath,
            fillLayerPath: project.fillLayerPath
        )
    }

    private func coloringPage(for template: Template) -> ColoringPage {
        ColoringPage(
            id: template.id,
            templateId: template.id,
            title: template.name,
            progress: 0,
            thumbnailColorHex: accentHex(for: template.category)
        )
    }

    private func completionProgress(for project: Project, template: Template?) -> Double {
        let storedProgress = project.completionPercentage
        let paintState = storageService.loadPaintState(for: project)
        guard !paintState.regionFills.isEmpty,
              let template,
              let url = template.svgURL,
              case .success(let geometry) = SVGParser.parse(url: url),
              !geometry.regions.isEmpty else {
            return storedProgress
        }

        let paintStateProgress = Double(paintState.regionFills.count) / Double(geometry.regions.count)
        return min(max(max(storedProgress, paintStateProgress), 0), 1)
    }

}

struct MockHomeRepository: HomeRepositoryProtocol {
    static let continuePages = [
        ColoringPage(title: "Rainy Library", progress: 0.72, thumbnailColorHex: "#E8611A"),
        ColoringPage(title: "Lemon Balcony", progress: 0.48, thumbnailColorHex: "#2BBCB3"),
        ColoringPage(title: "Wildflowers", progress: 0.31, thumbnailColorHex: "#E91E84")
    ]

    static let collections = TemplateCollectionCatalog.collections(from: Template.loadAll())

    static let moodCategories = MoodCategory.allCases

    func fetchContinuePages() async -> [ColoringPage] {
        Self.continuePages
    }

    func fetchRecentlyAddedPages() async -> [ColoringPage] {
        Template.loadAll()
            .sorted { $0.addedSortIndex > $1.addedSortIndex }
            .prefix(8)
            .map {
                ColoringPage(
                    id: $0.id,
                    templateId: $0.id,
                    title: $0.name,
                    progress: 0,
                    thumbnailColorHex: $0.category.accentHex
                )
            }
    }

    func fetchLibraryPages() async -> [ColoringPage] {
        Self.continuePages
    }

    func fetchCollections() async -> [PageCollection] {
        Self.collections
    }

    func fetchMoodCategories() async -> [MoodCategory] {
        Self.moodCategories
    }
}

extension MockHomeRepository: ColoringFlowRepositoryProtocol {
    func fetchExploreTemplates() async -> [Template] {
        Template.loadAll().sorted { $0.name < $1.name }
    }

    func fetchTemplates(for collection: PageCollection) async -> [Template] {
        TemplateCollectionCatalog.templates(for: collection, in: Template.loadAll())
    }

    func fetchTemplates(for mood: MoodCategory) async -> [Template] {
        Template.loadAll()
            .filter { mood.includes(template: $0) }
            .sorted { $0.name < $1.name }
    }

    func openOrCreateProject(for template: Template) async -> Project {
        Project(template: template)
    }

    func resolveProject(projectId: UUID?, templateId: UUID?) async -> (project: Project, template: Template)? {
        guard let template = Template.loadAll().first(where: { $0.id == templateId }) ?? Template.loadAll().first else {
            return nil
        }
        return (Project(template: template), template)
    }
}

private extension TemplateCategory {
    var accentHex: String {
        switch self {
        case .animals:
            return MoodCategory.wild.accentHex
        case .architecture:
            return MoodCategory.noir.accentHex
        case .abstract:
            return MoodCategory.bold.accentHex
        case .botanicals:
            return MoodCategory.calm.accentHex
        case .lifestyle:
            return MoodCategory.playful.accentHex
        case .mandalas:
            return MoodCategory.dreamy.accentHex
        }
    }
}

extension MoodCategory {
    func includes(template: Template) -> Bool {
        switch self {
        case .calm:
            return template.category == .mandalas || template.category == .botanicals
        case .bold:
            return template.category == .abstract || template.difficulty == .hard
        case .playful:
            return template.category == .animals || template.difficulty == .easy
        case .dreamy:
            return template.category == .lifestyle || template.category == .mandalas
        case .wild:
            return template.category == .animals || template.name.localizedCaseInsensitiveContains("wild")
        case .noir:
            return template.category == .architecture || template.category == .abstract
        }
    }
}
