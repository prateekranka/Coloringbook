import Foundation

enum TemplateCategory: String, CaseIterable, Codable {
    case mandalas = "Mandalas"
    case animals = "Animals"
    case architecture = "Architecture"
    case abstract = "Abstract"
    case botanicals = "Botanicals"

    var systemImageName: String {
        switch self {
        case .mandalas: return "circle.hexagongrid"
        case .animals: return "hare"
        case .architecture: return "building.2"
        case .abstract: return "square.on.square"
        case .botanicals: return "leaf"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
}

struct Template: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let category: TemplateCategory
    let difficulty: Difficulty
    let svgFilename: String      // e.g. "mandala_lotus.svg" inside Resources/Templates/<category>/
    let thumbnailFilename: String // pre-rendered 400×400 PNG cached on first launch

    var svgURL: URL? {
        Bundle.main.url(forResource: svgFilename, withExtension: nil)
    }

    static func == (lhs: Template, rhs: Template) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Manifest Loading

extension Template {
    static func loadAll() -> [Template] {
        guard let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let templates = try? JSONDecoder().decode([Template].self, from: data) else {
            return []
        }
        return templates
    }
}
