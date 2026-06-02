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
                    profileHero(metrics: metrics)
                    recentlyCompletedSection(metrics: metrics)
                }
                .padding(.horizontal, metrics.horizontalInset)
                .padding(.top, metrics.topContentPadding)
                .padding(.bottom, 110)
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
            .accessibilityLabel("Settings")
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

            if isSearchExpanded {
                TextField("Search", text: $searchText)
                    .font(.system(size: 13, weight: .semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                Button {
                    isSearchFocused = false
                    withAnimation(SableTheme.Motion.searchExpand) {
                        searchText = ""
                        isSearchExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, isSearchExpanded ? 8 : 0)
        .frame(width: isSearchExpanded ? metrics.searchExpandedWidth : metrics.actionButtonSize, height: metrics.actionButtonSize)
        .background(controlFill, in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
        .accessibilityLabel("Search")
    }

    private func profileHero(metrics: GouacheProfileMetrics) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SableTheme.gouachePanel(for: colorScheme).opacity(colorScheme == .dark ? 0.62 : 0.54))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                }

            if metrics.isLandscape {
                HStack(alignment: .center, spacing: 20) {
                    profileIdentity(metrics: metrics)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 18)

                    GouacheProfileArtworkImage()
                        .frame(width: metrics.profileArtworkWidth, height: metrics.profileArtworkHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .mask(
                            LinearGradient(
                                colors: [.clear, .black, .black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                VStack {
                    Spacer()
                    profileStatsRow
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    profileIdentity(metrics: metrics)

                    GouacheProfileArtworkImage()
                        .frame(maxWidth: .infinity)
                        .frame(height: metrics.profileArtworkHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .mask(
                            LinearGradient(
                                colors: [.clear, .black, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    profileStatsRow
                }
                .padding(18)
            }

            GouacheProfileBirdsImage()
                .frame(width: metrics.birdsWidth, height: metrics.birdsHeight)
                .opacity(metrics.birdsOpacity)
                .blendMode(colorScheme == .dark ? .screen : .multiply)
                .position(x: metrics.birdsCenterX, y: metrics.birdsCenterY)
                .allowsHitTesting(false)
        }
        .frame(height: metrics.profileHeroHeight)
        .shadow(
            color: SableTheme.Shadow.card(for: colorScheme).color,
            radius: SableTheme.Shadow.card(for: colorScheme).radius,
            x: SableTheme.Shadow.card(for: colorScheme).x,
            y: SableTheme.Shadow.card(for: colorScheme).y
        )
        .accessibilityElement(children: .contain)
    }

    private func profileIdentity(metrics: GouacheProfileMetrics) -> some View {
        HStack(spacing: 22) {
            GouacheProfileAvatarImage()
                .frame(width: metrics.avatarSize, height: metrics.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(displayName.isEmpty ? "Prateek" : displayName)
                    .font(SableTheme.Typography.fraunces(metrics.profileNameSize, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Color slowly. Make it yours.")
                    .font(.system(size: metrics.profileSubtitleSize, weight: .regular))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
            }
        }
    }

    private var profileStatsRow: some View {
        HStack(spacing: 12) {
            ProfileStatCard(systemImage: "leaf", title: "Favorite mood", value: "Calm")
            ProfileStatCard(systemImage: "book.closed", title: "Completed pages", value: "\(completedPageCount)")
            ProfileStatCard(systemImage: "camera.macro", title: "Favorite subject", value: "Botanicals")
        }
    }

    @ViewBuilder
    private func recentlyCompletedSection(metrics: GouacheProfileMetrics) -> some View {
        let pages = recentlyCompletedPages

        if !pages.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recently Completed")
                    .font(SableTheme.Typography.fraunces(24, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: metrics.cardGap) {
                        ForEach(pages) { page in
                            ProfileRecentCompletedCard(
                                page: page,
                                width: metrics.recentCardWidth,
                                imageHeight: metrics.recentImageHeight
                            ) {
                                navigate(.coloringPage(page))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var completedPageCount: Int {
        viewModel.pages.filter { $0.progress >= 1 }.count
    }

    private var recentlyCompletedPages: [ColoringPage] {
        let candidates = viewModel.pages.filter { $0.progress > 0.9 }
        let query = normalizedSearchQuery
        let visible = query.isEmpty ? candidates : candidates.filter { $0.title.localizedCaseInsensitiveContains(query) }

        return Array(visible.prefix(5))
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
            }

            ProfileSettingRow(title: "Storage & Sync", detail: "Artwork is saved on this iPad as you color.") {
                Image(systemName: "externaldrive.fill")
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Circle())
            }

            ProfileSettingRow(title: "Help", detail: "Gesture tips, coloring basics, and support.") {
                Image(systemName: "questionmark.circle.fill")
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Circle())
            }

            ProfileSettingRow(title: "About Gouache", detail: "A quiet iPad studio for coloring and keeping a daily art practice.") {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Circle())
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

    var horizontalInset: CGFloat {
        scaled(isLandscape ? 42 : 30)
    }

    var topContentPadding: CGFloat {
        scaled(isLandscape ? 18 : 20)
    }

    var sectionSpacing: CGFloat {
        scaled(isLandscape ? 22 : 26)
    }

    var brandSize: CGFloat {
        scaled(13)
    }

    var actionButtonSize: CGFloat {
        scaled(42)
    }

    var actionIconSize: CGFloat {
        scaled(18)
    }

    var searchExpandedWidth: CGFloat {
        scaled(isLandscape ? 310 : 270)
    }

    var profileHeroHeight: CGFloat {
        scaled(isLandscape ? 350 : 472)
    }

    var avatarSize: CGFloat {
        scaled(isLandscape ? 118 : 96)
    }

    var profileNameSize: CGFloat {
        scaled(isLandscape ? 42 : 32)
    }

    var profileSubtitleSize: CGFloat {
        scaled(isLandscape ? 15 : 13)
    }

    var profileArtworkWidth: CGFloat {
        scaled(isLandscape ? 560 : 648)
    }

    var profileArtworkHeight: CGFloat {
        scaled(isLandscape ? 220 : 205)
    }

    var birdsWidth: CGFloat {
        scaled(isLandscape ? 360 : 280)
    }

    var birdsHeight: CGFloat {
        scaled(isLandscape ? 120 : 90)
    }

    var birdsOpacity: CGFloat {
        isLandscape ? 0.64 : 0.58
    }

    var birdsCenterX: CGFloat {
        scaled(isLandscape ? 924 : 469)
    }

    var birdsCenterY: CGFloat {
        scaled(isLandscape ? 26 : 15)
    }

    var cardGap: CGFloat {
        scaled(isLandscape ? 22 : 16)
    }

    var recentCardWidth: CGFloat {
        scaled(isLandscape ? 248 : 206)
    }

    var recentImageHeight: CGFloat {
        scaled(isLandscape ? 148 : 132)
    }
}

private struct ProfileStatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SableTheme.Typography.fraunces(17, weight: .semibold))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(SableTheme.gouachePanel(for: colorScheme).opacity(0.66), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }
}

private struct ProfileRecentCompletedCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: ColoringPage
    let width: CGFloat
    let imageHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .frame(width: width, height: imageHeight)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    Text(page.title)
                        .font(SableTheme.Typography.fraunces(19, weight: .semibold))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    ProgressTrack(progress: page.progress)
                        .frame(width: 66)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colorScheme == .dark ? SableTheme.cardFooterDark : SableTheme.cardFooterLight)
            }
            .frame(width: width)
            .background(SableTheme.gouachePanel(for: colorScheme).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
            .shadow(
                color: SableTheme.Shadow.cardSmall(for: colorScheme).color,
                radius: SableTheme.Shadow.cardSmall(for: colorScheme).radius,
                x: SableTheme.Shadow.cardSmall(for: colorScheme).x,
                y: SableTheme.Shadow.cardSmall(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.title)
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
    }
}

#Preview("Profile") {
    ProfileView(repository: MockHomeRepository())
        .environment(AppThemeStore())
}
