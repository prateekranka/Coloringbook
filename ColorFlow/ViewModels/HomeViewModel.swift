import Observation

@MainActor
@Observable
final class HomeViewModel {
    var isLoading = false
    var continuePages: [ColoringPage] = []
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
        libraryPages = await repository.fetchLibraryPages()
        collections = await repository.fetchCollections()
        moods = await repository.fetchMoodCategories()

        isLoading = false
        hasLoaded = true
    }

    static var previewLoaded: HomeViewModel {
        let viewModel = HomeViewModel(repository: MockHomeRepository())
        viewModel.continuePages = MockHomeRepository.continuePages
        viewModel.libraryPages = MockHomeRepository.continuePages
        viewModel.collections = MockHomeRepository.collections
        viewModel.moods = MockHomeRepository.moodCategories
        viewModel.hasLoaded = true
        return viewModel
    }

    static var previewLoading: HomeViewModel {
        let viewModel = HomeViewModel(repository: MockHomeRepository())
        viewModel.isLoading = true
        viewModel.hasLoaded = true
        return viewModel
    }
}
