import Foundation
import OSLog

private let templateLogger = Logger(subsystem: "com.colorflow.app", category: "Template")

enum TemplateCategory: String, CaseIterable, Codable {
    case mandalas = "Mandalas"
    case animals = "Animals"
    case abstract = "Abstract"
    case botanicals = "Botanicals"
    case lifestyle = "Lifestyle"

    var systemImageName: String {
        switch self {
        case .mandalas: return "circle.hexagongrid"
        case .animals: return "hare"
        case .abstract: return "square.on.square"
        case .botanicals: return "leaf"
        case .lifestyle: return "cup.and.saucer"
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
        // Bundle.url(forResource:withExtension:subdirectory:) is the correct API
        // for files inside a folder reference (folder reference → Templates/ in bundle).
        let name = (svgFilename as NSString).deletingPathExtension
        let ext  = (svgFilename as NSString).pathExtension

        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Templates")
            // Flat copy fallback (files copied directly to bundle root)
            ?? Bundle.main.url(forResource: name, withExtension: ext)
            // Manual path fallback
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
            templateLogger.fault("[Template] Loaded \(templates.count) templates from bundle JSON")
            NSLog("[Template] Loaded %d templates from bundle JSON", templates.count)
            return templates
        }
        templateLogger.fault("[Template] Bundle JSON not found — using hardcoded catalogue (\(Self.bundledTemplates.count) templates)")
        templateLogger.fault("[Template] Bundle resource URL: \(Bundle.main.resourceURL?.path ?? "nil")")
        NSLog("[Template] Bundle JSON not found — using hardcoded catalogue (%d templates)", Self.bundledTemplates.count)
        NSLog("[Template] Bundle resource URL: %@", Bundle.main.resourceURL?.path ?? "nil")
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

        // ── New lifestyle / scene templates ─────────────────────────────────
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000030")!,
                 name: "Coffee Morning",
                 category: .lifestyle,
                 difficulty: .medium,
                 svgFilename: "coffee_morning.svg",
                 thumbnailFilename: "thumb_coffee_morning.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000031")!,
                 name: "Sleeping Cats",
                 category: .animals,
                 difficulty: .medium,
                 svgFilename: "sleeping_cats.svg",
                 thumbnailFilename: "thumb_sleeping_cats.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000032")!,
                 name: "Cloud Sofa",
                 category: .lifestyle,
                 difficulty: .easy,
                 svgFilename: "cloud_sofa.svg",
                 thumbnailFilename: "thumb_cloud_sofa.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000033")!,
                 name: "Cat Fish Dinner",
                 category: .animals,
                 difficulty: .medium,
                 svgFilename: "cat_fish_dinner.svg",
                 thumbnailFilename: "thumb_cat_fish_dinner.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000034")!,
                 name: "Kitchen Morning",
                 category: .lifestyle,
                 difficulty: .hard,
                 svgFilename: "kitchen_morning.svg",
                 thumbnailFilename: "thumb_kitchen_morning.png"),
    ]
}
