import Observation

@MainActor
@Observable
final class TemplateListViewModel {
    enum Source: Hashable {
        case explore
        case collection(PageCollection)
        case mood(MoodCategory)
        case search(String)

        var title: String {
            switch self {
            case .explore:
                return "Library"
            case .collection(let collection):
                return collection.name
            case .mood(let mood):
                return mood.title
            case .search:
                return "Search"
            }
        }

        var subtitle: String {
            switch self {
            case .explore:
                return "ALL TEMPLATES"
            case .collection(let collection):
                return collection.pageCountLabel
            case .mood:
                return "MOOD COLLECTION"
            case .search(let query):
                return query.isEmpty ? "ALL RESULTS" : "RESULTS FOR \(query.uppercased())"
            }
        }
    }

    var isLoading = false
    var templates: [Template] = []
    var searchText = ""
    var selectedDifficulty: Difficulty?
    var selectedMood: TemplateMood?

    let source: Source

    @ObservationIgnored private let repository: any ColoringFlowRepositoryProtocol
    @ObservationIgnored private var hasLoaded = false

    init(
        source: Source,
        repository: any ColoringFlowRepositoryProtocol = SableHomeRepository()
    ) {
        self.source = source
        self.repository = repository
        if case .search(let query) = source {
            self.searchText = query
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        isLoading = true
        switch source {
        case .explore:
            templates = await repository.fetchExploreTemplates()
        case .collection(let collection):
            templates = await repository.fetchTemplates(for: collection)
        case .mood(let mood):
            templates = await repository.fetchTemplates(for: mood)
        case .search:
            templates = await repository.fetchExploreTemplates()
        }
        isLoading = false
        hasLoaded = true
    }

    func routeForTemplate(_ template: Template) async -> AppRoute {
        let project = await repository.openOrCreateProject(for: template)
        return .canvas(
            CanvasRoute(
                projectId: project.id,
                templateId: template.id,
                title: template.name
            )
        )
    }

    var filteredTemplates: [Template] {
        templates.filter { template in
            let matchesSearch = searchText.isEmpty
                || template.name.localizedCaseInsensitiveContains(searchText)
                || template.category.rawValue.localizedCaseInsensitiveContains(searchText)
                || template.difficulty.displayTitle.localizedCaseInsensitiveContains(searchText)
                || template.svgFilename.localizedCaseInsensitiveContains(searchText)
            let matchesDifficulty = selectedDifficulty.map { template.difficulty == $0 } ?? true
            let matchesMood = selectedMood.map { $0.includes(template: template) } ?? true
            return matchesSearch && matchesDifficulty && matchesMood
        }
    }
}
