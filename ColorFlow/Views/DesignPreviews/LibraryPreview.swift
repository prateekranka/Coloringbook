import SwiftUI

/// Proposed Library Tab layout — category pills + adaptive grid of template cards.
/// Renders real SVG templates with proper ColorFlow branding (Fraunces font, sage accent).
struct ProposedLibraryView: View {
    let templates: [Template]
    let thumbnails: [UUID: UIImage]

    @State private var selectedCategory: TemplateCategory?
    @State private var searchText = ""

    private var filteredTemplates: [Template] {
        let base: [Template]
        if let cat = selectedCategory {
            base = templates.filter { $0.category == cat }
        } else {
            base = templates
        }
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Surface.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Brand header
                    libraryHeader

                    // Category bar
                    categoryBar

                    Divider().background(Color.white.opacity(0.08))

                    // Grid
                    if filteredTemplates.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(filteredTemplates) { template in
                                    templateCard(template)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Library Header

    private var libraryHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Library")
                    .font(Font.cfTitle)
                    .foregroundStyle(AppTheme.Ink.primary)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Search bar (always visible, prominent)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.Ink.tertiary)

                TextField("Search templates...", text: $searchText)
                    .font(Font.cfBody)
                    .foregroundStyle(AppTheme.Ink.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(AppTheme.Surface.elevated)
            )
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                CategoryPill(label: "All", isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = nil }
                }
                ForEach(TemplateCategory.allCases, id: \.self) { cat in
                    CategoryPill(label: cat.rawValue, isSelected: selectedCategory == cat) {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = cat }
                    }
                }
                // Proposed: extra filter pills
                CategoryPill(label: "Popular", isSelected: false) { }
                CategoryPill(label: "New", isSelected: false) { }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.Surface.background)
        .frame(height: 46)
    }

    // MARK: - Template Card

    private func templateCard(_ template: Template) -> some View {
        Button { } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(Color.white)
                        .aspectRatio(1, contentMode: .fit)

                    if let img = thumbnails[template.id] {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                    }
                }
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                HStack {
                    Text(template.name)
                        .font(Font.cfCaptionBold)
                        .foregroundStyle(AppTheme.Ink.primary)
                        .lineLimit(1)

                    Spacer()

                    // Favorite icon (proposed)
                    Image(systemName: "heart")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Ink.tertiary)
                }

                HStack(spacing: 6) {
                    DifficultyPillSmall(difficulty: template.difficulty)

                    // Category icon
                    Image(systemName: template.category.systemImageName)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.Ink.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            BrushMarkShape()
                .stroke(
                    AppTheme.Brand.accent.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 64, height: 64)

            Text(searchText.isEmpty ? "No Templates" : "No Results")
                .font(Font.cfTitleSmall)
                .foregroundStyle(AppTheme.Ink.primary)

            Text(searchText.isEmpty
                 ? "Templates will appear here."
                 : "Try a different search term.")
                .font(Font.cfBody)
                .foregroundStyle(AppTheme.Ink.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - BrushMarkShape

private struct BrushMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0.18 * w, y: 0.86 * h))
        path.addCurve(
            to: CGPoint(x: 0.58 * w, y: 0.32 * h),
            control1: CGPoint(x: 0.22 * w, y: 0.58 * h),
            control2: CGPoint(x: 0.40 * w, y: 0.40 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.84 * w, y: 0.20 * h),
            control1: CGPoint(x: 0.70 * w, y: 0.24 * h),
            control2: CGPoint(x: 0.80 * w, y: 0.18 * h)
        )
        return path
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(label)
                    .font(isSelected ? Font.cfSubheadline.bold() : Font.cfSubheadline)
                    .foregroundStyle(isSelected ? AppTheme.Brand.accent : AppTheme.Ink.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                Rectangle()
                    .fill(isSelected ? AppTheme.Brand.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Difficulty Pill (Small)

private struct DifficultyPillSmall: View {
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
            .background(Capsule().fill(color.opacity(0.18)))
    }
}

// MARK: - SVG Rendering Helper

private func libPreviewThumb(for template: Template, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
    guard let url = template.svgURL,
          case .success(let geo) = SVGParser.parse(url: url) else { return nil }
    return TemplateRenderer.renderThumbnail(geometry: geo, fills: [:], size: size)
}

// MARK: - Preview

#Preview("Proposed Library — Branded") {
    let allTemplates = Template.loadAll()
    var thumbs: [UUID: UIImage] = [:]
    for t in allTemplates {
        if let img = libPreviewThumb(for: t) {
            thumbs[t.id] = img
        }
    }
    return ProposedLibraryView(templates: allTemplates, thumbnails: thumbs)
        .environment(AppState.shared)
        .preferredColorScheme(.dark)
}
