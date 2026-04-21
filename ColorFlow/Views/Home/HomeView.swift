import SwiftUI

/// Home tab — featured content, recent work, and template suggestions.
/// Fully implemented in Phase 2; this stub satisfies the Phase 1 TabView.
struct HomeView: View {
    @Environment(GalleryViewModel.self) var galleryViewModel
    @State private var showTemplateLibrary = false
    @State private var showPhotoImport = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        heroPlaceholder
                        recentWorkSection
                        suggestionsSection
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { headerToolbar }
            .sheet(isPresented: $showTemplateLibrary) {
                TemplateLibraryView()
            }
            .sheet(isPresented: $showPhotoImport) {
                PhotoImportView { template in
                    galleryViewModel.startProject(from: template.asTemplate())
                }
            }
        }
    }

    // MARK: - Hero

    private var heroPlaceholder: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                .fill(AppTheme.Surface.elevated)
                .frame(maxWidth: .infinity)
                .frame(height: 220)

            VStack(alignment: .leading, spacing: 4) {
                Text("Start Coloring")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.Ink.primary)
                Text("Pick a template and bring it to life.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Ink.secondary)

                HStack(spacing: 10) {
                    Button("Browse Templates") { showTemplateLibrary = true }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Brand.accent)
                        .accessibilityIdentifier("home.browseTemplates")

                    Button {
                        showPhotoImport = true
                    } label: {
                        Label("From Photo", systemImage: "camera.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.Brand.accent)
                    .accessibilityIdentifier("home.createFromPhoto")
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, 12)
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
                            RecentWorkCell(project: project) {
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var headerToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("ColorFlow")
                .font(.headline)
                .foregroundStyle(AppTheme.Ink.primary)
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showTemplateLibrary = true } label: {
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
    let onTap: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(AppTheme.Ink.secondary)
                            }
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
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
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        let projectID = project.id
        let thumbPath = project.thumbnailPath
        let fillPath = project.fillLayerPath
        return await Task.detached(priority: .userInitiated) {
            ProjectThumbnailCache.shared.load(
                id: projectID,
                thumbnailPath: thumbPath,
                fillLayerPath: fillPath
            )
        }.value
    }
}

// MARK: - Suggested Template Cell

private struct SuggestedTemplateCell: View {
    let template: Template
    let onTap: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(Color.white)
                    .frame(width: 140, height: 140)

                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                } else {
                    Image(systemName: template.category.systemImageName)
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.Brand.accent.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start coloring: \(template.name)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.suggested.\(template.id.uuidString)")
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        guard let url = template.svgURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard case .success(let geo) = SVGParser.parse(url: url) else { return nil }
            return TemplateRenderer.renderThumbnail(geometry: geo, size: CGSize(width: 280, height: 280))
        }.value
    }
}
