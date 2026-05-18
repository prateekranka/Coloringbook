import Foundation

enum DrawingEngineMode: String, CaseIterable, Identifiable, Codable {
    case pencilKit = "PencilKit"
    case metalExperimental = "Metal Experimental"

    var id: Self { self }

    var isMetal: Bool {
        self == .metalExperimental
    }

    var displayName: String {
        switch self {
        case .pencilKit: return "PencilKit"
        case .metalExperimental: return "Metal (β)"
        }
    }
}
