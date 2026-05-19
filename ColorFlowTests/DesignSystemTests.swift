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
        XCTAssertEqual(pages.map(\.title), ["Rainy Library", "Lemon Balcony", "Wildflowers"])
        XCTAssertEqual(pages.map { Int(($0.progress * 100).rounded()) }, [72, 48, 31])

        let collections = await repository.fetchCollections()
        XCTAssertEqual(collections.map(\.name), ["Fresh Botanicals", "Sunlit Places", "Quiet Rooms", "Canopy Color"])
        XCTAssertEqual(collections.map(\.pageCount), [3, 3, 3, 1])
        XCTAssertEqual(collections.map(\.category), [.botanicals, .architecture, .lifestyle, .animals])

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
        XCTAssertEqual(viewModel.recentlyAddedPages.count, 8)
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
            title: "Wildflowers"
        )

        XCTAssertEqual(AppRoute.coloringPage(page).title, "Rainy Library")
        XCTAssertEqual(AppRoute.coloringPage(page).subtitle, "72% complete")
        XCTAssertEqual(AppRoute.collection(collection).title, "Fresh Botanicals")
        XCTAssertEqual(AppRoute.collection(collection).subtitle, "3 PAGES")
        XCTAssertEqual(AppRoute.mood(.noir).title, "NOIR")
        XCTAssertEqual(AppRoute.mood(.noir).subtitle, "Mood collection")
        XCTAssertEqual(AppRoute.canvas(canvasRoute).title, "Wildflowers")
        XCTAssertEqual(AppRoute.canvas(canvasRoute).subtitle, "Coloring canvas")
    }

    func test_sableRepository_mapsCollectionsToRealTemplates() async throws {
        let templates = [
            Template(
                id: UUID(uuidString: "33333333-0000-0000-0000-000000000101")!,
                name: "Lemon Branch",
                category: .botanicals,
                difficulty: .easy,
                svgFilename: "lemon-branch.svg",
                thumbnailFilename: "thumb-lemon-branch.png"
            ),
            Template(
                id: UUID(uuidString: "33333333-0000-0000-0000-000000000102")!,
                name: "Sunday Light",
                category: .lifestyle,
                difficulty: .medium,
                svgFilename: "sunday-light.svg",
                thumbnailFilename: "thumb-sunday-light.png"
            )
        ]
        let repository = SableHomeRepository(templates: templates)

        let collections = await repository.fetchCollections()
        let botanicals = try XCTUnwrap(collections.first { $0.name == "Fresh Botanicals" })
        let botanicalTemplates = await repository.fetchTemplates(for: botanicals)
        let exploreTemplates = await repository.fetchExploreTemplates()

        XCTAssertEqual(botanicals.pageCount, 1)
        XCTAssertEqual(botanicalTemplates.map(\.name), ["Lemon Branch"])
        XCTAssertEqual(exploreTemplates.map(\.name), ["Lemon Branch", "Sunday Light"])
    }

    func test_canonicalCollectionsDriveNamesCountsAndMembership() async throws {
        let repository = SableHomeRepository(templates: Template.loadAll())

        let collections = await repository.fetchCollections()

        XCTAssertEqual(collections.map(\.name), ["Fresh Botanicals", "Sunlit Places", "Quiet Rooms", "Canopy Color"])
        XCTAssertEqual(collections.map(\.pageCount), [3, 3, 3, 1])
        XCTAssertEqual(
            collections.map(\.templateFilenames),
            [
                ["wildflowers.svg", "lemon-branch.svg", "florist-window.svg"],
                ["amalfi-afternoon.svg", "lemon-balcony.svg", "mediterranean-kitchen-window.svg"],
                ["sunday-light.svg", "quiet-balcony-room.svg", "rainy-library.svg"],
                ["toucan-canopy.svg"]
            ]
        )

        for collection in collections {
            let templates = await repository.fetchTemplates(for: collection)
            XCTAssertEqual(templates.map(\.svgFilename), collection.templateFilenames)
            XCTAssertEqual(templates.count, collection.pageCount)
        }
    }

    func test_boldMoodIncludesBoldTemplateSet() async {
        let repository = SableHomeRepository(templates: Template.loadAll())

        let templates = await repository.fetchTemplates(for: .bold)

        XCTAssertTrue(
            Set(templates.map(\.svgFilename)).isSuperset(of: [
                "radiant-peaks.svg",
                "art-deco-bloom.svg",
                "compass-bloom.svg",
                "lion-crest.svg",
                "sunburst-bloom.svg",
                "lotus-crown.svg",
                "electric-starburst.svg"
            ])
        )
    }

    func test_templateListViewModel_loadsCollectionIndex() async {
        let viewModel = TemplateListViewModel(source: .collections, repository: MockHomeRepository())

        await viewModel.load()

        XCTAssertTrue(viewModel.showsCollectionIndex)
        XCTAssertEqual(viewModel.collections.map(\.name), ["Fresh Botanicals", "Sunlit Places", "Quiet Rooms", "Canopy Color"])
        XCTAssertTrue(viewModel.templates.isEmpty)
    }

    func test_templateListViewModel_exploreLoadsCollectionsAndAllTemplates() async {
        let viewModel = TemplateListViewModel(source: .explore, repository: MockHomeRepository())

        await viewModel.load()

        XCTAssertTrue(viewModel.showsExploreCollections)
        XCTAssertFalse(viewModel.showsCollectionIndex)
        XCTAssertEqual(viewModel.collections.map(\.name), ["Fresh Botanicals", "Sunlit Places", "Quiet Rooms", "Canopy Color"])
        XCTAssertEqual(viewModel.templates.count, Template.loadAll().count)
    }

    func test_templateListViewModel_sortsRecentlyAddedByCatalogOrderDescending() async {
        let viewModel = TemplateListViewModel(source: .recentlyAdded, repository: MockHomeRepository())

        await viewModel.load()

        XCTAssertEqual(
            viewModel.templates.map(\.name),
            [
                "Electric Starburst",
                "Lotus Crown",
                "Sunburst Bloom",
                "Lion Crest",
                "Compass Bloom",
                "Art Deco Bloom",
                "Radiant Peaks",
                "Florist Window",
                "Mediterranean Kitchen Window",
                "Rainy Library",
                "Quiet Balcony Room",
                "Lemon Balcony",
                "Toucan Canopy",
                "Amalfi Afternoon",
                "Sunday Light",
                "Lemon Branch",
                "Wildflowers"
            ]
        )
    }
}
