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
                VStack(alignment: .leading, spacing: 26) {
                    header
                    settingsPanel
                    myWorkSection
                        .id(ProfileFocus.myWork)
                }
                .padding(.horizontal, SableTheme.Spacing.pageInset)
                .padding(.top, 30)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(SableTheme.primaryText(for: colorScheme))

            Text("A calm desk for your artwork, preferences, and palettes.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ProfileAvatarBadge(name: displayName)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(SableTheme.secondaryText(for: colorScheme))

                    TextField("Display name", text: $displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                        .textFieldStyle(.plain)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(SableTheme.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
                }
            }

            ProfileSettingRow(title: "Theme", detail: "System, Light, or Dark") {
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

            ProfileSettingRow(title: "Gesture & Input", detail: "Apple Pencil colors; finger drag pans; pinch zooms") {
                Text("Configured")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(SableTheme.surface(for: colorScheme), in: Capsule())
            }

            ProfileSettingRow(title: "Saved Palettes", detail: "Custom palette structure is ready for the next pass") {
                HStack(spacing: -4) {
                    ForEach(["#D4213D", "#2BBCB3", "#F6CF85", "#7B68AE"], id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
                    }
                }
            }
        }
        .padding(20)
        .background(SableTheme.elevatedSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                .stroke(SableTheme.hairline(for: colorScheme), lineWidth: 1)
        }
    }

    private var myWorkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Work")
                    .font(SableTheme.Font.sectionTitle)
                    .foregroundStyle(SableTheme.primaryText(for: colorScheme))

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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 440), spacing: 18)], spacing: 18) {
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
        VStack(spacing: 12) {
            Image(systemName: "paintpalette")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(SableTheme.progressPink)

            Text("Your saved artwork will appear here.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(SableTheme.elevatedSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SableTheme.primaryText(for: colorScheme))

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
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
            Circle().stroke(SableTheme.ink.opacity(0.14), lineWidth: 1)
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

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer()

                    Text("\(Int((page.progress * 100).rounded()))%")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                }

                ProgressTrack(progress: page.progress)

                HStack(spacing: 10) {
                    actionButton("Duplicate", systemImage: "plus.square.on.square", action: duplicate)
                    actionButton("Share", systemImage: "square.and.arrow.up", action: share)
                    actionButton("Reset", systemImage: "arrow.counterclockwise", role: .destructive, action: reset)
                }
            }
            .padding(15)
        }
        .background(SableTheme.elevatedSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                .stroke(SableTheme.hairline(for: colorScheme), lineWidth: 1)
        }
    }

    private func actionButton(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 36, height: 34)
                .background(SableTheme.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? SableTheme.crimson : SableTheme.primaryText(for: colorScheme))
        .accessibilityLabel(title)
    }
}

#Preview("Profile") {
    ProfileView(repository: MockHomeRepository())
        .environment(AppThemeStore())
}
