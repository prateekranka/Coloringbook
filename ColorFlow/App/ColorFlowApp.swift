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
        }
    }

    // MARK: - UIKit Appearance

    private func configureAppearance() {
        let accentColor = UIColor(AppTheme.accent)

        // ── Tab bar ──────────────────────────────────────────────────────────
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()

        // Selected item: accent purple
        tabAppearance.stackedLayoutAppearance.selected.iconColor = accentColor
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accentColor]

        // Unselected item: system secondary label (adapts to light/dark)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // ── Navigation bar ───────────────────────────────────────────────────
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        // Title colors inherit from UILabel.appearance() — let the system handle them

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
