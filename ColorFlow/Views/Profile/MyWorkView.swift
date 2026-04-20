import SwiftUI

enum WorkFilter: String, CaseIterable {
    case all        = "All"
    case inProgress = "In Progress"
    case completed  = "Completed"
}

struct MyWorkView: View {
    @Environment(GalleryViewModel.self) var viewModel
    @State private var filter: WorkFilter = .all
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Work")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Ink.primary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = shareImage {
                    ShareSheet(image: img)
                }
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
        .onAppear { styleSegmentedControl() }
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
                    ArtworkCard(project: project) {
                        viewModel.open(project)
                    } onDelete: {
                        viewModel.delete(project)
                    } onShare: { img in
                        shareImage = img
                        showShareSheet = true
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
        guard let latest = viewModel.projects.first else { return }
        Task {
            let url = StorageService.documentsURL
                .appendingPathComponent(latest.fillLayerPath)
            guard let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { return }
            shareImage = img
            showShareSheet = true
        }
    }

    private func styleSegmentedControl() {
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(AppTheme.Brand.accent)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(AppTheme.Brand.onAccent)], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(AppTheme.Ink.secondary)], for: .normal)
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
    let onTap: () -> Void
    let onDelete: () -> Void
    let onShare: (UIImage) -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(Color.white)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
            if let img = thumbnail {
                Button { onShare(img) } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .accessibilityIdentifier("mywork.artwork.\(project.id.uuidString)")
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

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
