import SwiftUI

/// Home tab — featured content, recent work, and template suggestions.
/// Fully implemented in Phase 2; this stub satisfies the Phase 1 TabView.
struct HomeView: View {
    @Environment(GalleryViewModel.self) var galleryViewModel
    private enum HomeSheet: Identifiable {
        case browseTemplates, fromPhoto
        var id: Self { self }
    }
    @State private var presentedSheet: HomeSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        recentWorkSection
                        inspirationSection
                        suggestionsSection
                        heroPlaceholder
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { headerToolbar }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .browseTemplates:
                    TemplateLibraryView()
                case .fromPhoto:
                    PhotoImportView { template in
                        galleryViewModel.startProject(from: template.asTemplate())
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroPlaceholder: some View {
        HStack {
            Spacer()
            VStack(alignment: .center, spacing: 6) {
                Text("Start Coloring")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.Ink.primary)
                Text("Pick a template and bring it to life.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Ink.secondary)

                HStack(spacing: 10) {
                    Button("Browse Templates") { presentedSheet = .browseTemplates }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Brand.accent)
                        .accessibilityIdentifier("home.browseTemplates")

                    Button {
                        presentedSheet = .fromPhoto
                    } label: {
                        Label("From Photo", systemImage: "camera.fill")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.Brand.accent)
                    .accessibilityIdentifier("home.createFromPhoto")
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(AppTheme.Surface.elevated)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.top, 12)
            Spacer()
        }
    }

    // MARK: - Recent Work

    private var recentWorkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Recent Work")
                .padding(.horizontal, AppTheme.Spacing.xl)

            if galleryViewModel.projects.isEmpty {
                Text("No projects yet — start coloring!")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Ink.secondary)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(galleryViewModel.recentProjects) { project in
                            RecentWorkCell(project: project, template: galleryViewModel.template(for: project)) {
                                galleryViewModel.open(project)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Suggested For You")
                .padding(.horizontal, AppTheme.Spacing.xl)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(galleryViewModel.suggestedTemplates) { template in
                        SuggestedTemplateCell(template: template) {
                            galleryViewModel.startProject(from: template)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Inspiration

    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Inspiration")
                .padding(.horizontal, AppTheme.Spacing.xl)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(galleryViewModel.inspirationTemplates) { template in
                        InspirationCell(template: template) {
                            galleryViewModel.startProject(from: template)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var headerToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { presentedSheet = .browseTemplates } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.Brand.accent)
                    .font(.title3)
            }
            .accessibilityLabel("Browse templates")
            .accessibilityIdentifier("home.plus")
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(AppTheme.Ink.primary)
    }
}

// MARK: - Recent Work Cell

private struct RecentWorkCell: View {
    let project: Project
    let template: Template?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                AsyncThumbnail(
                    load: { await loadThumbnail() },
                    contentMode: .fill,
                    placeholderSystemName: "photo"
                )
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .compositingGroup()
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(Color.white)
                )

                // Restart badge
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Surface.elevated)
                    .background(Circle().fill(Color.white).padding(2))
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume recent project")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.recent.\(project.id.uuidString)")
    }

    private func loadThumbnail() async -> UIImage? {
        guard let template = template else {
            return await Task.detached {
                ProjectThumbnailCache.shared.load(
                    id: self.project.id,
                    thumbnailPath: self.project.thumbnailPath,
                    fillLayerPath: self.project.fillLayerPath
                )
            }.value
        }

        return await Task.detached(priority: .userInitiated) {
            let paintState: ProjectPaintState
            let paintStateURL = StorageService.documentsURL
                .appendingPathComponent("fills/\(self.project.id.uuidString).json")
            if let data = try? Data(contentsOf: paintStateURL),
               let saved = try? JSONDecoder().decode(ProjectPaintState.self, from: data) {
                paintState = saved
            } else {
                paintState = ProjectPaintState()
            }

            guard let svgURL = template.svgURL,
                  case .success(let geometry) = SVGParser.parse(url: svgURL) else {
                return nil as UIImage?
            }

            return TemplateRenderer.renderThumbnail(
                geometry: geometry,
                fills: paintState.regionFills,
                size: CGSize(width: 280, height: 280)
            )
        }.value
    }
}

// MARK: - Suggested Template Cell

private struct SuggestedTemplateCell: View {
    let template: Template
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(Color.white)

                AsyncThumbnail(
                    load: {
                        await TemplateRenderer.thumbnail(for: template, size: CGSize(width: 280, height: 280))
                    },
                    contentMode: .fit,
                    placeholderSystemName: template.category.systemImageName
                )
                .padding(8)
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start coloring: \(template.name)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.suggested.\(template.id.uuidString)")
    }
}

// MARK: - Inspiration Cell

private struct InspirationCell: View {
    let template: Template
    let onTap: () -> Void

    private static let palette: [String] = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
        "#F8B500", "#6C5CE7", "#A8E6CF", "#FD79A8", "#FDCB6E"
    ]

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(Color.white)

                AsyncThumbnail(
                    load: {
                        await Task.detached(priority: .userInitiated) {
                            let fills = Self.fills(for: template)
                            guard let url = template.svgURL else { return nil }
                            guard case .success(let geo) = SVGParser.parse(url: url) else { return nil }
                            return TemplateRenderer.renderThumbnail(geometry: geo, fills: fills, size: CGSize(width: 280, height: 280))
                        }.value
                    },
                    contentMode: .fit,
                    placeholderSystemName: template.category.systemImageName
                )
                .padding(8)
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Inspiration: \(template.name)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.inspiration.\(template.id.uuidString)")
    }

    private static func fills(for template: Template) -> [String: String] {
        guard let url = template.svgURL,
              case .success(let geometry) = SVGParser.parse(url: url) else {
            return [:]
        }
        var result: [String: String] = [:]
        for (index, region) in geometry.regions.enumerated() {
            result[region.id] = palette[index % palette.count]
        }
        return result
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(GalleryViewModel())
        .environment(AppState.shared)
}
