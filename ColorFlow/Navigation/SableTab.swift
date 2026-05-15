import SwiftUI

enum SableTab: String, CaseIterable, Identifiable {
    case home
    case library
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .library:
            return "Library"
        case .profile:
            return "Profile"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .home:
            return "Home"
        case .library:
            return "Library"
        case .profile:
            return "My Work"
        }
    }

    var systemImageName: String {
        switch self {
        case .home:
            return "house.fill"
        case .library:
            return "rectangle.grid.2x2"
        case .profile:
            return "person.crop.circle"
        }
    }
}
