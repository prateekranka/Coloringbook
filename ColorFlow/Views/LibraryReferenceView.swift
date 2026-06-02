import SwiftUI
import UIKit

struct LibraryReferenceConfiguration {
    let title: String
    let sectionTitle: String
    let sectionSubtitle: String
    let searchPlaceholder: String
    let emptyTitle: String
    let emptySubtitle: String
    let showsTemplateFilters: Bool
    let usesProjectCards: Bool

    static let allTemplates = LibraryReferenceConfiguration(
        title: "Library",
        sectionTitle: "All Templates",
        sectionSubtitle: "Explore templates from our collection.",
        searchPlaceholder: "Search",
        emptyTitle: "No templates found",
        emptySubtitle: "Try a different search.",
        showsTemplateFilters: true,
        usesProjectCards: false
    )

    static let inProgress = LibraryReferenceConfiguration(
        title: "Continue Coloring",
        sectionTitle: "In Progress",
        sectionSubtitle: "Templates sorted by when you last worked on them.",
        searchPlaceholder: "Search saved work",
        emptyTitle: "No saved colorings yet",
        emptySubtitle: "Start a template and it will appear here.",
        showsTemplateFilters: false,
        usesProjectCards: true
    )

    static let recentlyAdded = LibraryReferenceConfiguration(
        title: "Recently Added",
        sectionTitle: "Newest Templates",
        sectionSubtitle: "Templates sorted by date added.",
        searchPlaceholder: "Search new templates",
        emptyTitle: "No templates found",
        emptySubtitle: "Try a different search.",
        showsTemplateFilters: false,
        usesProjectCards: false
    )
}

