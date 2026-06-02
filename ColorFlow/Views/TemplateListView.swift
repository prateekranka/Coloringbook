import SwiftUI
import UIKit

@MainActor
struct TemplateListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: TemplateListViewModel
    let navigate: (AppRoute) -> Void
    let showAllTemplates: () -> Void

    init(
        source: TemplateListViewModel.Source,
        repository: any ColoringFlowRepositoryProtocol = SableHomeRepository(),
        navigate: @escaping (AppRoute) -> Void = { _ in },
        showAllTemplates: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: TemplateListViewModel(source: source, repository: repository))
        self.navigate = navigate
        self.showAllTemplates = showAllTemplates
    }

    init(
        viewModel: TemplateListViewModel,
        navigate: @escaping (AppRoute) -> Void = { _ in },
        showAllTemplates: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigate = navigate
        self.showAllTemplates = showAllTemplates
    }

    var body: some View {
        Group {
            if viewModel.source.isReferenceLibrary {
                LibraryReferenceView(
                    templates: viewModel.filteredTemplates,
                    pages: viewModel.filteredPages,
                    configuration: viewModel.source.referenceConfiguration,
                    isLoading: viewModel.isLoading,
                    onShowAllTemplates: viewModel.source.showsAllTemplatesReturn ? showAllTemplates : nil,
                    onSelectTemplate: openReferenceTemplate(_:),
                    onSelectPage: openReferencePage(_:)
                )
            } else {
                ZStack {
                    SableTheme.appBackground(for: colorScheme).ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: SableTheme.Spacing.xxxl) {
                            header
                            if viewModel.showsTemplateFilters {
                                GouacheSearchBar(text: $viewModel.searchText, placeholder: "Search by artwork, subject, mood")
                                filters
                            }

                            if viewModel.isLoading {
                                loading
                            } else if viewModel.showsCollectionIndex {
                                collectionGrid
                            } else {
                                if viewModel.showsExploreCollections {
                                    libraryCollectionsSection
                                }
                                templateGrid
                            }
                        }
                        .padding(.horizontal, SableTheme.Spacing.pageInset)
                        .padding(.top, SableTheme.Spacing.xxxl)
                        .padding(.bottom, 132)
                    }
                }
            }
        }
        .navigationTitle(viewModel.source.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
            Text(viewModel.source.title)
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(viewModel.source.subtitle)
                .font(SableTheme.Typography.bodySmall.weight(.black))
                .foregroundStyle(.white)
                .padding(.horizontal, SableTheme.Spacing.lg)
                .padding(.vertical, SableTheme.Spacing.xxs)
                .background(SableTheme.cardBlack, in: Capsule())
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SableTheme.Spacing.md) {
                filterButton("All difficulty", isSelected: viewModel.selectedDifficulty == nil) {
                    viewModel.selectedDifficulty = nil
                }

                ForEach(Difficulty.allCases) { difficulty in
                    filterButton(difficulty.displayTitle, isSelected: viewModel.selectedDifficulty == difficulty) {
                        viewModel.selectedDifficulty = difficulty
                    }
                }

                Divider()
                    .frame(height: 28)

                filterButton("All moods", isSelected: viewModel.selectedMood == nil) {
                    viewModel.selectedMood = nil
                }

                ForEach(TemplateMood.allCases) { mood in
                    filterButton(mood.title, isSelected: viewModel.selectedMood == mood) {
                        viewModel.selectedMood = mood
                    }
                }
            }
            .padding(.vertical, SableTheme.Spacing.xxxs)
        }
    }

    private var templateGrid: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.lg) {
            if viewModel.showsExploreCollections {
                sectionTitle("All Templates")
            }

            MasonryTemplateGrid(templates: viewModel.filteredTemplates) { template in
                Task {
                    let route = await viewModel.routeForTemplate(template)
                    navigate(route)
                }
            }
        }
        .accessibilityIdentifier("library.allTemplates")
    }

    private var libraryCollectionsSection: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.lg) {
            sectionTitle("Collections")

            LazyVGrid(columns: columns, spacing: SableTheme.Spacing.xxl) {
                ForEach(viewModel.collections) { collection in
                    LibraryCollectionCard(collection: collection) {
                        navigate(.collection(collection))
                    }
                }
            }
        }
        .accessibilityIdentifier("library.collections")
    }

    private var collectionGrid: some View {
        LazyVGrid(columns: columns, spacing: SableTheme.Spacing.xxl) {
            ForEach(viewModel.collections) { collection in
                LibraryCollectionCard(collection: collection) {
                    navigate(.collection(collection))
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(SableTheme.Typography.sectionTitle)
            .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
            .accessibilityIdentifier("library.section.\(title.normalizedIdentifier)")
    }

    private func filterButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SableTheme.Typography.labelMedium.weight(.bold))
                .foregroundStyle(isSelected ? .white : SableTheme.gouachePrimaryText(for: colorScheme))
                .padding(.horizontal, SableTheme.Spacing.lg)
                .frame(height: 34)
                .background(isSelected ? SableTheme.cardBlack : SableTheme.cardSurface(for: colorScheme), in: Capsule())
                .overlay {
                    Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                }
        }
        .buttonStyle(.plain)
    }

    private var loading: some View {
        ProgressView()
            .tint(SableTheme.progressPink)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 220, maximum: 330), spacing: SableTheme.Spacing.xxl)]
    }

    private func openReferenceTemplate(_ template: Template) {
        Task {
            let route = await viewModel.routeForTemplate(template)
            navigate(route)
        }
    }

    private func openReferencePage(_ page: ColoringPage) {
        navigate(.coloringPage(page))
    }
}

