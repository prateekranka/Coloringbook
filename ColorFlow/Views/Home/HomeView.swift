import SwiftUI

/// Home tab — featured content, recent work, and template suggestions.
/// Fully implemented in Phase 2; this stub satisfies the Phase 1 TabView.
struct HomeView: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @State private var showHelp = false
    @State private var showTemplateLibrary = false
    @State private var streakCount: Int = DailyChallengeService.currentStreak

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        heroPlaceholder
                        dailyChallengeSection
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
            .sheet(isPresented: $showHelp) {
                OnboardingView(isPresented: $showHelp)
            }
        }
    }

    // MARK: - Hero

    private var heroPlaceholder: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(AppTheme.surface)
                .frame(maxWidth: .infinity)
                .frame(height: 220)

            VStack(alignment: .leading, spacing: 4) {
                Text("Start Coloring")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Pick a template and bring it to life.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                Button("Browse Templates") { showTemplateLibrary = true }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding(.top, 4)
                    .accessibilityHint("Opens the template library")
            }
            .padding(20)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.top, 12)
    }

    // MARK: - Daily Challenge

    private var dailyChallengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                SectionHeader(title: "Daily Challenge")
                Spacer()
                if streakCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(streakCount)")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)

            if let template = galleryViewModel.dailyChallengeTemplate {
                DailyChallengeCard(template: template) {
                    DailyChallengeService.recordChallenge()
                    streakCount = DailyChallengeService.currentStreak
                    galleryViewModel.startProject(from: template)
                }
                .padding(.horizontal, AppTheme.screenPadding)
            }
        }
    }

    // MARK: - Recent Work

    private var recentWorkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Recent Work")
                .padding(.horizontal, AppTheme.screenPadding)

            if galleryViewModel.projects.isEmpty {
                Text("No projects yet — start coloring!")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, AppTheme.screenPadding)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(galleryViewModel.recentProjects) { project in
                            RecentWorkCell(project: project) {
                                galleryViewModel.open(project)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                }
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Suggested For You")
                .padding(.horizontal, AppTheme.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(galleryViewModel.suggestedTemplates) { template in
                        SuggestedTemplateCell(template: template) {
                            galleryViewModel.startProject(from: template)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var headerToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("ColorFlow")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showTemplateLibrary = true } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.title3)
            }
            .accessibilityLabel("Browse templates")
        }
        ToolbarItem(placement: .secondaryAction) {
            Button { showHelp = true } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(AppTheme.textSecondary)
                    .font(.title3)
            }
            .accessibilityLabel("Help")
            .accessibilityHint("Shows app tutorial")
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(AppTheme.textPrimary)
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
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .fill(Color.white)
                )

                // Restart badge
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.surface)
                    .background(Circle().fill(Color.white).padding(2))
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(project.templateName)
        .accessibilityHint("Continue coloring")
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let url = StorageService.documentsURL
                    .appendingPathComponent(project.fillLayerPath)
                guard let data = try? Data(contentsOf: url) else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: UIImage(data: data))
            }
        }
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
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(Color.white)
                    .frame(width: 140, height: 140)

                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                } else {
                    Image(systemName: template.category.systemImageName)
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.accent.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
        .accessibilityHint("Start coloring")
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        guard let url = template.svgURL else { return nil }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                if case .success(let geo) = SVGParser.parse(url: url) {
                    let img = TemplateRenderer.renderThumbnail(geometry: geo, size: CGSize(width: 280, height: 280))
                    cont.resume(returning: img)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Daily Challenge Card

private struct DailyChallengeCard: View {
    let template: Template
    let onStart: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(AppTheme.surface)
                    .frame(width: 90, height: 90)
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                } else {
                    Image(systemName: template.category.systemImageName)
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent.opacity(0.6))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(template.difficulty.rawValue)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Button(action: onStart) {
                    Text("Start Challenge")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Starts today's daily challenge template")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .cardShadow()
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        guard let url = template.svgURL else { return nil }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                if case .success(let geo) = SVGParser.parse(url: url) {
                    let img = TemplateRenderer.renderThumbnail(geometry: geo, size: CGSize(width: 180, height: 180))
                    cont.resume(returning: img)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
