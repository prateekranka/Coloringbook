import Observation

@MainActor
@Observable
final class TemplateListViewModel {
    enum Source: Hashable {
        case explore
        case collections
        case recentlyAdded
        case collection(PageCollection)
        case mood(MoodCategory)
        case search(String)

        var title: String {
            switch self {
            case .explore:
                return "Library"
            case .collections:
                return "Collections"
            case .recentlyAdded:
                return "Recently Added"
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
            case .collections:
                return "ALL COLLECTIONS"
            case .recentlyAdded:
                return "NEWEST FIRST"
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
    var collections: [PageCollection] = []
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
            collections = await repository.fetchCollections()
        case .collections:
            collections = await repository.fetchCollections()
            templates = []
        case .recentlyAdded:
            templates = await repository.fetchExploreTemplates()
                .sorted { lhs, rhs in
                    if lhs.addedSortIndex == rhs.addedSortIndex {
                        return lhs.name < rhs.name
                    }
                    return lhs.addedSortIndex > rhs.addedSortIndex
                }
            collections = []
        case .collection(let collection):
            templates = await repository.fetchTemplates(for: collection)
            collections = []
        case .mood(let mood):
            templates = await repository.fetchTemplates(for: mood)
            collections = []
        case .search:
            templates = await repository.fetchExploreTemplates()
            collections = []
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

    var showsCollectionIndex: Bool {
        if case .collections = source {
            return true
        }
        return false
    }

    var showsExploreCollections: Bool {
        if case .explore = source {
            return true
        }
        return false
    }

    var showsTemplateFilters: Bool {
        !showsCollectionIndex
    }
}
