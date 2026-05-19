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
    @AppStorage("gouache.displayName") private var displayName = "Artist"
    @State private var selectedFilter: MyWorkFilter = .all
    @State private var resetPage: ColoringPage?
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
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: SableTheme.Spacing.xxxl) {
                    header
                    settingsPanel
                    myWorkSection
                        .id(ProfileFocus.myWork)
                }
                .padding(.horizontal, SableTheme.Spacing.pageInset)
                .padding(.top, SableTheme.Spacing.xxxl)
                .padding(.bottom, 110)
            }
            .background(SableTheme.appBackground(for: colorScheme).ignoresSafeArea())
            .task {
                await viewModel.load()
                scrollToFocus(with: proxy)
            }
            .onChange(of: focus) { _, _ in
                scrollToFocus(with: proxy)
            }
        }
        .confirmationDialog(
            "Reset this artwork?",
            isPresented: Binding(
                get: { resetPage != nil },
                set: { if !$0 { resetPage = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Reset Artwork", role: .destructive) {
                resetPage = nil
            }
            Button("Cancel", role: .cancel) {
                resetPage = nil
            }
        } message: {
            Text("This will remove all coloring progress and cannot be undone.")
        }
    }

    private func scrollToFocus(with proxy: ScrollViewProxy) {
        guard let focus else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.snappy(duration: 0.28)) {
                proxy.scrollTo(focus, anchor: .top)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
            Text("Profile")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

            Text("A calm desk for your artwork, preferences, and palettes.")
                .font(SableTheme.Typography.bodyMedium.weight(.semibold))
                .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xxl) {
            HStack(spacing: SableTheme.Spacing.xl) {
                ProfileAvatarBadge(name: displayName)

                VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
                    Text("Display Name")
                        .font(SableTheme.Typography.labelMedium.weight(.black))
                        .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))

                    TextField("Display name", text: $displayName)
                        .font(SableTheme.Typography.fraunces(22, weight: .bold))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                        .textFieldStyle(.plain)
                        .padding(.vertical, SableTheme.Spacing.sm)
                        .padding(.horizontal, SableTheme.Spacing.md)
                        .background(SableTheme.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
                }
            }

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

            ProfileSettingRow(title: "Apple Pencil & Touch", detail: "Two-finger undo, three-finger redo, pinch zoom, and clean color regions.") {
                Image(systemName: "hand.point.up.left.fill")
                    .font(SableTheme.Typography.bodyLarge.weight(.bold))
                    .foregroundStyle(SableTheme.progressPink)
                    .frame(width: 34, height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Circle())
            }

            ProfileSettingRow(title: "My Palettes", detail: "A quick view of your current Gouache colors.") {
                HStack(spacing: -SableTheme.Spacing.xxxs) {
                    ForEach([SableTheme.crimson, SableTheme.mist, SableTheme.butter, SableTheme.lavender], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: SableTheme.Border.hairlineWidth))
                    }
                }
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
    }

    private var myWorkSection: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xl) {
            HStack {
                Text("My Work")
                    .font(SableTheme.Typography.sectionTitle)
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

                Spacer()

                SegmentedFilter(options: MyWorkFilter.allCases, selection: $selectedFilter) { $0.title }
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(SableTheme.progressPink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
            } else if filteredPages.isEmpty {
                emptyWork
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 440), spacing: SableTheme.Spacing.xxl)], spacing: SableTheme.Spacing.xxl) {
                    ForEach(filteredPages) { page in
                        MyWorkCard(
                            page: page,
                            open: { navigate(.coloringPage(page)) },
                            duplicate: {},
                            share: {},
                            reset: { resetPage = page }
                        )
                    }
                }
            }
        }
    }

    private var filteredPages: [ColoringPage] {
        switch selectedFilter {
        case .all:
            return viewModel.pages
        case .incomplete:
            return viewModel.pages.filter { $0.progress < 1 }
        case .complete:
            return viewModel.pages.filter { $0.progress >= 1 }
        }
    }

    private var emptyWork: some View {
        VStack(spacing: SableTheme.Spacing.md) {
            Image(systemName: "paintpalette")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(SableTheme.progressPink)

            Text("Your saved artwork will appear here.")
                .font(SableTheme.Typography.bodyMedium.weight(.semibold))
                .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(SableTheme.cardSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
    }
}

private enum MyWorkFilter: String, CaseIterable, Identifiable {
    case all
    case incomplete
    case complete

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .incomplete:
            return "Incomplete"
        case .complete:
            return "Complete"
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
    }
}

private struct ProfileAvatarBadge: View {
    let name: String

    var body: some View {
        ZStack {
            Circle()
                .fill(SableTheme.blush.opacity(0.72))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(SableTheme.ink)
        }
        .frame(width: 72, height: 72)
        .overlay {
            Circle().stroke(SableTheme.ink.opacity(0.14), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }
}

private struct MyWorkCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: ColoringPage
    let open: () -> Void
    let duplicate: () -> Void
    let share: () -> Void
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: open) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .aspectRatio(1.34, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.project.\(page.title.normalizedIdentifier)")

            VStack(alignment: .leading, spacing: SableTheme.Spacing.md) {
                HStack(spacing: SableTheme.Spacing.md) {
                    Text(page.title)
                        .font(SableTheme.Typography.fraunces(21, weight: .black))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer()

                    Text("\(Int((page.progress * 100).rounded()))%")
                        .font(SableTheme.Typography.labelLarge.weight(.black))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                }

                ProgressTrack(progress: page.progress)

                HStack(spacing: SableTheme.Spacing.sm) {
                    actionButton("Duplicate", systemImage: "plus.square.on.square", action: duplicate)
                    actionButton("Share", systemImage: "square.and.arrow.up", action: share)
                    actionButton("Reset", systemImage: "arrow.counterclockwise", role: .destructive, action: reset)
                }
            }
            .padding(SableTheme.Spacing.lg)
        }
        .background(SableTheme.cardSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
    }

    private func actionButton(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(SableTheme.Typography.bodyMedium.weight(.bold))
                .frame(width: 36, height: 34)
                .background(SableTheme.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? SableTheme.crimson : SableTheme.gouachePrimaryText(for: colorScheme))
        .accessibilityLabel(title)
    }
}

#Preview("Profile") {
    ProfileView(repository: MockHomeRepository())
        .environment(AppThemeStore())
}
