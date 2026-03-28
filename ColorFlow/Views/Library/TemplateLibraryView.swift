import SwiftUI

struct TemplateLibraryView: View {
    @StateObject private var viewModel = TemplateLibraryViewModel()
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @Environment(\.dismiss) private var dismiss

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

                if viewModel.filteredTemplates.isEmpty {
                    ContentUnavailableView("No Templates", systemImage: "square.dashed",
                                          description: Text("Templates will appear here."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.filteredTemplates) { template in
                                TemplateThumbnailCell(template: template) {
                                    galleryViewModel.startProject(from: template)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Templates")
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .aspectRatio(1, contentMode: .fit)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: template.category.systemImageName)
                            .font(.largeTitle)
                            .foregroundStyle(Color.gray.opacity(0.4))
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
            .foregroundStyle(.white)
    }
}
