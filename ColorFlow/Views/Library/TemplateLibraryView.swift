import SwiftUI

struct TemplateLibraryView: View {
    @State private var viewModel = TemplateLibraryViewModel()
    @State private var selectedTemplate: Template?
    @State private var selectedUserTemplate: UserTemplate?
    @State private var showPhotoImport = false

    let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter chips
                TemplateCategoryView(
                    selectedCategory: $viewModel.selectedCategory,
                    categories: TemplateCategory.allCases
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // My Photos section (only when user templates exist)
                        if !viewModel.userTemplates.isEmpty {
                            myPhotosSection
                        }

                        // Curated catalog grid
                        if viewModel.filteredTemplates.isEmpty {
                            ContentUnavailableView("No Templates", systemImage: "square.dashed",
                                                  description: Text("Templates will appear here."))
                                .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(viewModel.filteredTemplates) { template in
                                    TemplateThumbnailCell(template: template) {
                                        selectedTemplate = template
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPhotoImport = true
                    } label: {
                        Label("Create from Photo", systemImage: "camera.fill")
                    }
                    .accessibilityIdentifier("library.createFromPhoto")
                }
            }
            .fullScreenCover(item: $selectedTemplate) { template in
                let project = Project(template: template)
                let canvasVM = CanvasViewModel(project: project, template: template)
                CanvasView(viewModel: canvasVM)
            }
            .fullScreenCover(item: $selectedUserTemplate) { userTemplate in
                let template = userTemplate.asTemplate()
                let project  = Project(template: template)
                let canvasVM = CanvasViewModel(project: project, template: template)
                CanvasView(viewModel: canvasVM)
            }
            .sheet(isPresented: $showPhotoImport) {
                PhotoImportView { template in
                    viewModel.reloadUserTemplates()
                }
            }
        }
    }

    // MARK: - My Photos

    private var myPhotosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Photos")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(viewModel.userTemplates.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.userTemplates) { userTemplate in
                        UserTemplateThumbnailCell(userTemplate: userTemplate) {
                            selectedUserTemplate = userTemplate
                        } onDelete: {
                            viewModel.deleteUserTemplate(userTemplate)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            Divider()
                .padding(.horizontal)
                .padding(.top, 4)
        }
    }
}

// MARK: - Thumbnail Cell

private struct TemplateThumbnailCell: View {
    let template: Template
    let onSelect: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(AppTheme.Surface.canvas)
                        .aspectRatio(1, contentMode: .fit)
                        .shadow(color: AppTheme.Surface.scrim, radius: AppTheme.Spacing.xxs, y: 2)

                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .padding(10)
.clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    } else {
                        Image(systemName: template.category.systemImageName)
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.Ink.tertiary.opacity(0.4))
                    }

                    // Difficulty badge
                    VStack {
                        HStack {
                            Spacer()
                            DifficultyBadge(difficulty: template.difficulty)
                        }
                        Spacer()
                    }
                    .padding(8)
                }

                Text(template.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(template.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        // Load cached thumbnail PNG from Caches directory
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let thumbURL = cachesURL.appendingPathComponent("thumbnails/\(template.svgFilename).png")

        if let data = try? Data(contentsOf: thumbURL), let img = UIImage(data: data) {
            thumbnail = img
            return
        }

        // Not cached — parse SVG and render thumbnail on background thread
        guard let svgURL = template.svgURL else { return }
        let img = await Task.detached(priority: .background) {
            guard case .success(let geometry) = SVGParser.parse(url: svgURL) else {
                return UIImage()
            }
            return TemplateRenderer.renderThumbnail(
                geometry: geometry,
                size: CGSize(width: 400, height: 400)
            )
        }.value

        // Cache it
        try? FileManager.default.createDirectory(at: thumbURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = img.pngData() {
            try? data.write(to: thumbURL)
        }
        thumbnail = img
    }
}

// MARK: - User Template Thumbnail Cell

private struct UserTemplateThumbnailCell: View {
    let userTemplate: UserTemplate
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let thumb = thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.largeTitle)
                                .foregroundStyle(AppTheme.Brand.accent.opacity(0.4))
                        }
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    .compositingGroup()
                    .background(AppTheme.Surface.canvas.clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md)))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)

                    // Delete button
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .background(Circle().fill(.white).padding(2))
                    }
                    .padding(4)
                    .accessibilityLabel("Delete \(userTemplate.name)")
                }

                Text(userTemplate.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)

                Text(userTemplate.preset)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open user template: \(userTemplate.name)")
        .accessibilityIdentifier("library.userTemplate.\(userTemplate.id.uuidString)")
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let thumbURL = StorageService.documentsURL
            .appendingPathComponent(userTemplate.thumbnailPath)
        guard FileManager.default.fileExists(atPath: thumbURL.path),
              let data = try? Data(contentsOf: thumbURL),
              let img  = UIImage(data: data) else { return }
        thumbnail = img
    }
}

// MARK: - Difficulty Badge

private struct DifficultyBadge: View {
    let difficulty: Difficulty
    var color: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
            .foregroundStyle(AppTheme.Brand.onAccent)
    }
}
