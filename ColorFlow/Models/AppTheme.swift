import Observation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
@Observable
final class AppThemeStore {
    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.themeKey)
        }
    }

    init() {
        let launchTheme = ProcessInfo.processInfo.arguments.launchValue(after: "-gouacheTheme")
        let rawValue = launchTheme ?? UserDefaults.standard.string(forKey: Self.themeKey)
        selectedTheme = rawValue.flatMap(AppTheme.init(rawValue:)) ?? .system
    }

    private static let themeKey = "gouache.appTheme"
}

private extension [String] {
    func launchValue(after flag: String) -> String? {
        guard let index = firstIndex(of: flag) else { return nil }
        let nextIndex = self.index(after: index)
        guard indices.contains(nextIndex) else { return nil }
        return self[nextIndex]
    }
}
