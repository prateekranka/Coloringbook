import SwiftUI

struct MyWorkView: View {
    @EnvironmentObject var viewModel: GalleryViewModel
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
            .accessibilityHint("Shares your most recent artwork")

        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Artwork Grid

    @ViewBuilder
    private var artworkGrid: some View {
        let displayed = viewModel.projects
        if displayed.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent.opacity(0.5))
                Text(viewModel.projects.isEmpty
                     ? "No artwork yet — start coloring!"
                     : "Nothing here yet.")
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

    // MARK: - Helpers

    private func shareLatestArtwork() {
        guard let latest = viewModel.projects.first else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let url = StorageService.documentsURL
                .appendingPathComponent(latest.thumbnailPath)
            guard let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                shareImage = img
                showShareSheet = true
            }
        }
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
                    .heavyShadow()

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
        .accessibilityLabel(project.templateName)
        .accessibilityHint("Double-tap to continue coloring")
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
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let url = StorageService.documentsURL
                    .appendingPathComponent(project.thumbnailPath)
                guard let data = try? Data(contentsOf: url) else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: UIImage(data: data))
            }
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