struct LibraryReferenceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFilter: LibraryReferenceFilter = .all
    @State private var selectedSketchbook: PageCollection?
    @State private var isSearchExpanded = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    let templates: [Template]
    let pages: [ColoringPage]
    let configuration: LibraryReferenceConfiguration
    let isLoading: Bool
    let onShowAllTemplates: (() -> Void)?
    let onSelectTemplate: (Template) -> Void
    let onSelectPage: (ColoringPage) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = LibraryReferenceMetrics(size: proxy.size)
            let displayedTemplates = self.displayedTemplates
            let displayedPages = self.displayedPages
            let displayedSketchbooks = self.displayedSketchbooks
            let showsSketchbookIndex = self.showsSketchbookIndex
            let isContentEmpty = showsSketchbookIndex
                ? displayedSketchbooks.isEmpty
                : displayedTemplates.isEmpty && displayedPages.isEmpty
            let contentItemCount = showsSketchbookIndex
                ? displayedSketchbooks.count
                : max(displayedTemplates.count, displayedPages.count)

            ZStack(alignment: .top) {
                pageBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        libraryBackground(metrics: metrics)

                        header(metrics: metrics)
                            .offset(x: metrics.titleX, y: metrics.titleY)
                            .zIndex(2)

                        filterControls
                            .offset(x: metrics.filtersX, y: metrics.filtersY)
                            .zIndex(2)

                        searchControl(metrics: metrics)
                            .offset(x: metrics.searchX(isExpanded: isSearchExpanded), y: metrics.searchY)
                            .zIndex(2)

                        sectionHeader(metrics: metrics)
                            .offset(x: metrics.sectionX, y: metrics.sectionY)
                            .zIndex(2)

                        if isLoading && templates.isEmpty {
                            ProgressView()
                                .tint(SableTheme.progressPink)
                                .frame(width: metrics.gridWidth, height: 260)
                                .offset(x: metrics.gridX, y: metrics.gridY)
                                .zIndex(1)
                        } else if isContentEmpty {
                            emptyState
                                .frame(width: metrics.gridWidth, height: 240)
                                .offset(x: metrics.gridX, y: metrics.gridY)
                                .zIndex(1)
                        } else if configuration.usesProjectCards {
                            LibraryReferenceProjectGrid(
                                pages: displayedPages,
                                columnCount: metrics.columnCount,
                                gridGap: metrics.gridGap,
                                onTap: onSelectPage
                            )
                            .frame(width: metrics.gridWidth)
                            .offset(x: metrics.gridX, y: metrics.gridY)
                            .zIndex(1)
                        } else if showsSketchbookIndex {
                            LibraryReferenceSketchbookGrid(
                                collections: displayedSketchbooks,
                                columnCount: metrics.sketchbookColumnCount,
                                gridGap: metrics.gridGap,
                                onTap: selectSketchbook
                            )
                            .frame(width: metrics.gridWidth)
                            .offset(x: metrics.gridX, y: metrics.gridY)
                            .zIndex(1)
                        } else {
                            LibraryReferenceMasonryGrid(
                                templates: displayedTemplates,
                                columnCount: metrics.columnCount,
                                gridGap: metrics.gridGap,
                                onTap: onSelectTemplate
                            )
                            .frame(width: metrics.gridWidth)
                            .offset(x: metrics.gridX, y: metrics.gridY)
                            .zIndex(1)
                        }
                    }
                    .frame(
                        width: proxy.size.width,
                        height: metrics.contentHeight(for: contentItemCount),
                        alignment: .topLeading
                    )
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .accessibilityIdentifier("library.reference")
    }

    private func libraryBackground(metrics: LibraryReferenceMetrics) -> some View {
        Image(colorScheme == .dark ? "LibraryHeroBackgroundDark" : "LibraryHeroBackgroundLight")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: metrics.size.width, height: metrics.backgroundFrameHeight, alignment: .top)
            .clipped()
            .opacity(0.96)
            .overlay {
                LinearGradient(
                    colors: [
                        pageBackground.opacity(0.58),
                        .clear,
                        .clear,
                        pageBackground.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .offset(x: 0, y: metrics.backgroundY(for: colorScheme))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func header(metrics: LibraryReferenceMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.headerSpacing) {
            Text("Gouache")
                .font(SableTheme.Typography.fraunces(metrics.brandSize, weight: .regular))
                .foregroundStyle(primaryText)

            Text(configuration.title)
                .font(SableTheme.Typography.fraunces(metrics.titleSize, weight: .regular))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .shadow(color: metrics.headerShadowColor(for: colorScheme), radius: metrics.headerShadowRadius, x: 0, y: 1)
    }

    private func sectionHeader(metrics: LibraryReferenceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(sectionTitle)
                    .font(SableTheme.Typography.fraunces(metrics.sectionTitleSize, weight: .regular))
                    .foregroundStyle(primaryText)

                if selectedSketchbook != nil {
                    Button(action: showAllSketchbooks) {
                        Text("All Sketchbooks")
                            .font(SableTheme.Typography.chip.weight(.semibold))
                            .foregroundStyle(primaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(unselectedFilterFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library.sketchbooks.all")
                }
            }

            Text(sectionSubtitle)
                .font(.system(size: metrics.subtitleSize, weight: .regular))
                .foregroundStyle(secondaryText)
        }
    }

    private func searchControl(metrics: LibraryReferenceMetrics) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(SableTheme.Motion.searchExpand) {
                    isSearchExpanded = true
                }
                isSearchFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: metrics.searchIconSize, weight: .regular))
                    .foregroundStyle(primaryText)
                    .frame(width: isSearchExpanded ? 34 : metrics.searchButtonSize, height: isSearchExpanded ? 34 : metrics.searchButtonSize)
            }
            .buttonStyle(.plain)

            if isSearchExpanded {
                TextField(configuration.searchPlaceholder, text: $searchText)
                    .font(.system(size: 13, weight: .semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                Button {
                    withAnimation(SableTheme.Motion.searchExpand) {
                        searchText = ""
                        isSearchExpanded = false
                    }
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, isSearchExpanded ? 8 : 0)
        .frame(width: isSearchExpanded ? metrics.searchExpandedWidth : metrics.searchButtonSize, height: metrics.searchButtonSize)
        .background(searchFill, in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }

    private func hero(metrics: LibraryReferenceMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            Image(colorScheme == .dark ? "LibraryHeroBackgroundDark" : "LibraryHeroBackgroundLight")
                .resizable()
                .scaledToFill()
                .frame(width: metrics.size.width, height: metrics.heroHeight)
                .clipped()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.58),
                            .init(color: .black.opacity(0.72), location: 0.78),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, pageBackground.opacity(0.92), pageBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: metrics.heroHeight * 0.42)
                }
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: metrics.headerSpacing) {
                Text("Gouache")
                    .font(SableTheme.Typography.fraunces(metrics.brandSize, weight: .regular))
                    .foregroundStyle(primaryText)

                Text("Library")
                    .font(SableTheme.Typography.fraunces(metrics.titleSize, weight: .regular))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                HStack(spacing: 12) {
                    ForEach(LibraryReferenceFilter.allCases) { filter in
                        filterButton(filter)
                    }
                }
            }
            .padding(.leading, metrics.horizontalInset)
            .padding(.top, metrics.topInset)

            Button(action: {}) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: metrics.searchIconSize, weight: .regular))
                    .foregroundStyle(primaryText)
                    .frame(width: metrics.searchButtonSize, height: metrics.searchButtonSize)
                    .background(searchFill, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, metrics.topInset + 4)
            .padding(.trailing, metrics.horizontalInset)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("Search")
        }
        .frame(height: metrics.heroHeight)
    }

    private func filterButton(_ filter: LibraryReferenceFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(SableTheme.Motion.searchExpand) {
                selectedFilter = filter
                selectedSketchbook = nil
            }
        } label: {
            Text(filter.title)
                .font(SableTheme.Typography.chip.weight(.semibold))
                .foregroundStyle(isSelected ? selectedFilterText : primaryText)
                .padding(.horizontal, filter == .all ? 18 : 20)
                .frame(height: 30)
                .background(isSelected ? selectedFilterFill : unselectedFilterFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.filter.\(filter.title.normalizedIdentifier)")
    }

    private var filterControls: some View {
        HStack(spacing: 12) {
            if let onShowAllTemplates {
                Button(action: onShowAllTemplates) {
                    Label("All Templates", systemImage: "square.grid.2x2")
                        .font(SableTheme.Typography.chip.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 16)
                        .frame(height: 30)
                        .background(unselectedFilterFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.filter.allTemplates")
            }

            if configuration.showsTemplateFilters {
                ForEach(LibraryReferenceFilter.allCases) { filter in
                    filterButton(filter)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(emptyTitle)
                .font(SableTheme.Typography.fraunces(22, weight: .semibold))
                .foregroundStyle(primaryText)

            Text(emptySubtitle)
                .font(SableTheme.Typography.bodySmall)
                .foregroundStyle(secondaryText)

            HStack(spacing: 10) {
                if hasSearchQuery {
                    emptyActionButton("Clear Search", systemImage: "xmark.circle", action: clearSearch)
                }

                if selectedSketchbook != nil {
                    emptyActionButton("All Sketchbooks", systemImage: "books.vertical", action: showAllSketchbooks)
                } else if selectedFilter == .sketchbooks {
                    emptyActionButton("All Templates", systemImage: "square.grid.2x2", action: showAllTemplateGrid)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func emptyActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(SableTheme.Typography.chip.weight(.semibold))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 13)
                .frame(height: 30)
                .background(unselectedFilterFill, in: Capsule())
                .overlay {
                    Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.empty.\(title.normalizedIdentifier)")
    }

    private func templatesSection(metrics: LibraryReferenceMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionGap) {
            VStack(alignment: .leading, spacing: 4) {
                Text("All Templates")
                    .font(SableTheme.Typography.fraunces(metrics.sectionTitleSize, weight: .regular))
                    .foregroundStyle(primaryText)

                Text("Explore templates from our collection.")
                    .font(.system(size: metrics.subtitleSize, weight: .regular))
                    .foregroundStyle(secondaryText)
            }

            if isLoading && templates.isEmpty {
                ProgressView()
                    .tint(SableTheme.progressPink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
            } else {
                LibraryReferenceMasonryGrid(
                    templates: displayedTemplates,
                    columnCount: metrics.columnCount,
                    gridGap: metrics.gridGap,
                    onTap: onSelectTemplate
                )
            }
        }
        .padding(.horizontal, metrics.horizontalInset)
        .padding(.top, metrics.sectionTopOffset)
    }

    private var displayedTemplates: [Template] {
        let base: [Template]
        switch selectedFilter {
        case .all:
            base = templates
        case .sketchbooks:
            guard let selectedSketchbook else { return [] }
            base = TemplateCollectionCatalog.templates(for: selectedSketchbook, in: templates)
        }

        guard hasSearchQuery else { return base }
        return base.filter { templateMatchesSearch($0) }
    }

    private var displayedPages: [ColoringPage] {
        guard hasSearchQuery else { return pages }
        return pages.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var displayedSketchbooks: [PageCollection] {
        let collections = TemplateCollectionCatalog.collections(from: templates)
            .filter { $0.pageCount > 0 }

        guard hasSearchQuery else { return collections }
        return collections.filter { collection in
            collection.name.localizedCaseInsensitiveContains(searchQuery)
                || collection.category.rawValue.localizedCaseInsensitiveContains(searchQuery)
                || collection.pageCountLabel.localizedCaseInsensitiveContains(searchQuery)
                || TemplateCollectionCatalog.templates(for: collection, in: templates).contains { templateMatchesSearch($0) }
        }
    }

    private var showsSketchbookIndex: Bool {
        configuration.showsTemplateFilters && selectedFilter == .sketchbooks && selectedSketchbook == nil
    }

    private var sectionTitle: String {
        guard configuration.showsTemplateFilters else { return configuration.sectionTitle }

        switch selectedFilter {
        case .all:
            return configuration.sectionTitle
        case .sketchbooks:
            return selectedSketchbook?.name ?? "Sketchbooks"
        }
    }

    private var sectionSubtitle: String {
        guard configuration.showsTemplateFilters else { return configuration.sectionSubtitle }

        switch selectedFilter {
        case .all:
            return configuration.sectionSubtitle
        case .sketchbooks:
            if let selectedSketchbook {
                return "\(selectedSketchbook.pageCount) pages in this sketchbook."
            }
            return "Curated sets for choosing a mood and pace."
        }
    }

    private var emptyTitle: String {
        if hasSearchQuery {
            return "No matches for \"\(searchQuery)\""
        }

        if selectedFilter == .sketchbooks {
            return selectedSketchbook == nil ? "No sketchbooks found" : "No pages found"
        }

        return configuration.emptyTitle
    }

    private var emptySubtitle: String {
        if hasSearchQuery {
            return selectedFilter == .sketchbooks
                ? "Clear the search or return to the full library."
                : "Clear the search to return to the full library."
        }

        if selectedFilter == .sketchbooks {
            return selectedSketchbook == nil
                ? "Switch back to all templates."
                : "Return to the sketchbook index."
        }

        return configuration.emptySubtitle
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchQuery: Bool {
        !searchQuery.isEmpty
    }

    private func templateMatchesSearch(_ template: Template) -> Bool {
        template.name.localizedCaseInsensitiveContains(searchQuery)
            || template.category.rawValue.localizedCaseInsensitiveContains(searchQuery)
            || template.difficulty.displayTitle.localizedCaseInsensitiveContains(searchQuery)
            || template.svgFilename.localizedCaseInsensitiveContains(searchQuery)
    }

    private func selectSketchbook(_ collection: PageCollection) {
        withAnimation(SableTheme.Motion.searchExpand) {
            selectedSketchbook = collection
            searchText = ""
        }
        isSearchFocused = false
    }

    private func clearSearch() {
        withAnimation(SableTheme.Motion.searchExpand) {
            searchText = ""
        }
        isSearchFocused = false
    }

    private func showAllSketchbooks() {
        withAnimation(SableTheme.Motion.searchExpand) {
            selectedFilter = .sketchbooks
            selectedSketchbook = nil
            searchText = ""
        }
        isSearchFocused = false
    }

    private func showAllTemplateGrid() {
        withAnimation(SableTheme.Motion.searchExpand) {
            selectedFilter = .all
            selectedSketchbook = nil
            searchText = ""
        }
        isSearchFocused = false
    }

    private var pageBackground: Color {
        SableTheme.gouacheBackground(for: colorScheme)
    }

    private var primaryText: Color {
        SableTheme.gouachePrimaryText(for: colorScheme)
    }

    private var secondaryText: Color {
        SableTheme.gouacheSecondaryText(for: colorScheme)
    }

    private var searchFill: Color {
        colorScheme == .dark ? SableTheme.searchFillDark : SableTheme.searchFillLight
    }

    private var selectedFilterFill: Color {
        colorScheme == .dark ? Color(hex: "#F2E1CA") : Color(hex: "#26231F")
    }

    private var selectedFilterText: Color {
        colorScheme == .dark ? Color(hex: "#141514") : .white
    }

    private var unselectedFilterFill: Color {
        colorScheme == .dark ? Color(hex: "#2B2924").opacity(0.82) : Color(hex: "#E9DDCB").opacity(0.76)
    }
}

private struct LibraryReferenceMasonryGrid: View {
    let templates: [Template]
    let columnCount: Int
    let gridGap: CGFloat
    let onTap: (Template) -> Void
    @State private var measuredHeight: CGFloat = 320

    var body: some View {
        GeometryReader { proxy in
            let columns = balancedColumns(width: proxy.size.width)
            let height = gridHeight(width: proxy.size.width)

            HStack(alignment: .top, spacing: gridGap) {
                ForEach(columns.indices, id: \.self) { columnIndex in
                    LazyVStack(spacing: gridGap) {
                        ForEach(columns[columnIndex]) { template in
                            LibraryReferenceTemplateCard(template: template) {
                                onTap(template)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height, alignment: .top)
            .onAppear {
                measuredHeight = height
            }
            .onChange(of: proxy.size.width) { _, _ in
                measuredHeight = height
            }
            .onChange(of: templates) { _, _ in
                measuredHeight = height
            }
        }
        .frame(height: measuredHeight)
        .frame(minHeight: 320)
    }

    private func balancedColumns(width: CGFloat) -> [[Template]] {
        var columns = Array(repeating: [Template](), count: max(columnCount, 1))
        var heights = Array(repeating: CGFloat.zero, count: max(columnCount, 1))
        let columnWidth = (width - CGFloat(max(columnCount - 1, 0)) * gridGap) / CGFloat(max(columnCount, 1))

        for template in templates {
            let index = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[index].append(template)
            heights[index] += estimatedHeight(for: template, columnWidth: columnWidth) + gridGap
        }

        return columns
    }

    private func gridHeight(width: CGFloat) -> CGFloat {
        let columns = balancedColumns(width: width)
        let columnWidth = (width - CGFloat(max(columnCount - 1, 0)) * gridGap) / CGFloat(max(columnCount, 1))
        return max(320, columns.map { column in
            column.reduce(CGFloat.zero) { $0 + estimatedHeight(for: $1, columnWidth: columnWidth) + gridGap }
        }.max() ?? 320)
    }

    private func estimatedHeight(for template: Template, columnWidth: CGFloat) -> CGFloat {
        let artworkHeight = columnWidth / CGFloat(max(0.64, min(1.85, template.displayAspectRatio)))
        return artworkHeight + 62
    }
}

private struct LibraryReferenceProjectGrid: View {
    let pages: [ColoringPage]
    let columnCount: Int
    let gridGap: CGFloat
    let onTap: (ColoringPage) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: gridGap) {
            ForEach(pages) { page in
                LibraryReferenceProjectCard(page: page) {
                    onTap(page)
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: gridGap),
            count: max(columnCount, 1)
        )
    }
}

private struct LibraryReferenceProjectCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let page: ColoringPage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .aspectRatio(1.35, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(page.title)
                            .font(SableTheme.Typography.fraunces(17, weight: .semibold))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 8)

                        Text(progressText)
                            .font(SableTheme.Typography.labelMedium.weight(.semibold))
                            .foregroundStyle(secondaryText)
                    }

                    ProgressTrack(progress: page.progress)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(cardFill)
            }
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                    .stroke(cardStroke, lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(page.title), \(progressText) complete")
        .accessibilityIdentifier("library.reference.project.\(page.title.normalizedIdentifier)")
    }

    private var progressText: String {
        "\(Int((page.progress * 100).rounded()))%"
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color(hex: "#181916").opacity(0.96) : Color(hex: "#FBF2E7").opacity(0.94)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color(hex: "#E5D1B6").opacity(0.22) : Color(hex: "#2C2A27").opacity(0.12)
    }

    private var primaryText: Color {
        SableTheme.gouachePrimaryText(for: colorScheme)
    }

    private var secondaryText: Color {
        SableTheme.gouacheSecondaryText(for: colorScheme)
    }
}

private struct LibraryReferenceSketchbookGrid: View {
    let collections: [PageCollection]
    let columnCount: Int
    let gridGap: CGFloat
    let onTap: (PageCollection) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: gridGap) {
            ForEach(collections) { collection in
                LibraryReferenceSketchbookCard(collection: collection) {
                    onTap(collection)
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: gridGap),
            count: max(columnCount, 1)
        )
    }
}

private struct LibraryReferenceSketchbookCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let collection: PageCollection
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                coverStack

                VStack(alignment: .leading, spacing: 8) {
                    Text(collection.name)
                        .font(SableTheme.Typography.fraunces(20, weight: .semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(pageCountText)
                        .font(SableTheme.Typography.labelMedium.weight(.semibold))
                        .foregroundStyle(secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(cardFill)
            }
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                    .stroke(cardStroke, lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(collection.name), \(pageCountText)")
        .accessibilityIdentifier("library.reference.sketchbook.\(collection.name.normalizedIdentifier)")
    }

    private var coverStack: some View {
        GeometryReader { proxy in
            let coverWidth = proxy.size.width * 0.42
            let coverHeight = proxy.size.height * 0.76

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(shelfFill)
                    .frame(height: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 13)

                if collection.previewTemplates.isEmpty {
                    PlaceholderArtwork(
                        tint: collection.category.accentColor,
                        seed: collection.name,
                        style: .compact
                    )
                    .frame(width: coverWidth, height: coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.leading, 12)
                    .padding(.bottom, 21)
                } else {
                    ForEach(Array(collection.previewTemplates.prefix(3).enumerated()), id: \.element.id) { index, template in
                        GouacheTemplatePreviewImage(template: template, contentMode: .fill)
                            .frame(width: coverWidth, height: coverHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(coverStroke, lineWidth: SableTheme.Border.hairlineWidth)
                            }
                            .rotationEffect(.degrees(rotation(for: index)))
                            .offset(
                                x: 12 + CGFloat(index) * coverWidth * 0.48,
                                y: verticalOffset(for: index)
                            )
                            .zIndex(Double(index))
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
        }
        .aspectRatio(1.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(coverBackground)
        .clipped()
    }

    private func rotation(for index: Int) -> Double {
        switch index {
        case 0:
            return -3
        case 2:
            return 2.5
        default:
            return 0
        }
    }

    private func verticalOffset(for index: Int) -> CGFloat {
        index == 1 ? -8 : 0
    }

    private var pageCountText: String {
        collection.pageCount == 1 ? "1 page" : "\(collection.pageCount) pages"
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color(hex: "#181916").opacity(0.96) : Color(hex: "#FBF2E7").opacity(0.94)
    }

    private var coverBackground: Color {
        colorScheme == .dark ? Color(hex: "#11120F").opacity(0.92) : Color(hex: "#F3E5D1").opacity(0.58)
    }

    private var shelfFill: Color {
        colorScheme == .dark ? Color(hex: "#73512C").opacity(0.76) : Color(hex: "#B9854C").opacity(0.62)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color(hex: "#E5D1B6").opacity(0.22) : Color(hex: "#2C2A27").opacity(0.12)
    }

    private var coverStroke: Color {
        colorScheme == .dark ? Color(hex: "#F5E4CD").opacity(0.22) : Color(hex: "#2C2A27").opacity(0.14)
    }

    private var primaryText: Color {
        SableTheme.gouachePrimaryText(for: colorScheme)
    }

    private var secondaryText: Color {
        SableTheme.gouacheSecondaryText(for: colorScheme)
    }
}

private struct LibraryReferenceTemplateCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let template: Template
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                GouacheTemplatePreviewImage(template: template, contentMode: .fill)
                    .aspectRatio(template.displayAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 9) {
                    Text(template.name)
                        .font(SableTheme.Typography.fraunces(17, weight: .semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    DifficultyPill(difficulty: template.difficulty)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(cardFill)
            }
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                    .stroke(cardStroke, lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
        .accessibilityIdentifier("library.reference.template.\(template.name.normalizedIdentifier)")
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color(hex: "#181916").opacity(0.96) : Color(hex: "#FBF2E7").opacity(0.94)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color(hex: "#E5D1B6").opacity(0.22) : Color(hex: "#2C2A27").opacity(0.12)
    }

    private var primaryText: Color {
        SableTheme.gouachePrimaryText(for: colorScheme)
    }

}

private struct LibraryReferenceMetrics {
    let size: CGSize

    var isLandscape: Bool {
        UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }

    private var baseWidth: CGFloat {
        isLandscape ? 1194 : 744
    }

    private var scale: CGFloat {
        max(0.86, min(1.08, size.width / baseWidth))
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * scale
    }

    var horizontalInset: CGFloat {
        scaled(isLandscape ? 58 : 30)
    }

    var topInset: CGFloat {
        scaled(isLandscape ? 30 : 28)
    }

    var heroHeight: CGFloat {
        backgroundFrameHeight
    }

    var titleX: CGFloat {
        scaled(isLandscape ? 58 : 30)
    }

    var titleY: CGFloat {
        scaled(isLandscape ? 30 : 32)
    }

    var filtersX: CGFloat {
        scaled(isLandscape ? 61 : 29)
    }

    var filtersY: CGFloat {
        scaled(isLandscape ? 148 : 212)
    }

    var searchY: CGFloat {
        scaled(isLandscape ? 30 : 34)
    }

    func searchX(isExpanded: Bool) -> CGFloat {
        let width = isExpanded ? searchExpandedWidth : searchButtonSize
        return size.width - horizontalInset - width
    }

    var sectionX: CGFloat {
        scaled(isLandscape ? 58 : 30)
    }

    var sectionY: CGFloat {
        scaled(isLandscape ? 184 : 252)
    }

    var gridX: CGFloat {
        scaled(isLandscape ? 58 : 30)
    }

    var gridY: CGFloat {
        scaled(isLandscape ? 272 : 430)
    }

    var gridWidth: CGFloat {
        min(size.width - gridX * 2, scaled(isLandscape ? 1260 : 684))
    }

    var backgroundFrameHeight: CGFloat {
        scaled(isLandscape ? 338 : 374)
    }

    func backgroundY(for colorScheme: ColorScheme) -> CGFloat {
        0
    }

    func contentHeight(for itemCount: Int) -> CGFloat {
        let rowCount = max(1, Int(ceil(Double(max(itemCount, 1)) / Double(max(columnCount, 1)))))
        let estimatedRowHeight = scaled(isLandscape ? 350 : 360)
        let gridHeight = CGFloat(rowCount) * estimatedRowHeight + CGFloat(max(rowCount - 1, 0)) * gridGap
        return max(backgroundFrameHeight, gridY + gridHeight + bottomPadding)
    }

    var brandSize: CGFloat {
        scaled(isLandscape ? 13 : 14)
    }

    var titleSize: CGFloat {
        scaled(isLandscape ? 42 : 43)
    }

    var sectionTitleSize: CGFloat {
        scaled(23)
    }

    var subtitleSize: CGFloat {
        scaled(12)
    }

    var searchButtonSize: CGFloat {
        scaled(42)
    }

    var searchIconSize: CGFloat {
        scaled(17)
    }

    var searchExpandedWidth: CGFloat {
        scaled(isLandscape ? 310 : 270)
    }

    var headerSpacing: CGFloat {
        scaled(isLandscape ? 10 : 9)
    }

    func headerShadowColor(for colorScheme: ColorScheme) -> Color {
        guard !isLandscape else { return .clear }
        return colorScheme == .dark ? Color.black.opacity(0.36) : Color.white.opacity(0.42)
    }

    var headerShadowRadius: CGFloat {
        isLandscape ? 0 : scaled(3)
    }

    var gridGap: CGFloat {
        scaled(22)
    }

    var sectionGap: CGFloat {
        scaled(18)
    }

    var sectionTopOffset: CGFloat {
        0
    }

    var bottomPadding: CGFloat {
        scaled(132)
    }

    var columnCount: Int {
        isLandscape ? 4 : 2
    }

    var sketchbookColumnCount: Int {
        isLandscape ? 3 : 2
    }
}

private enum LibraryReferenceFilter: String, CaseIterable, Identifiable {
    case all
    case sketchbooks

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .sketchbooks:
            return "Sketchbooks"
        }
    }
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
