import SwiftUI

struct LibraryReferenceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFilter: LibraryReferenceFilter = .all

    let templates: [Template]
    let isLoading: Bool
    let onSearch: () -> Void
    let onSelectTemplate: (Template) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = LibraryReferenceMetrics(size: proxy.size)

            ZStack(alignment: .top) {
                pageBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(metrics: metrics)
                        templatesSection(metrics: metrics)
                    }
                    .padding(.bottom, metrics.bottomPadding)
                }
            }
        }
        .accessibilityIdentifier("library.reference")
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

            Button(action: onSearch) {
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
            selectedFilter = filter
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
        switch selectedFilter {
        case .all, .sketchbooks:
            return templates
        }
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
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(bookmarkColor)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
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

    private var bookmarkColor: Color {
        colorScheme == .dark ? Color(hex: "#E7D4BB") : Color(hex: "#504941")
    }
}

private struct LibraryReferenceMetrics {
    let size: CGSize

    var isLandscape: Bool {
        size.width > size.height
    }

    var horizontalInset: CGFloat {
        isLandscape ? 58 : 30
    }

    var topInset: CGFloat {
        isLandscape ? 24 : 20
    }

    var heroHeight: CGFloat {
        isLandscape ? min(max(size.height * 0.46, 300), 360) : min(max(size.height * 0.33, 270), 330)
    }

    var brandSize: CGFloat {
        isLandscape ? 14 : 12
    }

    var titleSize: CGFloat {
        isLandscape ? 40 : 34
    }

    var sectionTitleSize: CGFloat {
        isLandscape ? 24 : 20
    }

    var subtitleSize: CGFloat {
        isLandscape ? 13 : 11
    }

    var searchButtonSize: CGFloat {
        isLandscape ? 48 : 38
    }

    var searchIconSize: CGFloat {
        isLandscape ? 20 : 16
    }

    var headerSpacing: CGFloat {
        isLandscape ? 16 : 12
    }

    var gridGap: CGFloat {
        isLandscape ? 22 : 12
    }

    var sectionGap: CGFloat {
        isLandscape ? 18 : 12
    }

    var sectionTopOffset: CGFloat {
        isLandscape ? -20 : -6
    }

    var bottomPadding: CGFloat {
        isLandscape ? 28 : 24
    }

    var columnCount: Int {
        isLandscape ? 4 : 2
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
