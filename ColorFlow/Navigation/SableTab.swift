import SwiftUI

enum SableTab: String, CaseIterable, Identifiable {
    case home
    case explore
    case library

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .explore:
            return "Explore"
        case .library:
            return "My Library"
        }
    }

    var systemImageName: String {
        switch self {
        case .home:
            return "house.fill"
        case .explore:
            return "safari"
        case .library:
            return "books.vertical"
        }
    }
}
