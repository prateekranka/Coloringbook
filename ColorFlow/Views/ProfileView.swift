import SwiftUI

@MainActor
enum ProfileFocus: Hashable {
    case myWork
}

@MainActor
struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppThemeStore.self) private var themeStore
    @State private var viewModel: MyLibraryViewModel
    @AppStorage("gouache.displayName") private var displayName = "Prateek"
    @State private var isSearchExpanded = false
    @State private var isSettingsPresented = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    let focus: ProfileFocus?
    let navigate: (AppRoute) -> Void

    init(
        repository: any HomeRepositoryProtocol = SableHomeRepository(),
        focus: ProfileFocus? = nil,
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: MyLibraryViewModel(repository: repository))
        self.focus = focus
        self.navigate = navigate
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = GouacheProfileMetrics(size: geometry.size)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    profileTopBar(metrics: metrics)

                    if metrics.isLandscape {
                        landscapeStudioLayout(metrics: metrics)
                    } else {
                        profileHero(metrics: metrics)
                        completedSection(metrics: metrics)
                    }
                }
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .center)
                .padding(.horizontal, metrics.horizontalInset)
                .padding(.top, metrics.topContentPadding)
                .padding(.bottom, SableTheme.Spacing.contentAboveTabBar + 32)
                .frame(maxWidth: .infinity)
            }
            .background(SableTheme.gouacheBackground(for: colorScheme).ignoresSafeArea())
            .task {
                await viewModel.load()
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            settingsSheet
        }
    }

    private func landscapeStudioLayout(metrics: GouacheProfileMetrics) -> some View {
        HStack(alignment: .top, spacing: metrics.landscapeColumnGap) {
            profileHero(metrics: metrics)
                .frame(width: metrics.landscapeHeroWidth)

            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                completedSection(metrics: metrics)
                studioDetailsPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func profileTopBar(metrics: GouacheProfileMetrics) -> some View {
        HStack(alignment: .center) {
            Text("Gouache")
                .font(SableTheme.Typography.fraunces(metrics.brandSize, weight: .regular))
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

            Spacer()

            profileSearchControl(metrics: metrics)

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: metrics.actionButtonSize, height: metrics.actionButtonSize)
                    .background(controlFill, in: Circle())
                    .overlay {
                        Circle().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
            .accessibilityLabel("Open profile settings")
        }
        .frame(height: metrics.actionButtonSize)
    }

    private func profileSearchControl(metrics: GouacheProfileMetrics) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(SableTheme.Motion.searchExpand) {
                    isSearchExpanded = true
                }
                isSearchFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: metrics.actionIconSize, weight: .regular))
                    .frame(width: isSearchExpanded ? 32 : metrics.actionButtonSize, height: isSearchExpanded ? 32 : metrics.actionButtonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search completed artwork")

            if isSearchExpanded {
                TextField("Completed artwork", text: $searchText)
                    .font(.system(size: 13, weight: .semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .accessibilityLabel("Search completed artwork")

                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear profile search")
            }
        }
        .padding(.horizontal, isSearchExpanded ? 8 : 0)
        .frame(width: isSearchExpanded ? metrics.searchExpandedWidth : metrics.actionButtonSize, height: metrics.actionButtonSize)
        .background(controlFill, in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
    }

    private func profileHero(metrics: GouacheProfileMetrics) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SableTheme.gouachePanel(for: colorScheme).opacity(colorScheme == .dark ? 0.74 : 0.58))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                }

            VStack(alignment: .leading, spacing: metrics.heroInternalGap) {
                profileIdentity(metrics: metrics)

                profileArtwork(metrics: metrics)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.profileArtworkHeight)
            }
            .padding(metrics.heroPadding)

            GouacheProfileBirdsImage()
                .frame(width: metrics.birdsWidth, height: metrics.birdsHeight)
                .opacity(metrics.birdsOpacity)
                .blendMode(colorScheme == .dark ? .screen : .multiply)
                .position(x: metrics.birdsCenterX, y: metrics.birdsCenterY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(height: metrics.profileHeroHeight)
        .shadow(
            color: SableTheme.Shadow.card(for: colorScheme).color,
            radius: SableTheme.Shadow.card(for: colorScheme).radius,
            x: SableTheme.Shadow.card(for: colorScheme).x,
            y: SableTheme.Shadow.card(for: colorScheme).y
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your Studio. Color slowly. Make it yours. Saved on this iPad.")
    }

    private func profileIdentity(metrics: GouacheProfileMetrics) -> some View {
        HStack(alignment: .center, spacing: metrics.identityGap) {
            GouacheProfileAvatarImage()
                .frame(width: metrics.avatarSize, height: metrics.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your Studio")
                    .font(SableTheme.Typography.fraunces(metrics.profileNameSize, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Color slowly. Make it yours.")
                    .font(.system(size: metrics.profileSubtitleSize, weight: .regular))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))

                localBadge
            }
        }
    }

    private var localBadge: some View {
        HStack(spacing: SableTheme.Spacing.xxs) {
            Image(systemName: "ipad")
                .font(.system(size: 11, weight: .semibold))

            Text("Saved on this iPad")
                .font(SableTheme.Typography.labelTiny.weight(.semibold))
        }
        .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(controlFill.opacity(colorScheme == .dark ? 0.82 : 0.72), in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }

    private func profileArtwork(metrics: GouacheProfileMetrics) -> some View {
        GouacheProfileArtworkImage()
            .clipShape(RoundedRectangle(cornerRadius: metrics.artworkCornerRadius, style: .continuous))
            .mask(
                LinearGradient(
                    colors: profileArtworkMaskColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .brightness(colorScheme == .dark ? 0.045 : 0)
            .overlay {
                if colorScheme == .dark {
                    SableTheme.gouachePrimaryText(for: colorScheme)
                        .opacity(0.08)
                        .blendMode(.screen)
                }
            }
            .accessibilityHidden(true)
    }

    private var profileArtworkMaskColors: [Color] {
        colorScheme == .dark
            ? [.black.opacity(0.32), .black, .black]
            : [.clear, .black, .black]
    }

    @ViewBuilder
    private func completedSection(metrics: GouacheProfileMetrics) -> some View {
        let pages = visibleCompletedPages
        let isSearching = !normalizedSearchQuery.isEmpty

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text(isSearching ? "Search results" : "Completed")
                    .font(SableTheme.Typography.fraunces(24, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

                Spacer()

                if !isSearching && completedPages.count > 0 {
                    Text("\(completedPages.count) \(completedPages.count == 1 ? "artwork" : "artworks")")
                        .font(SableTheme.Typography.labelSmall)
                        .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                }
            }

            if !pages.isEmpty {
                completedArtworkGrid(pages: pages, metrics: metrics)
            } else if isSearching {
                searchEmptyState(query: normalizedSearchQuery)
            } else {
                completedEmptyState(metrics: metrics)
            }
        }
        .accessibilityIdentifier("profile.completed.section")
    }

    @ViewBuilder
    private func completedArtworkGrid(pages: [ColoringPage], metrics: GouacheProfileMetrics) -> some View {
        if metrics.isLandscape {
            LazyVGrid(columns: metrics.completedGridColumns, spacing: metrics.cardGap) {
                ForEach(pages) { page in
                    ProfileCompletedArtworkCard(
                        page: page,
                        imageHeight: metrics.completedImageHeight
                    ) {
                        navigate(.coloringPage(page))
                    }
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: metrics.cardGap) {
                    ForEach(pages) { page in
                        ProfileCompletedArtworkCard(
                            page: page,
                            imageHeight: metrics.completedImageHeight
                        ) {
                            navigate(.coloringPage(page))
                        }
                        .frame(width: metrics.completedCardWidth)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func completedEmptyState(metrics: GouacheProfileMetrics) -> some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
                Text("Start your first page")
                    .font(SableTheme.Typography.fraunces(metrics.emptyStateTitleSize, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

                Text("Choose a template, color at your pace, and completed artwork will collect here.")
                    .font(SableTheme.Typography.bodySmall)
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: metrics.cardGap) {
                ForEach(emptyStateSuggestions) { page in
                    ProfileTemplateSuggestionCard(page: page, imageHeight: metrics.suggestionImageHeight) {
                        navigate(.coloringPage(page))
                    }
                }
            }

            ProfilePrimaryActionButton(title: "Browse Library", systemImage: "book") {
                navigate(.search(""))
            }
        }
        .padding(metrics.emptyStatePadding)
        .background(SableTheme.cardSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }

    private func searchEmptyState(query: String) -> some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
                Text("No completed artwork found")
                    .font(SableTheme.Typography.fraunces(22, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

                Text("Completed artwork matching \"\(query)\" will appear here. You can also search the full Library.")
                    .font(SableTheme.Typography.bodySmall)
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: SableTheme.Spacing.md) {
                ProfilePrimaryActionButton(title: "Search Library", systemImage: "magnifyingglass") {
                    navigate(.search(query))
                }

                Button {
                    clearSearch()
                } label: {
                    Text("Clear Search")
                        .font(SableTheme.Typography.labelLarge)
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                        .frame(height: 44)
                        .padding(.horizontal, SableTheme.Spacing.xl)
                        .background(controlFill, in: Capsule())
                        .overlay {
                            Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear profile search")
            }
        }
        .padding(SableTheme.Spacing.xl)
        .background(SableTheme.cardSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }

    private var studioDetailsPanel: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.lg) {
            ProfileStudioDetailRow(
                systemImage: "checkmark.circle",
                title: "Completed",
                detail: "\(completedPages.count) \(completedPages.count == 1 ? "artwork" : "artworks")"
            )

            ProfileStudioDetailRow(
                systemImage: "ipad",
                title: "Saved on this iPad",
                detail: "Artwork stays local unless you export it."
            )

            ProfileStudioDetailRow(
                systemImage: "circle.lefthalf.filled",
                title: "Appearance",
                detail: themeStore.selectedTheme.title
            )
        }
        .padding(SableTheme.Spacing.xl)
        .background(SableTheme.cardSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }

    private var completedPages: [ColoringPage] {
        viewModel.pages.filter { $0.progress >= 1 }
    }

    private var visibleCompletedPages: [ColoringPage] {
        let query = normalizedSearchQuery
        let pages = completedPages
        guard !query.isEmpty else {
            return Array(pages.prefix(6))
        }

        return Array(
            pages.filter { page in
                page.title.localizedCaseInsensitiveContains(query)
                    || templateName(for: page)?.localizedCaseInsensitiveContains(query) == true
            }
            .prefix(6)
        )
    }

    private var emptyStateSuggestions: [ColoringPage] {
        Template.loadAll()
            .sorted { $0.name < $1.name }
            .prefix(3)
            .map { template in
                ColoringPage(
                    id: template.id,
                    templateId: template.id,
                    title: template.name,
                    progress: 0,
                    thumbnailColorHex: template.category.profileAccentHex
                )
            }
    }

    private func templateName(for page: ColoringPage) -> String? {
        guard let templateId = page.templateId else { return nil }
        return Template.loadAll().first(where: { $0.id == templateId })?.name
    }

    private func clearSearch() {
        isSearchFocused = false
        withAnimation(SableTheme.Motion.searchExpand) {
            searchText = ""
            isSearchExpanded = false
        }
    }

    private var controlFill: Color {
        colorScheme == .dark ? SableTheme.controlFillDark : SableTheme.controlFillLight
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xxl) {
            ProfileSettingRow(title: "Appearance", detail: "Follow the system, stay light, or stay dark.") {
                Picker("Theme", selection: Binding(
                    get: { themeStore.selectedTheme },
                    set: { themeStore.selectedTheme = $0 }
                )) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 310)
                .accessibilityLabel("Theme")
            }

            ProfileSettingRow(title: "Saved on this iPad", detail: "Artwork stays local unless you export it.") {
                Image(systemName: "externaldrive.fill")
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Circle())
                    .accessibilityHidden(true)
            }

            ProfileSettingRow(title: "Help", detail: "Gesture tips, coloring basics, and support.") {
                Image(systemName: "questionmark.circle.fill")
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Circle())
                    .accessibilityHidden(true)
            }

            ProfileSettingRow(title: "About Gouache", detail: "A quiet iPad studio for coloring and keeping a daily art practice.") {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .padding(SableTheme.Spacing.xl)
        .background(SableTheme.cardSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(SableTheme.gouacheBackground(for: colorScheme))
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct GouacheProfileMetrics {
    let size: CGSize

    var isLandscape: Bool {
        size.width > size.height
    }

    private var baseWidth: CGFloat {
        isLandscape ? 1194 : 744
    }

    private var scale: CGFloat {
        max(0.86, min(1.08, size.width / baseWidth))
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * scale
    }

    var contentMaxWidth: CGFloat {
        scaled(isLandscape ? 1510 : 820)
    }

    var horizontalInset: CGFloat {
        scaled(isLandscape ? 42 : 30)
    }

    var topContentPadding: CGFloat {
        scaled(isLandscape ? 18 : 20)
    }

    var sectionSpacing: CGFloat {
        scaled(isLandscape ? 22 : 22)
    }

    var brandSize: CGFloat {
        scaled(13)
    }

    var actionButtonSize: CGFloat {
        scaled(44)
    }

    var actionIconSize: CGFloat {
        scaled(18)
    }

    var searchExpandedWidth: CGFloat {
        scaled(isLandscape ? 330 : 270)
    }

    var landscapeColumnGap: CGFloat {
        scaled(28)
    }

    var landscapeHeroWidth: CGFloat {
        min(scaled(560), size.width * 0.44)
    }

    var profileHeroHeight: CGFloat {
        scaled(isLandscape ? 462 : 368)
    }

    var heroPadding: CGFloat {
        scaled(isLandscape ? 22 : 18)
    }

    var heroInternalGap: CGFloat {
        scaled(isLandscape ? 22 : 14)
    }

    var identityGap: CGFloat {
        scaled(isLandscape ? 20 : 18)
    }

    var avatarSize: CGFloat {
        scaled(isLandscape ? 106 : 78)
    }

    var profileNameSize: CGFloat {
        scaled(isLandscape ? 40 : 31)
    }

    var profileSubtitleSize: CGFloat {
        scaled(isLandscape ? 15 : 13)
    }

    var profileArtworkHeight: CGFloat {
        scaled(isLandscape ? 238 : 170)
    }

    var artworkCornerRadius: CGFloat {
        scaled(isLandscape ? 14 : 12)
    }

    var birdsWidth: CGFloat {
        scaled(isLandscape ? 290 : 230)
    }

    var birdsHeight: CGFloat {
        scaled(isLandscape ? 96 : 76)
    }

    var birdsOpacity: CGFloat {
        isLandscape ? 0.52 : 0.48
    }

    var birdsCenterX: CGFloat {
        scaled(isLandscape ? 378 : 420)
    }

    var birdsCenterY: CGFloat {
        scaled(isLandscape ? 28 : 16)
    }

    var cardGap: CGFloat {
        scaled(isLandscape ? 16 : 14)
    }

    var completedCardWidth: CGFloat {
        scaled(212)
    }

    var completedImageHeight: CGFloat {
        scaled(isLandscape ? 132 : 128)
    }

    var suggestionImageHeight: CGFloat {
        scaled(isLandscape ? 112 : 118)
    }

    var emptyStateTitleSize: CGFloat {
        scaled(isLandscape ? 24 : 22)
    }

    var emptyStatePadding: CGFloat {
        scaled(isLandscape ? 18 : 16)
    }

    var completedGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: cardGap),
            GridItem(.flexible(), spacing: cardGap)
        ]
    }
}

private struct ProfileCompletedArtworkCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: ColoringPage
    let imageHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SableTheme.Spacing.sm) {
                    Text(page.title)
                        .font(SableTheme.Typography.fraunces(18, weight: .semibold))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("Completed")
                        .font(SableTheme.Typography.labelTiny.weight(.bold))
                        .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(SableTheme.gouacheHairline(for: colorScheme).opacity(0.22), in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colorScheme == .dark ? SableTheme.cardFooterDark : SableTheme.cardFooterLight)
            }
            .frame(maxWidth: .infinity)
            .background(SableTheme.gouachePanel(for: colorScheme).opacity(0.74))
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                    .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(
                color: SableTheme.Shadow.cardSmall(for: colorScheme).color,
                radius: SableTheme.Shadow.cardSmall(for: colorScheme).radius,
                x: SableTheme.Shadow.cardSmall(for: colorScheme).x,
                y: SableTheme.Shadow.cardSmall(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open completed artwork, \(page.title)")
        .accessibilityHint("Opens the completed project. Clear Artwork is available in canvas options.")
    }
}

private struct ProfileTemplateSuggestionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: ColoringPage
    let imageHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectArtworkThumbnail(page: page, style: .compact, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .clipped()
                    .background(SableTheme.paper)
                    .accessibilityHidden(true)

                Text(page.title)
                    .font(SableTheme.Typography.labelSmall)
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(colorScheme == .dark ? SableTheme.cardFooterDark : SableTheme.cardFooterLight)
            }
            .frame(maxWidth: .infinity)
            .background(SableTheme.gouachePanel(for: colorScheme).opacity(0.74))
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                    .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start template, \(page.title)")
    }
}

private struct ProfilePrimaryActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SableTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(SableTheme.Typography.labelLarge)
            }
            .foregroundStyle(SableTheme.selectedText(for: colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(SableTheme.selectedSurface(for: colorScheme), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct ProfileStudioDetailRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: SableTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                .frame(width: 26, height: 26)
                .background(SableTheme.gouacheHairline(for: colorScheme).opacity(0.18), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SableTheme.Spacing.xxxs) {
                Text(title)
                    .font(SableTheme.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

                Text(detail)
                    .font(SableTheme.Typography.labelMedium)
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ProfileSettingRow<Accessory: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: SableTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: SableTheme.Spacing.xxxs) {
                Text(title)
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

                Text(detail)
                    .font(SableTheme.Typography.labelMedium)
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
            }

            Spacer()
            accessory
        }
        .accessibilityElement(children: .combine)
    }
}

private extension TemplateCategory {
    var profileAccentHex: String {
        switch self {
        case .animals:
            return MoodCategory.wild.accentHex
        case .architecture:
            return MoodCategory.noir.accentHex
        case .abstract:
            return MoodCategory.bold.accentHex
        case .botanicals:
            return MoodCategory.calm.accentHex
        case .lifestyle:
            return MoodCategory.playful.accentHex
        case .mandalas:
            return MoodCategory.dreamy.accentHex
        }
    }
}

#Preview("Profile") {
    ProfileView(repository: MockHomeRepository())
        .environment(AppThemeStore())
        .environment(RenderTuningStore())
}
