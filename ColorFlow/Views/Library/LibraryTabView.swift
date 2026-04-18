import SwiftUI

/// Library tab — full-screen template browser with a curated collections strip,
/// icon-rich category pills, and thumbnail cards with soft shadows + gradient
/// fills. The underlying data source (`Template.loadAll`) is unchanged; the CDN
/// integration slots in later via `ContentService`.
struct LibraryTabView: View {
    @State private var viewModel = TemplateLibraryViewModel()
    @State private var searchText = ""
    @Environment(GalleryViewModel.self) var galleryViewModel

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 14)]

    // Cutoff for the "New" badge — templates added within this window get a tag.
    private let newBadgeWindow: TimeInterval = 14 * 24 * 60 * 60 // 14 days

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !featuredCollections.isEmpty && searchText.isEmpty {
                            collectionsStrip
                        }

                        LibraryCategoryBar(
                            selectedCategory: $viewModel.selectedCategory,
                            categories: TemplateCategory.allCases
                        )
                        .padding(.horizontal, AppTheme.screenPadding)

                        if filteredTemplates.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(filteredTemplates) { template in
                                    LibraryTemplateCard(
                                        template: template,
                                        isNew: isNew(template)
                                    ) {
                                        HapticService.shared.toolChanged()
                                        galleryViewModel.startProject(from: template)
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.screenPadding)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { libraryToolbar }
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search templates")
            .refreshable {
                await viewModel.refreshRemoteCatalogue()
                if let version = ContentService.shared.manifestVersion {
                    ContentService.shared.lastSeenVersion = version
                }
            }
        }
    }

    private var filteredTemplates: [Template] {
        let base = viewModel.filteredTemplates
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Auto-generated collections — one per populated category. Replaced by
    /// curated remote collections when `ContentService` lands (workstream B).
    private var featuredCollections: [(title: String, templates: [Template])] {
        let grouped = Dictionary(grouping: viewModel.templates) { $0.category }
        return TemplateCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], items.count >= 2 else { return nil }
            return (cat.rawValue, items)
        }
    }

    private var collectionsStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collections")
                .font(AppTheme.displayFont(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(featuredCollections, id: \.title) { collection in
                        CollectionCard(
                            title: collection.title,
                            count: collection.templates.count,
                            category: TemplateCategory(rawValue: collection.title) ?? .abstract
                        ) {
                            HapticService.shared.selectionMoved()
                            viewModel.selectedCategory = TemplateCategory(rawValue: collection.title)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: searchText.isEmpty ? "books.vertical" : "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
            }
            Text(searchText.isEmpty ? "No Templates" : "No Results")
                .font(AppTheme.displayFont(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(searchText.isEmpty
                 ? "Templates will appear here."
                 : "Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func isNew(_ template: Template) -> Bool {
        guard let addedAt = template.addedAt else { return false }
        return Date().timeIntervalSince(addedAt) <= newBadgeWindow
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Library")
                .font(AppTheme.displayFont(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

// MARK: - Category pill bar

struct LibraryCategoryBar: View {
    @Binding var selectedCategory: TemplateCategory?
    let categories: [TemplateCategory]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryPill(label: "All",
                             icon: "square.grid.2x2",
                             isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = nil }
                    HapticService.shared.selectionMoved()
                }
                ForEach(categories, id: \.self) { cat in
                    CategoryPill(label: cat.rawValue,
                                 icon: cat.systemImageName,
                                 isSelected: selectedCategory == cat) {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = cat }
                        HapticService.shared.selectionMoved()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct CategoryPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected
                          ? AnyShapeStyle(AppTheme.accentGradient)
                          : AnyShapeStyle(AppTheme.surface))
            )
            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("library.category.\(label)")
    }
}

// MARK: - Collection card

private struct CollectionCard: View {
    let title: String
    let count: Int
    let category: TemplateCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Category-tinted gradient background.
                RoundedRectangle(cornerRadius: AppTheme.heroCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors(for: category),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Large decorative icon in the top-right.
                Image(systemName: category.systemImageName)
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.18))
                    .offset(x: 40, y: -14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.displayFont(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(count) template\(count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(16)
            }
            .frame(width: 200, height: 140)
            .clipped()
            .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) templates")
        .accessibilityIdentifier("library.collection.\(title)")
    }

    private func gradientColors(for category: TemplateCategory) -> [Color] {
        switch category {
        case .mandalas:     return [Color(hex: "#7B5FE8"), Color(hex: "#3D2E8A")]
        case .animals:      return [Color(hex: "#FF7A7A"), Color(hex: "#B3324A")]
        case .architecture: return [Color(hex: "#4E7BD4"), Color(hex: "#1E2F63")]
        case .abstract:     return [Color(hex: "#E879F9"), Color(hex: "#6A1B9A")]
        case .botanicals:   return [Color(hex: "#6DBE71"), Color(hex: "#1E6B3B")]
        case .lifestyle:    return [Color(hex: "#F5A962"), Color(hex: "#A04D1E")]
        }
    }
}

// MARK: - Template card

struct LibraryTemplateCard: View {
    let template: Template
    var isNew: Bool = false
    let onSelect: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Soft gradient card face — replaces plain white.
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.93)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(1, contentMode: .fit)

                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    } else {
                        Image(systemName: template.category.systemImageName)
                            .font(.system(size: 36))
                            .foregroundStyle(AppTheme.accent.opacity(0.4))
                    }

                    if isNew {
                        VStack {
                            HStack {
                                Spacer()
                                NewBadge()
                            }
                            Spacer()
                        }
                        .padding(10)
                    }
                }
                .cardShadow()

                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    DifficultyPill(difficulty: template.difficulty)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.name), \(template.category.rawValue), difficulty \(template.difficulty.rawValue)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("library.template.\(template.id.uuidString)")
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        // 1. Prefer a pre-rendered remote preview PNG when available — avoids
        //    rasterising large SVGs on-device.
        if let remote = template.remotePreviewURL,
           let img = await fetchRemoteThumbnail(remote) {
            return img
        }
        // 2. Ensure an SVG is available (download on demand when bundled copy
        //    is absent), then rasterise.
        let svgURL = template.svgURL ?? (await ContentService.shared.ensureSVGCached(template))
        guard let url = svgURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard case .success(let geo) = SVGParser.parse(url: url) else { return nil }
            return TemplateRenderer.renderThumbnail(geometry: geo, size: CGSize(width: 400, height: 400))
        }.value
    }

    private func fetchRemoteThumbnail(_ url: URL) async -> UIImage? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("content/thumbs", isDirectory: true)
        let cacheURL = cacheDir.appendingPathComponent(url.lastPathComponent)

        if let data = try? Data(contentsOf: cacheURL), let img = UIImage(data: data) {
            return img
        }

        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            try? data.write(to: cacheURL, options: .atomic)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

private struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(AppTheme.accentGradient))
    }
}

// MARK: - Difficulty Pill

struct DifficultyPill: View {
    let difficulty: Difficulty

    private var color: Color {
        switch difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.18))
            )
    }
}
