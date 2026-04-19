import SwiftUI

@main
struct ColorFlowApp: App {
    @State private var galleryViewModel = GalleryViewModel()

    init() {
        AppLog.trace(AppLog.app, "init — app is starting")
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(galleryViewModel)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - UIKit Appearance

    private func configureAppearance() {
        // ── Tab bar ──────────────────────────────────────────────────────────
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1) // CFBackground

        // Selected item: accent purple
        let accentColor = UIColor(red: 0.482, green: 0.373, blue: 0.910, alpha: 1)
        tabAppearance.stackedLayoutAppearance.selected.iconColor   = accentColor
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accentColor]

        // Unselected item: dim white
        let dimColor = UIColor(white: 0.55, alpha: 1)
        tabAppearance.stackedLayoutAppearance.normal.iconColor    = dimColor
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: dimColor]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // ── Navigation bar ───────────────────────────────────────────────────
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
        navAppearance.titleTextAttributes      = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accentColor
    }
}

// MARK: - Root Content

struct ContentView: View {
    @Environment(GalleryViewModel.self) var galleryViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    /// True only for this process lifetime. Scene-phase reactivations
    /// from background do NOT replay the splash because the flag sticks.
    @State private var splashDone: Bool

    init() {
        let skipSplash = ProcessInfo.processInfo.arguments.contains("-skipSplash")
            || ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
        _splashDone = State(initialValue: skipSplash)
    }

    /// UI tests launch with "-skipOnboarding" to bypass the flow deterministically.
    private var skipOnboardingForTests: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
    }

    var body: some View {
        ZStack {
            if !hasSeenOnboarding && !skipOnboardingForTests {
                OnboardingView(isPresented: Binding(
                    get: { !hasSeenOnboarding },
                    set: { hasSeenOnboarding = !$0 }
                ))
            } else {
                MainTabView()
            }

            if !splashDone {
                SplashView(onFinish: { splashDone = true })
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(AppTheme.Motion.pageTransition, value: splashDone)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(GalleryViewModel.self) var galleryViewModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .accessibilityIdentifier("tab.home")

            LibraryTabView()
                .tabItem {
                    Label("Library", systemImage: "book.fill")
                }
                .accessibilityIdentifier("tab.library")

            MyWorkView()
                .tabItem {
                    Label("My Work", systemImage: "person.fill")
                }
                .accessibilityIdentifier("tab.myWork")
        }
        // Force classic bottom tab bar — iOS 18 iPad defaults to a sidebar/top style.
        .tint(AppTheme.accent)
        // Single canvas presenter — avoids duplicate fullScreenCover conflicts
        // across tabs that all share the same openedProject binding.
        .fullScreenCover(item: Bindable(galleryViewModel).openedProject) { item in
            CanvasView(viewModel: CanvasViewModel(project: item.project, template: item.template))
        }
    }
}
