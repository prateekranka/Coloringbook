import SwiftUI

@main
struct ColorFlowApp: App {
    @StateObject private var galleryViewModel = GalleryViewModel()

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
