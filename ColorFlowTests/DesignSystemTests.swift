import SwiftUI
import XCTest
@testable import ColorFlow

@MainActor
final class DesignSystemTests: XCTestCase {
    func test_sableTheme_hexTokens_matchMockup() {
        XCTAssertEqual(SableTheme.creamHex, "#F5F0EB")
        XCTAssertEqual(SableTheme.crimsonHex, "#D4213D")
        XCTAssertEqual(SableTheme.progressPinkHex, "#FF2D78")

        let _: Color = SableTheme.cream
        let _: Color = SableTheme.crimson
        let _: Color = SableTheme.progressPink
    }

    func test_moodCategory_accentColors_matchSpecification() {
        XCTAssertEqual(MoodCategory.calm.accentHex, "#2BBCB3")
        XCTAssertEqual(MoodCategory.bold.accentHex, "#E91E84")
        XCTAssertEqual(MoodCategory.playful.accentHex, "#F5C518")
        XCTAssertEqual(MoodCategory.dreamy.accentHex, "#7B68AE")
        XCTAssertEqual(MoodCategory.wild.accentHex, "#E8611A")
        XCTAssertEqual(MoodCategory.noir.accentHex, "#8B1A1A")
    }

    func test_mockRepository_returnsSableHomeData() async {
        let repository = MockHomeRepository()

        let pages = await repository.fetchContinuePages()
        XCTAssertEqual(pages.map(\.title), ["Majestic Tiger", "Ocean Explorer", "Secret Garden"])
        XCTAssertEqual(pages.map { Int(($0.progress * 100).rounded()) }, [72, 48, 31])

        let collections = await repository.fetchCollections()
        XCTAssertEqual(collections.map(\.name), ["Koi Serenity", "Botanical Bold", "Wanderlust", "Architectural Beauty"])
        XCTAssertEqual(collections.map(\.pageCount), [32, 45, 28, 36])
        XCTAssertEqual(collections.map(\.category), [.animals, .botanicals, .lifestyle, .architecture])

        let moods = await repository.fetchMoodCategories()
        XCTAssertEqual(moods, [.calm, .bold, .playful, .dreamy, .wild, .noir])

        let exploreTemplates = await repository.fetchExploreTemplates()
        XCTAssertFalse(exploreTemplates.isEmpty)
        XCTAssertEqual(exploreTemplates, exploreTemplates.sorted { $0.name < $1.name })
    }

    func test_homeViewModel_loadsDataThroughRepository() async {
        let viewModel = HomeViewModel(repository: MockHomeRepository())

        XCTAssertFalse(viewModel.isLoading)
        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.continuePages.count, 3)
        XCTAssertEqual(viewModel.libraryPages.count, 3)
        XCTAssertEqual(viewModel.collections.count, 4)
        XCTAssertEqual(viewModel.moods.count, 6)
    }

    func test_appRoutes_exposeDestinationTitles() {
        let page = MockHomeRepository.continuePages[0]
        let collection = MockHomeRepository.collections[0]
        let canvasRoute = CanvasRoute(
            projectId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            templateId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Lotus Mandala"
        )

        XCTAssertEqual(AppRoute.coloringPage(page).title, "Majestic Tiger")
        XCTAssertEqual(AppRoute.coloringPage(page).subtitle, "72% complete")
        XCTAssertEqual(AppRoute.collection(collection).title, "Koi Serenity")
        XCTAssertEqual(AppRoute.collection(collection).subtitle, "32 PAGES")
        XCTAssertEqual(AppRoute.mood(.noir).title, "NOIR")
        XCTAssertEqual(AppRoute.mood(.noir).subtitle, "Mood collection")
        XCTAssertEqual(AppRoute.canvas(canvasRoute).title, "Lotus Mandala")
        XCTAssertEqual(AppRoute.canvas(canvasRoute).subtitle, "Coloring canvas")
    }

    func test_sableRepository_mapsCollectionsToRealTemplates() async throws {
        let templates = [
            Template(
                id: UUID(uuidString: "33333333-0000-0000-0000-000000000101")!,
                name: "Leaf Study",
                category: .botanicals,
                difficulty: .easy,
                svgFilename: "tropical_leaves.svg",
                thumbnailFilename: "thumb_tropical_leaves.png"
            ),
            Template(
                id: UUID(uuidString: "33333333-0000-0000-0000-000000000102")!,
                name: "Stone House",
                category: .architecture,
                difficulty: .hard,
                svgFilename: "victorian_house.svg",
                thumbnailFilename: "thumb_victorian_house.png"
            )
        ]
        let repository = SableHomeRepository(templates: templates)

        let collections = await repository.fetchCollections()
        let botanicals = try XCTUnwrap(collections.first { $0.name == "Botanical Bold" })
        let botanicalTemplates = await repository.fetchTemplates(for: botanicals)
        let exploreTemplates = await repository.fetchExploreTemplates()

        XCTAssertEqual(botanicals.pageCount, 1)
        XCTAssertEqual(botanicalTemplates.map(\.name), ["Leaf Study"])
        XCTAssertEqual(exploreTemplates.map(\.name), ["Leaf Study", "Stone House"])
    }
}
