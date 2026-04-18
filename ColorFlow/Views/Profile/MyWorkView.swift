import SwiftUI

enum WorkFilter: String, CaseIterable {
    case all        = "All"
    case inProgress = "In Progress"
    case completed  = "Completed"
}

struct MyWorkView: View {
    @Environment(GalleryViewModel.self) var viewModel
    @State private var cloudStorage = CloudStorage.shared
    @State private var filter: WorkFilter = .all
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

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
                        .foregroundStyle(AppTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusPill(status: cloudStorage.status)
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
                    .fill(AppTheme.surface)
                    .frame(width: 90, height: 90)
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text("You")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)

            // CTA
            Button {
                shareLatestArtwork()
            } label: {
                Text("Share your art!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppTheme.accent))
            }

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
        .padding(.horizontal, AppTheme.screenPadding)
        .onAppear { styleSegmentedControl() }
    }

    // MARK: - Artwork Grid

    @ViewBuilder
    private var artworkGrid: some View {
        let displayed = filteredProjects
        if displayed.isEmpty {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.14))
                        .frame(width: 120, height: 120)
                    Image(systemName: "paintpalette")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.accent)
                }
                Text(viewModel.projects.isEmpty
                     ? "No artwork yet"
                     : "Nothing here yet")
                    .font(AppTheme.displayFont(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(viewModel.projects.isEmpty
                     ? "Your finished pieces will show up here."
                     : "Try a different filter.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
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
            .padding(.horizontal, AppTheme.screenPadding)
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
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(AppTheme.accent)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(AppTheme.textSecondary)], for: .normal)
    }
}

// MARK: - Sync Status Pill

private struct SyncStatusPill: View {
    let status: CloudStorage.SyncStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.systemImage)
                .font(.caption)
            Text(status.displayLabel)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(AppTheme.surface.opacity(0.6))
        )
        .accessibilityLabel(status.displayLabel)
        .accessibilityIdentifier("myWork.syncStatus")
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
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
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
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(Color.white)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
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
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let url = StorageService.documentsURL
                .appendingPathComponent(project.fillLayerPath)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
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
