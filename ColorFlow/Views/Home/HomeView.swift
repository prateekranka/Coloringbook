import SwiftUI

/// Home tab — editorial hero, daily pick, continue coloring, and category rails.
struct HomeView: View {
    @Environment(GalleryViewModel.self) var galleryViewModel
    @State private var showTemplateLibrary = false
    @State private var featured: Template?
    @State private var dailyPick: Template?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        featuredHero

                        if let continueProject = galleryViewModel.projects.first {
                            continueColoringCard(project: continueProject)
                        }

                        if let daily = dailyPick {
                            dailySection(template: daily)
                        }

                        recentWorkSection
                        rails
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { headerToolbar }
            .sheet(isPresented: $showTemplateLibrary) {
                TemplateLibraryView()
            }
            .task { assignFeatured() }
        }
    }

    // MARK: - Featured hero

    private var featuredHero: some View {
        Group {
            if let template = featured {
                FeaturedHeroCard(
                    template: template,
                    onOpen: {
                        HapticService.shared.toolChanged()
                        galleryViewModel.startProject(from: template)
                    },
                    onBrowse: {
                        HapticService.shared.toolChanged()
                        showTemplateLibrary = true
                    }
                )
                .padding(.horizontal, AppTheme.screenPadding)
            } else {
                // Data not yet ready — render a clean placeholder that keeps
                // the hero's dimensions so nothing jumps when it arrives.
                RoundedRectangle(cornerRadius: AppTheme.heroCornerRadius, style: .continuous)
                    .fill(AppTheme.surface)
                    .frame(height: 240)
                    .padding(.horizontal, AppTheme.screenPadding)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Continue coloring

    private func continueColoringCard(project: Project) -> some View {
        HStack(spacing: 14) {
            ProjectThumbnail(project: project)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Continue Coloring")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(project.templateName)
                    .font(AppTheme.displayFont(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(project.modifiedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticService.shared.toolChanged()
            galleryViewModel.open(project)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.continueColoring")
    }

    // MARK: - Daily pick

    private func dailySection(template: Template) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.accent)
                Text("Daily Pick")
                    .font(AppTheme.displayFont(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, AppTheme.screenPadding)

            Button {
                HapticService.shared.toolChanged()
                galleryViewModel.startProject(from: template)
            } label: {
                DailyPickCard(template: template)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.screenPadding)
            .accessibilityIdentifier("home.dailyPick")
        }
    }

    // MARK: - Recent work

    private var recentWorkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Recent Work")
                .padding(.horizontal, AppTheme.screenPadding)

            if galleryViewModel.projects.isEmpty {
                HStack {
                    Text("No projects yet — your recent coloring will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, AppTheme.screenPadding)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(galleryViewModel.recentProjects) { project in
                            RecentWorkCell(project: project) {
                                HapticService.shared.toolChanged()
                                galleryViewModel.open(project)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                }
            }
        }
    }

    // MARK: - Rails

    private var rails: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Shuffled suggested rail (existing behavior).
            if !galleryViewModel.suggestedTemplates.isEmpty {
                templateRail(title: "Suggested for you",
                             templates: galleryViewModel.suggestedTemplates,
                             idPrefix: "home.suggested")
            }

            // One rail per non-empty category.
            ForEach(TemplateCategory.allCases, id: \.self) { category in
                let items = templates(in: category)
                if items.count >= 2 {
                    templateRail(title: category.rawValue,
                                 templates: items,
                                 idPrefix: "home.rail.\(category.rawValue)")
                }
            }
        }
    }

    private func templateRail(title: String, templates: [Template], idPrefix: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
                .padding(.horizontal, AppTheme.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        SuggestedTemplateCell(template: template) {
                            HapticService.shared.toolChanged()
                            galleryViewModel.startProject(from: template)
                        }
                        .accessibilityIdentifier("\(idPrefix).\(template.id.uuidString)")
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
            }
        }
    }

    private func templates(in category: TemplateCategory) -> [Template] {
        Template.loadAll().filter { $0.category == category }
    }

    // MARK: - Data helpers

    /// Picks a featured template on appear. The "featured" slot changes per
    /// calendar day to give the home surface a daily refresh even without a
    /// remote feed behind it.
    private func assignFeatured() {
        let all = Template.loadAll()
        guard !all.isEmpty else { return }
        let dayIndex = Int(Date().timeIntervalSince1970 / 86_400)
        featured = all[dayIndex % all.count]
        dailyPick = all[(dayIndex + 1) % all.count]
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var headerToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("ColorFlow")
                .font(AppTheme.displayFont(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showTemplateLibrary = true } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.title3)
            }
            .accessibilityLabel("Browse templates")
            .accessibilityIdentifier("home.plus")
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(AppTheme.displayFont(size: 20, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

// MARK: - Featured hero card

private struct FeaturedHeroCard: View {
    let template: Template
    let onOpen: () -> Void
    let onBrowse: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient backdrop with a brand glow.
            RoundedRectangle(cornerRadius: AppTheme.heroCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2A1C5E"), Color(hex: "#7B5FE8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Template art floats on the right.
            if let img = thumbnail {
                HStack {
                    Spacer()
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .colorInvert()
                        .opacity(0.85)
                        .padding(.trailing, 8)
                }
            } else {
                HStack {
                    Spacer()
                    Image(systemName: template.category.systemImageName)
                        .font(.system(size: 120))
                        .foregroundStyle(.white.opacity(0.18))
                        .padding(.trailing, 24)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Featured this week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.18)))

                Text(template.name)
                    .font(AppTheme.displayFont(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(template.category.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 10) {
                    Button(action: onOpen) {
                        Label("Start Coloring", systemImage: "paintbrush.pointed.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(hex: "#2A1C5E"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.featured.start")

                    Button(action: onBrowse) {
                        Text("Browse All")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.browseTemplates")
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(height: 260)
        .clipped()
        .cardShadow()
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        guard let url = template.svgURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard case .success(let geo) = SVGParser.parse(url: url) else { return nil }
            return TemplateRenderer.renderThumbnail(geometry: geo, size: CGSize(width: 600, height: 600))
        }.value
    }
}

// MARK: - Daily pick card

private struct DailyPickCard: View {
    let template: Template
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 110, height: 110)
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .frame(width: 110, height: 110)
                } else {
                    Image(systemName: template.category.systemImageName)
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.accent.opacity(0.5))
                }
            }
            .cardShadow()

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(AppTheme.displayFont(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("A fresh template, picked for today.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                Text(template.category.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.surface)
        )
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        guard let url = template.svgURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard case .success(let geo) = SVGParser.parse(url: url) else { return nil }
            return TemplateRenderer.renderThumbnail(geometry: geo, size: CGSize(width: 300, height: 300))
        }.value
    }
}

// MARK: - Project thumbnail (reused)

private struct ProjectThumbnail: View {
    let project: Project
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                    Image(systemName: "photo")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .background(Color.white)
        .task { image = await loadThumbnail() }
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

// MARK: - Recent work cell

private struct RecentWorkCell: View {
    let project: Project
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                ProjectThumbnail(project: project)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                    .cardShadow()

                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                    .background(Circle().fill(Color.white).padding(2))
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume \(project.templateName)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.recent.\(project.id.uuidString)")
    }
}

// MARK: - Suggested template cell

private struct SuggestedTemplateCell: View {
    let template: Template
    let onTap: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.94)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                    } else {
                        Image(systemName: template.category.systemImageName)
                            .font(.system(size: 30))
                            .foregroundStyle(AppTheme.accent.opacity(0.4))
                    }
                }
                .frame(width: 150, height: 150)
                .cardShadow()

                Text(template.name)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start coloring: \(template.name)")
        .accessibilityAddTraits(.isButton)
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
