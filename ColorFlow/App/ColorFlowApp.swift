import SwiftUI
import OSLog

private let appLogger = Logger(subsystem: "com.colorflow.app", category: "App")

@main
struct ColorFlowApp: App {
    @StateObject private var galleryViewModel = GalleryViewModel()

    init() {
        appLogger.fault("[ColorFlowApp] init — app is starting")
        NSLog("[ColorFlowApp] init — app is starting")
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(galleryViewModel)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - UIKit Appearance

    private func configureAppearance() {
        // ── Tab bar ──────────────────────────────────────────────────────────
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppTheme.background)

        // Selected item: accent purple
        let accentColor = UIColor(AppTheme.accent)
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
        navAppearance.backgroundColor = UIColor(AppTheme.background)
        navAppearance.titleTextAttributes      = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accentColor
    }
}

// MARK: - Root Content

struct ContentView: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { hasSeenOnboarding = !$0 }
            ))
        } else {
            MainTabView()
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel

    var body: some View {
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
        .tint(AppTheme.accent)
        // Single canvas presenter — avoids duplicate fullScreenCover conflicts
        // across tabs that all share the same openedProject binding.
        .fullScreenCover(item: $galleryViewModel.openedProject) { item in
            CanvasView(viewModel: CanvasViewModel(project: item.project, template: item.template))
        }
    }
}
