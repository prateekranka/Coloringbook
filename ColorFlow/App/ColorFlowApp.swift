import SwiftUI
import OSLog

private let appLogger = Logger(subsystem: "com.colorflow.app", category: "App")

@main
struct ColorFlowApp: App {
    @StateObject private var galleryViewModel = GalleryViewModel()

    init() {
        appLogger.debug("[ColorFlowApp] init — app is starting")
        print("[ColorFlowApp] init — app is starting")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(galleryViewModel)
        }
    }
}

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
            GalleryView()
        }
    }
}
