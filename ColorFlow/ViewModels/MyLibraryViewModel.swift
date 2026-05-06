import Observation

@MainActor
@Observable
final class MyLibraryViewModel {
    var isLoading = false
    var pages: [ColoringPage] = []

    @ObservationIgnored private let repository: any HomeRepositoryProtocol

    init(repository: any HomeRepositoryProtocol = SableHomeRepository()) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        pages = await repository.fetchLibraryPages()
        isLoading = false
    }

    static var previewLoaded: MyLibraryViewModel {
        let viewModel = MyLibraryViewModel(repository: MockHomeRepository())
        viewModel.pages = MockHomeRepository.continuePages
        return viewModel
    }
}
