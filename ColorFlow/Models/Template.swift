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
        // Try bundle root first (flat copy), then inside a "Templates" subdirectory
        // (XcodeGen folder-reference copy).
        Bundle.main.url(forResource: svgFilename, withExtension: nil)
            ?? Bundle.main.url(forResource: "Templates/\(svgFilename)", withExtension: nil)
            ?? Bundle.main.resourceURL.flatMap {
                let url = $0.appendingPathComponent("Templates/\(svgFilename)")
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
    }

    static func == (lhs: Template, rhs: Template) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Manifest Loading

extension Template {
    static func loadAll() -> [Template] {
        // Try bundle JSON first; fall back to the embedded catalogue.
        if let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let templates = try? JSONDecoder().decode([Template].self, from: data),
           !templates.isEmpty {
            print("[Template] Loaded \(templates.count) templates from bundle JSON")
            return templates
        }
        print("[Template] Bundle JSON not found — using hardcoded catalogue (\(Self.bundledTemplates.count) templates)")
        print("[Template] Bundle resource URL: \(Bundle.main.resourceURL?.path ?? "nil")")
        return Self.bundledTemplates
    }

    // Mirrors Resources/templates.json — guarantees templates are always
    // available even when the resource file is absent from the bundle.
    private static let bundledTemplates: [Template] = [
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000001")!,
                 name: "Lotus Mandala",
                 category: .mandalas,
                 difficulty: .medium,
                 svgFilename: "lotus_mandala.svg",
                 thumbnailFilename: "thumb_lotus_mandala.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000006")!,
                 name: "Owl Portrait",
                 category: .animals,
                 difficulty: .medium,
                 svgFilename: "owl_portrait.svg",
                 thumbnailFilename: "thumb_owl_portrait.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000009")!,
                 name: "Butterfly Garden",
                 category: .animals,
                 difficulty: .easy,
                 svgFilename: "butterfly_garden.svg",
                 thumbnailFilename: "thumb_butterfly_garden.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000021")!,
                 name: "Rose Bouquet",
                 category: .botanicals,
                 difficulty: .medium,
                 svgFilename: "rose_bouquet.svg",
                 thumbnailFilename: "thumb_rose_bouquet.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000017")!,
                 name: "Wave Pattern",
                 category: .abstract,
                 difficulty: .medium,
                 svgFilename: "wave_pattern.svg",
                 thumbnailFilename: "thumb_wave_pattern.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000016")!,
                 name: "Hexagon Grid",
                 category: .abstract,
                 difficulty: .easy,
                 svgFilename: "hexagon_grid.svg",
                 thumbnailFilename: "thumb_hexagon_grid.png"),
    ]
}
