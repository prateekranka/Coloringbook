import SwiftUI

@main
struct ColorFlowApp: App {
    init() {
        #if DEBUG
        PersonaSeedLoader.seedIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationShell()
        }
    }
}
