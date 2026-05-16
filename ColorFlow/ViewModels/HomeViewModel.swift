import Observation

@MainActor
@Observable
final class HomeViewModel {
    var isLoading = false
    var continuePages: [ColoringPage] = []
    var recentlyAddedPages: [ColoringPage] = []
    var libraryPages: [ColoringPage] = []
    var collections: [PageCollection] = []
    var moods: [MoodCategory] = []

    @ObservationIgnored private let repository: any HomeRepositoryProtocol
    @ObservationIgnored private var hasLoaded = false

    init(repository: any HomeRepositoryProtocol = MockHomeRepository()) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        isLoading = true

        continuePages = await repository.fetchContinuePages()
        recentlyAddedPages = await repository.fetchRecentlyAddedPages()
        libraryPages = await repository.fetchLibraryPages()
        collections = await repository.fetchCollections()
        moods = await repository.fetchMoodCategories()

        isLoading = false
        hasLoaded = true
    }

    static var previewLoaded: HomeViewModel {
        let viewModel = HomeViewModel(repository: MockHomeRepository())
        viewModel.continuePages = MockHomeRepository.continuePages
        viewModel.recentlyAddedPages = awaitPreviewRecentlyAdded()
        viewModel.libraryPages = MockHomeRepository.continuePages
        viewModel.collections = MockHomeRepository.collections
        viewModel.moods = MockHomeRepository.moodCategories
        viewModel.hasLoaded = true
        return viewModel
    }

    private static func awaitPreviewRecentlyAdded() -> [ColoringPage] {
        Template.loadAll()
            .sorted { $0.addedSortIndex > $1.addedSortIndex }
            .prefix(8)
            .map {
                ColoringPage(
                    id: $0.id,
                    templateId: $0.id,
                    title: $0.name,
                    progress: 0,
                    thumbnailColorHex: SableTheme.progressPinkHex
                )
            }
    }

    static var previewLoading: HomeViewModel {
        let viewModel = HomeViewModel(repository: MockHomeRepository())
        viewModel.isLoading = true
        viewModel.hasLoaded = true
        return viewModel
    }
}
