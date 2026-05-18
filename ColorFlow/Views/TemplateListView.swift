import SwiftUI
import UIKit

@MainActor
struct TemplateListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: TemplateListViewModel
    let navigate: (AppRoute) -> Void

    init(
        source: TemplateListViewModel.Source,
        repository: any ColoringFlowRepositoryProtocol = SableHomeRepository(),
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: TemplateListViewModel(source: source, repository: repository))
        self.navigate = navigate
    }

    init(
        viewModel: TemplateListViewModel,
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigate = navigate
    }

    var body: some View {
        ZStack {
            SableTheme.appBackground(for: colorScheme).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
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
                .padding(.top, 28)
                .padding(.bottom, 132)
            }
        }
        .navigationTitle(viewModel.source.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.source.title)
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(viewModel.source.subtitle)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(SableTheme.cardBlack, in: Capsule())
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
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
            .padding(.vertical, 2)
        }
    }

    private var templateGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
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
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Collections")

            LazyVGrid(columns: columns, spacing: 18) {
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
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(viewModel.collections) { collection in
                LibraryCollectionCard(collection: collection) {
                    navigate(.collection(collection))
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 25, weight: .black))
            .foregroundStyle(SableTheme.primaryText(for: colorScheme))
            .accessibilityIdentifier("library.section.\(title.normalizedIdentifier)")
    }

    private func filterButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? .white : SableTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(isSelected ? SableTheme.cardBlack : SableTheme.elevatedSurface(for: colorScheme), in: Capsule())
                .overlay {
                    Capsule().stroke(SableTheme.hairline(for: colorScheme), lineWidth: 1)
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
        [GridItem(.adaptive(minimum: 220, maximum: 330), spacing: 18)]
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

                VStack(alignment: .leading, spacing: 7) {
                    Text(collection.name)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(collection.category.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(SableTheme.elevatedSurface(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                    .stroke(SableTheme.hairline(for: colorScheme), lineWidth: 1)
            }
            .shadow(color: SableTheme.cardShadow, radius: 8, x: 0, y: 5)
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

            HStack(alignment: .top, spacing: 18) {
                ForEach(columns.indices, id: \.self) { columnIndex in
                    LazyVStack(spacing: 18) {
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
        let columnWidth = (width - CGFloat(count - 1) * 18) / CGFloat(count)

        for template in templates {
            let index = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[index].append(template)
            heights[index] += estimatedHeight(for: template, columnWidth: columnWidth) + 18
        }

        return columns
    }

    private func gridHeight(columnCount: Int, width: CGFloat) -> CGFloat {
        let columns = balancedColumns(count: columnCount, width: width)
        let columnWidth = (width - CGFloat(columnCount - 1) * 18) / CGFloat(columnCount)
        return max(320, columns.map { column in
            column.reduce(CGFloat.zero) { $0 + estimatedHeight(for: $1, columnWidth: columnWidth) + 18 }
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

                VStack(alignment: .leading, spacing: 7) {
                    Text(template.name)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(template.category.rawValue.uppercased())
                        DifficultyPill(difficulty: template.difficulty)
                    }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(SableTheme.elevatedSurface(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(color: SableTheme.cardShadow, radius: 8, x: 0, y: 5)
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
