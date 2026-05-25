import SwiftUI

@MainActor
struct NavigationShell: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: SableTab = .home
    @State private var path: [AppRoute] = []
    @State private var librarySource: TemplateListViewModel.Source = .explore
    @State private var profileFocus: ProfileFocus?
    @State private var renderTuning = RenderTuningStore()
    @State private var appThemeStore = AppThemeStore()
    @State private var didApplyLaunchRoute = false
    private let repository = SableHomeRepository()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                selectedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 86)

                SableTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 18)
            }
            .background(SableTheme.appBackground(for: colorScheme).ignoresSafeArea())
            #if DEBUG && SHOW_RENDER_METRICS
            .overlay(alignment: .topTrailing) {
                if path.isEmpty {
                    RenderTuningPanel(tuning: renderTuning)
                        .padding(.trailing, 32)
                        .padding(.top, 18)
                }
            }
            #endif
            .toolbar(path.isEmpty ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
            .onAppear(perform: applyLaunchRouteIfNeeded)
        }
        .environment(renderTuning)
        .environment(appThemeStore)
        .preferredColorScheme(appThemeStore.selectedTheme.preferredColorScheme)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .home:
            HomeView(
                repository: repository,
                navigate: navigate,
                openProfile: openProfile,
                openMyWork: openMyWork,
                openCollections: openCollections,
                openRecentlyAdded: openRecentlyAdded
            )
        case .library:
            TemplateListView(
                source: librarySource,
                repository: repository,
                navigate: navigate
            )
            .id(librarySource)
        case .profile:
            ProfileView(repository: repository, focus: profileFocus, navigate: navigate)
                .id(profileFocus)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .coloringPage(let page):
            ColoringCanvasView(
                projectId: page.projectId,
                templateId: page.templateId,
                fallbackTitle: page.title,
                repository: repository
            )
        case .collection(let collection):
            TemplateListView(
                source: .collection(collection),
                repository: repository,
                navigate: navigate
            )
        case .mood(let mood):
            TemplateListView(
                source: .mood(mood),
                repository: repository,
                navigate: navigate
            )
        case .canvas(let route):
            ColoringCanvasView(
                projectId: route.projectId,
                templateId: route.templateId,
                fallbackTitle: route.title,
                repository: repository
            )
        case .search(let query):
            TemplateListView(
                source: .search(query),
                repository: repository,
                navigate: navigate
            )
        }
    }

    private func navigate(to route: AppRoute) {
        path.append(route)
    }

    private func applyLaunchRouteIfNeeded() {
        guard !didApplyLaunchRoute else { return }
        didApplyLaunchRoute = true
        guard let slug = ProcessInfo.processInfo.arguments.launchValue(after: "-gouacheOpenTemplate"),
              let template = Template.loadAll().first(where: { $0.svgFilename == "\(slug).svg" }) else {
            return
        }
        path = [
            .coloringPage(
                ColoringPage(
                    templateId: template.id,
                    title: template.name,
                    progress: 0,
                    thumbnailColorHex: SableTheme.progressPinkHex
                )
            )
        ]
    }

    private func openProfile() {
        path.removeAll()
        profileFocus = nil
        selectedTab = .profile
    }

    private func openMyWork() {
        path.removeAll()
        profileFocus = .myWork
        selectedTab = .profile
    }

    private func openCollections() {
        path.removeAll()
        librarySource = .collections
        selectedTab = .library
    }

    private func openRecentlyAdded() {
        path.removeAll()
        librarySource = .recentlyAdded
        selectedTab = .library
    }
}

private extension [String] {
    func launchValue(after flag: String) -> String? {
        guard let index = firstIndex(of: flag) else { return nil }
        let nextIndex = self.index(after: index)
        guard indices.contains(nextIndex) else { return nil }
        return self[nextIndex]
    }
}

#if DEBUG && SHOW_RENDER_METRICS
private struct RenderTuningPanel: View {
    let tuning: RenderTuningStore
    @State private var isExpanded = false
    @State private var savedValue: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                Label("Render", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(SableTheme.cardBlack, in: Capsule())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    RenderTuningSlider(
                        title: "Thumbnails",
                        value: Binding(
                            get: { tuning.thumbnailStrokeWidth },
                            set: { tuning.thumbnailStrokeWidth = $0 }
                        ),
                        range: RenderTuningStore.thumbnailStrokeWidthRange
                    )

                    RenderTuningSlider(
                        title: "Canvas",
                        value: Binding(
                            get: { tuning.canvasStrokeWidth },
                            set: { tuning.canvasStrokeWidth = $0 }
                        ),
                        range: RenderTuningStore.canvasStrokeWidthRange
                    )

                    HStack(spacing: 12) {
                        Button("Save") {
                            savedValue = tuning.thumbnailStrokeWidth
                        }

                        Button("Reset") {
                            tuning.reset()
                        }
                    }
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(SableTheme.progressPink)

                    if let savedValue {
                        Text("Saved thumbnail line width: \(savedValue, format: .number.precision(.fractionLength(2)))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SableTheme.ink.opacity(0.72))
                    }
                }
                .padding(14)
                .frame(width: 270)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                        .stroke(SableTheme.hairline, lineWidth: 1)
                }
            }
        }
        .accessibilityIdentifier("render.tuning.panel")
    }
}

private struct RenderTuningSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(SableTheme.ink)

                Spacer()

                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(SableTheme.progressPink)
            }

            Slider(value: $value, in: range, step: 0.05)
                .tint(SableTheme.progressPink)
        }
    }
}
#endif

private struct SableTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: SableTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SableTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    let isSelected = selectedTab == tab

                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImageName)
                            .font(.system(size: 18, weight: .medium))

                        Text(tab.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundStyle(isSelected ? selectedForeground : unselectedForeground)
                    .frame(minWidth: 118, minHeight: 38)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(selectedFill)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(tabBarFill, in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
        .shadow(
            color: SableTheme.Shadow.tabBar(for: colorScheme).color,
            radius: SableTheme.Shadow.tabBar(for: colorScheme).radius,
            x: SableTheme.Shadow.tabBar(for: colorScheme).x,
            y: SableTheme.Shadow.tabBar(for: colorScheme).y
        )
    }

    private var tabBarFill: Color {
        colorScheme == .dark ? Color(hex: "#171816").opacity(0.96) : Color(hex: "#F1E7DA").opacity(0.92)
    }

    private var selectedFill: Color {
        colorScheme == .dark ? Color(hex: "#4A3B2E").opacity(0.92) : Color(hex: "#E4D5C2").opacity(0.94)
    }

    private var selectedForeground: Color {
        colorScheme == .dark ? Color(hex: "#F2DEC3") : Color(hex: "#201E1B")
    }

    private var unselectedForeground: Color {
        colorScheme == .dark ? Color(hex: "#BDAE99") : Color(hex: "#6C6258")
    }
}

#Preview("Navigation Shell") {
    NavigationShell()
}

#Preview("Explore Tab") {
    TemplateListView(source: .explore)
}
