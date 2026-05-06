import SwiftUI

@MainActor
struct NavigationShell: View {
    @State private var selectedTab: SableTab = .home
    @State private var path: [AppRoute] = []
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
            .background(SableTheme.cream.ignoresSafeArea())
            .toolbar(path.isEmpty ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .home:
            HomeView(repository: repository, navigate: navigate)
        case .explore:
            PlaceholderTabScreen(tab: .explore)
        case .library:
            MyLibraryView(repository: repository, navigate: navigate)
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
        }
    }

    private func navigate(to route: AppRoute) {
        path.append(route)
    }
}

private struct SableTabBar: View {
    @Binding var selectedTab: SableTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SableTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.systemImageName)
                            .font(.system(size: 24, weight: .semibold))

                        Text(tab.title)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? SableTheme.progressPink : SableTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .frame(maxWidth: 820)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
    }
}

private struct PlaceholderTabScreen: View {
    let tab: SableTab

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tab.systemImageName)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(SableTheme.crimson)

            Text(tab.title)
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(SableTheme.ink)

            Text("Coming soon")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SableTheme.mutedInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SableTheme.cream)
    }
}

#Preview("Navigation Shell") {
    NavigationShell()
}

#Preview("Explore Tab") {
    PlaceholderTabScreen(tab: .explore)
}
