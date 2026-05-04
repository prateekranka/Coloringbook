import SwiftUI

enum WorkFilter: String, CaseIterable {
    case all        = "All"
    case inProgress = "In Progress"
    case completed  = "Completed"
}

struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MyWorkView: View {
    @Environment(GalleryViewModel.self) var viewModel
    @State private var filter: WorkFilter = .all
    @State private var shareItem: ShareItem?

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        profileSection
                        filterBar
                        artworkGrid
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $shareItem) {
                ShareSheet(image: $0.image)
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppTheme.Surface.elevated)
                    .frame(width: 90, height: 90)
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.Ink.secondary)
            }

            Text("You")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.Ink.primary)

            // CTA
            Button {
                shareLatestArtwork()
            } label: {
                Text("Share your art!")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.Brand.onAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppTheme.Brand.accent))
            }
            .disabled(viewModel.projects.isEmpty)
            .opacity(viewModel.projects.isEmpty ? 0.4 : 1)
            .accessibilityIdentifier("mywork.share")

            // Stats row
            HStack(spacing: 0) {
                StatCell(value: viewModel.projects.count, label: "Total")
                Divider()
                    .frame(height: 36)
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 20)
                StatCell(value: viewModel.completedCount, label: "Completed")
                Divider()
                    .frame(height: 36)
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 20)
                StatCell(value: viewModel.inProgressCount, label: "In Progress")
            }
            .padding(.top, 4)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        Picker("Filter", selection: $filter) {
            ForEach(WorkFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppTheme.Spacing.xl)
        .accessibilityIdentifier("mywork.filter")
    }

    // MARK: - Artwork Grid

    @ViewBuilder
    private var artworkGrid: some View {
        let displayed = filteredProjects
        if displayed.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.Brand.accent.opacity(0.5))
                Text(viewModel.projects.isEmpty
                     ? "No artwork yet — start coloring!"
                     : "Nothing here yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Ink.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(displayed) { project in
                    ArtworkCard(project: project, template: viewModel.template(for: project)) {
                        viewModel.open(project)
                    } onDelete: {
                        viewModel.delete(project)
                    } onShare: { img in
                        shareItem = ShareItem(image: img)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    private var filteredProjects: [Project] {
        // Phase 5 will use a real status field; for now "All" shows everything.
        viewModel.projects
    }

    // MARK: - Helpers

    private func shareLatestArtwork() {
        guard let latest = viewModel.projects.first,
              let template = viewModel.template(for: latest) else { return }
        Task {
            let paintState: ProjectPaintState
            let paintStateURL = StorageService.documentsURL
                .appendingPathComponent("fills/\(latest.id.uuidString).json")
            if let data = try? Data(contentsOf: paintStateURL),
               let saved = try? JSONDecoder().decode(ProjectPaintState.self, from: data) {
                paintState = saved
            } else {
                paintState = ProjectPaintState()
            }

            guard let svgURL = template.svgURL,
                  case .success(let geometry) = SVGParser.parse(url: svgURL) else { return }

            let img = await Task.detached {
                TemplateRenderer.renderExport(
                    geometry: geometry,
                    fills: paintState.regionFills,
                    pencilImage: nil,
                    backgroundColor: .white,
                    size: CGSize(width: 1024, height: 1024)
                )
            }.value
            shareItem = ShareItem(image: img)
        }
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.Ink.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.Ink.secondary)
        }
        .frame(minWidth: 70)
    }
}

// MARK: - Artwork Card

private struct ArtworkCard: View {
    let project: Project
    let template: Template?
    let onTap: () -> Void
    let onDelete: () -> Void
    let onShare: (UIImage) -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(Color.white)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                AsyncThumbnail(
                    load: { await loadThumbnail() },
                    contentMode: .fill,
                    placeholderSystemName: "photo"
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { shareHighRes() } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityLabel("Artwork: \(project.templateName)")
        .accessibilityIdentifier("mywork.artwork.\(project.id.uuidString)")
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
                size: CGSize(width: 360, height: 360)
            )
        }.value
    }

    private func shareHighRes() {
        guard let template = template else { return }
        Task {
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
                  case .success(let geometry) = SVGParser.parse(url: svgURL) else { return }

            let img = await Task.detached {
                TemplateRenderer.renderExport(
                    geometry: geometry,
                    fills: paintState.regionFills,
                    pencilImage: nil,
                    backgroundColor: .white,
                    size: CGSize(width: 1024, height: 1024)
                )
            }.value
            onShare(img)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    MyWorkView()
        .environment(GalleryViewModel())
        .environment(AppState.shared)
}
