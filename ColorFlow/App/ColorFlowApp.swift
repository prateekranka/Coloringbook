import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var appearance: AppearancePreference {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appearance") ?? "system"
        appearance = AppearancePreference(rawValue: raw) ?? .system
    }
}

@main
struct ColorFlowApp: App {
    @State private var galleryViewModel = GalleryViewModel()

    init() {
        AppLog.trace(AppLog.app, "init — app is starting")
        configureAppearance()
        #if DEBUG
        PersonaSeedLoader.seedIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(galleryViewModel)
                .environment(AppState.shared)
        }
    }

    // MARK: - UIKit Appearance

    private func configureAppearance() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.082, green: 0.071, blue: 0.063, alpha: 1)
                : UIColor.white
        }

        let accent = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.478, green: 0.722, blue: 0.529, alpha: 1)
                : UIColor(red: 0.431, green: 0.620, blue: 0.478, alpha: 1)
        }
        tabBar.stackedLayoutAppearance.selected.iconColor = accent
        tabBar.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]

        let dim = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.45, alpha: 1)
                : UIColor(white: 0.55, alpha: 1)
        }
        tabBar.stackedLayoutAppearance.normal.iconColor = dim
        tabBar.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: dim]

        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navBar = UINavigationBarAppearance()
        navBar.configureWithOpaqueBackground()
        navBar.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.082, green: 0.071, blue: 0.063, alpha: 1)
                : UIColor.white
        }
        navBar.titleTextAttributes = [.foregroundColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.961, green: 0.937, blue: 0.902, alpha: 1)
                : UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1)
        }]
        navBar.largeTitleTextAttributes = navBar.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
        UINavigationBar.appearance().tintColor = accent
    }
}

// MARK: - Root Content

struct ContentView: View {
    @Environment(GalleryViewModel.self) var galleryViewModel
    @Environment(AppState.self) private var appState
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
    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { hasSeenOnboarding = !$0 }
        )
    }

    private var skipOnboardingForTests: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
    }

    var body: some View {
        ZStack {
            if !hasSeenOnboarding && !skipOnboardingForTests {
                OnboardingView(isPresented: onboardingBinding)
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
        .preferredColorScheme(appState.appearance.colorScheme)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(GalleryViewModel.self) var galleryViewModel

    var body: some View {
        // Note: SwiftUI TabView's .tabItem buttons don't accept accessibility
        // identifiers on iPadOS 18+. Tests should query by label text
        // (app.tabBars.buttons["Home"]) instead of a "tab.*" identifier.
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            LibraryTabView()
                .tabItem {
                    Label("Library", systemImage: "book.fill")
                }

            MyWorkView()
                .tabItem {
                    Label("My Work", systemImage: "person.fill")
                }
        }
        // Force classic bottom tab bar — iOS 18 iPad defaults to a sidebar/top style.
        .tint(AppTheme.Brand.accent)
        // Single canvas presenter — avoids duplicate fullScreenCover conflicts
        // across tabs that all share the same openedProject binding.
        .fullScreenCover(item: Bindable(galleryViewModel).openedProject) { item in
            CanvasView(viewModel: CanvasViewModel(project: item.project, template: item.template))
        }
    }
}
