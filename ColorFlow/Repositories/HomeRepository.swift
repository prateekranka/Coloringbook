import Foundation

protocol HomeRepositoryProtocol {
    func fetchContinuePages() async -> [ColoringPage]
    func fetchLibraryPages() async -> [ColoringPage]
    func fetchCollections() async -> [PageCollection]
    func fetchMoodCategories() async -> [MoodCategory]
}

protocol ColoringFlowRepositoryProtocol {
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

    func fetchLibraryPages() async -> [ColoringPage] {
        storageService.loadAllProjects()
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map(coloringPage)
    }

    func fetchCollections() async -> [PageCollection] {
        [
            makeCollection(name: "Koi Serenity", category: .animals),
            makeCollection(name: "Botanical Bold", category: .botanicals),
            makeCollection(name: "Wanderlust", category: .lifestyle),
            makeCollection(name: "Architectural Beauty", category: .architecture)
        ]
    }

    func fetchMoodCategories() async -> [MoodCategory] {
        MoodCategory.allCases
    }

    func fetchTemplates(for collection: PageCollection) async -> [Template] {
        templates
            .filter { $0.category == collection.category }
            .sorted { $0.name < $1.name }
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

    private func makeCollection(name: String, category: TemplateCategory) -> PageCollection {
        PageCollection(
            name: name,
            category: category,
            pageCount: templates.filter { $0.category == category }.count
        )
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
            title: project.templateName,
            progress: project.completionPercentage,
            thumbnailColorHex: accentHex(for: template?.category),
            thumbnailPath: project.thumbnailPath,
            fillLayerPath: project.fillLayerPath
        )
    }
}

struct MockHomeRepository: HomeRepositoryProtocol {
    static let continuePages = [
        ColoringPage(title: "Majestic Tiger", progress: 0.72, thumbnailColorHex: "#E8611A"),
        ColoringPage(title: "Ocean Explorer", progress: 0.48, thumbnailColorHex: "#2BBCB3"),
        ColoringPage(title: "Secret Garden", progress: 0.31, thumbnailColorHex: "#E91E84")
    ]

    static let collections = [
        PageCollection(name: "Koi Serenity", category: .animals, pageCount: 32),
        PageCollection(name: "Botanical Bold", category: .botanicals, pageCount: 45),
        PageCollection(name: "Wanderlust", category: .lifestyle, pageCount: 28),
        PageCollection(name: "Architectural Beauty", category: .architecture, pageCount: 36)
    ]

    static let moodCategories = MoodCategory.allCases

    func fetchContinuePages() async -> [ColoringPage] {
        Self.continuePages
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
    func fetchTemplates(for collection: PageCollection) async -> [Template] {
        Template.loadAll()
            .filter { $0.category == collection.category }
            .sorted { $0.name < $1.name }
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
