import Foundation

enum FillPattern: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case dots = "Dots"
    case stripes = "Stripes"
    case crosshatch = "Crosshatch"
    case checker = "Checker"

    var id: String { rawValue }
    var systemImageName: String {
        switch self {
        case .none: return "square"
        case .dots: return "circle.grid.3x3"
        case .stripes: return "line.diagonal"
        case .crosshatch: return "grid"
        case .checker: return "checkerboard.rectangle"
        }
    }
}
