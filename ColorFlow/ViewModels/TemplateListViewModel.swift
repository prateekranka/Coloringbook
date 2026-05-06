import Observation

@MainActor
@Observable
final class TemplateListViewModel {
    enum Source: Hashable {
        case explore
        case collection(PageCollection)
        case mood(MoodCategory)

        var title: String {
            switch self {
            case .explore:
                return "Explore"
            case .collection(let collection):
                return collection.name
            case .mood(let mood):
                return mood.title
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
            }
        }
    }

    var isLoading = false
    var templates: [Template] = []

    let source: Source

    @ObservationIgnored private let repository: any ColoringFlowRepositoryProtocol
    @ObservationIgnored private var hasLoaded = false

    init(
        source: Source,
        repository: any ColoringFlowRepositoryProtocol = SableHomeRepository()
    ) {
        self.source = source
        self.repository = repository
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
}