private extension TemplateListViewModel.Source {
    var isReferenceLibrary: Bool {
        switch self {
        case .explore, .inProgress, .recentlyAdded:
            return true
        default:
            return false
        }
    }

    var showsAllTemplatesReturn: Bool {
        if case .explore = self {
            return false
        }
        return isReferenceLibrary
    }

    var referenceConfiguration: LibraryReferenceConfiguration {
        switch self {
        case .explore:
            return .allTemplates
        case .inProgress:
            return .inProgress
        case .recentlyAdded:
            return .recentlyAdded
        default:
            return .allTemplates
        }
    }
}

private struct LibraryCollectionCard: View {
    let collection: PageCollection
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    if collection.previewTemplates.isEmpty {
                        PlaceholderArtwork(
                            tint: collection.category.accentColor,
                            seed: collection.name,
                            style: .compact
                        )
                    } else {
                        HStack(spacing: 0) {
                            ForEach(collection.previewTemplates.prefix(3)) { template in
                                TemplateThumbnailView(template: template)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            }
                        }
                    }
                }
                .aspectRatio(1.18, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
                    Text(collection.name)
                        .font(SableTheme.Typography.fraunces(20, weight: .black))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(collection.category.rawValue.uppercased())
                        .font(SableTheme.Typography.labelTiny)
                        .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SableTheme.Spacing.lg)
                .background(SableTheme.cardSurface(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                    .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(
                color: SableTheme.Shadow.card(for: colorScheme).color,
                radius: SableTheme.Shadow.card(for: colorScheme).radius,
                x: SableTheme.Shadow.card(for: colorScheme).x,
                y: SableTheme.Shadow.card(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(collection.name)
        .accessibilityIdentifier("library.collection.\(collection.name.normalizedIdentifier)")
    }
}

private struct MasonryTemplateGrid: View {
    let templates: [Template]
    let onTap: (Template) -> Void
    @State private var measuredHeight: CGFloat = 320

    var body: some View {
        GeometryReader { proxy in
            let columnCount = proxy.size.width > 980 ? 4 : (proxy.size.width > 640 ? 3 : 2)
            let columns = balancedColumns(count: columnCount, width: proxy.size.width)
            let height = gridHeight(columnCount: columnCount, width: proxy.size.width)

            HStack(alignment: .top, spacing: SableTheme.Spacing.xxl) {
                ForEach(columns.indices, id: \.self) { columnIndex in
                    LazyVStack(spacing: SableTheme.Spacing.xxl) {
                        ForEach(columns[columnIndex]) { template in
                            TemplateCard(template: template) {
                                onTap(template)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .onAppear {
                measuredHeight = height
            }
            .onChange(of: proxy.size.width) { _, _ in
                measuredHeight = height
            }
        }
        .frame(height: measuredHeight)
        .frame(minHeight: 320)
    }

    private func balancedColumns(count: Int, width: CGFloat) -> [[Template]] {
        var columns = Array(repeating: [Template](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)
        let columnWidth = (width - CGFloat(count - 1) * SableTheme.Spacing.xxl) / CGFloat(count)

        for template in templates {
            let index = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[index].append(template)
            heights[index] += estimatedHeight(for: template, columnWidth: columnWidth) + SableTheme.Spacing.xxl
        }

        return columns
    }

    private func gridHeight(columnCount: Int, width: CGFloat) -> CGFloat {
        let columns = balancedColumns(count: columnCount, width: width)
        let columnWidth = (width - CGFloat(columnCount - 1) * SableTheme.Spacing.xxl) / CGFloat(columnCount)
        return max(320, columns.map { column in
            column.reduce(CGFloat.zero) { $0 + estimatedHeight(for: $1, columnWidth: columnWidth) + SableTheme.Spacing.xxl }
        }.max() ?? 320)
    }

    private func estimatedHeight(for template: Template, columnWidth: CGFloat) -> CGFloat {
        let artworkHeight = columnWidth / CGFloat(max(0.64, min(1.85, template.displayAspectRatio)))
        return artworkHeight + 76
    }
}

private struct TemplateCard: View {
    let template: Template
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                TemplateThumbnailView(template: template)
                    .aspectRatio(template.displayAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
                    Text(template.name)
                        .font(SableTheme.Typography.fraunces(20, weight: .black))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    DifficultyPill(difficulty: template.difficulty)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SableTheme.Spacing.lg)
                .background(SableTheme.cardSurface(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(
                color: SableTheme.Shadow.cardSmall(for: colorScheme).color,
                radius: SableTheme.Shadow.cardSmall(for: colorScheme).radius,
                x: SableTheme.Shadow.cardSmall(for: colorScheme).x,
                y: SableTheme.Shadow.cardSmall(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
        .accessibilityIdentifier("template.\(template.name.normalizedIdentifier)")
    }
}

private struct TemplateThumbnailView: View {
    let template: Template
    @Environment(RenderTuningStore.self) private var renderTuning
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                SableTheme.paper

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PlaceholderArtwork(
                    tint: template.category.accentColor,
                    seed: template.name,
                    style: .compact
                )
            }
        }
        .clipped()
        .task(id: taskID) {
            image = nil
            image = await TemplateRenderer.thumbnail(
                for: template,
                strokeWidthPixels: CGFloat(renderTuning.thumbnailStrokeWidth)
            )
        }
    }

    private var taskID: TemplateThumbnailTaskID {
        TemplateThumbnailTaskID(
            templateID: template.id,
            strokeWidth: renderTuning.thumbnailStrokeWidth
        )
    }
}

private struct TemplateThumbnailTaskID: Hashable {
    let templateID: UUID
    let strokeWidth: Double
}

private extension TemplateCategory {
    var accentColor: Color {
        switch self {
        case .mandalas:
            return MoodCategory.dreamy.accentColor
        case .animals:
            return MoodCategory.wild.accentColor
        case .architecture:
            return MoodCategory.noir.accentColor
        case .abstract:
            return MoodCategory.bold.accentColor
        case .botanicals:
            return MoodCategory.calm.accentColor
        case .lifestyle:
            return MoodCategory.playful.accentColor
        }
    }
}

#Preview("Collection Templates") {
    NavigationStack {
        TemplateListView(
            source: .collection(MockHomeRepository.collections[1]),
            repository: MockHomeRepository()
        )
    }
    .environment(RenderTuningStore())
}

#Preview("Mood Templates") {
    NavigationStack {
        TemplateListView(
            source: .mood(.calm),
            repository: MockHomeRepository()
        )
    }
    .environment(RenderTuningStore())
}

#Preview("Explore Templates") {
    NavigationStack {
        TemplateListView(
            source: .explore,
            repository: MockHomeRepository()
        )
    }
    .environment(RenderTuningStore())
}
