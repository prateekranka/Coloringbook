import Foundation

enum TemplateCategory: String, CaseIterable, Codable {
    case mandalas = "Mandalas"
    case animals = "Animals"
    case architecture = "Architecture"
    case abstract = "Abstract"
    case botanicals = "Botanicals"
    case lifestyle = "Lifestyle"

    var systemImageName: String {
        switch self {
        case .mandalas: return "circle.hexagongrid"
        case .animals: return "hare"
        case .architecture: return "building.2"
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
}

struct Template: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let category: TemplateCategory
    let difficulty: Difficulty
    let svgFilename: String      // e.g. "mandala_lotus.svg" inside Resources/Templates/<category>/
    let thumbnailFilename: String // pre-rendered 400×400 PNG cached on first launch

    /// Non-nil only for user-generated templates. When set, `svgURL` resolves
    /// from `Documents/<userTemplateDirectoryPath>/` instead of the bundle.
    var userTemplateDirectoryPath: String?

    var svgURL: URL? {
        // User-generated templates live in Documents/, not the bundle.
        if let dirPath = userTemplateDirectoryPath {
            let url = StorageService.documentsURL
                .appendingPathComponent(dirPath)
                .appendingPathComponent(svgFilename)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }

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
            AppLog.trace(AppLog.template, "Loaded \(templates.count) templates from bundle JSON")
            return templates
        }
        // Falling back to bundled catalogue is recoverable but unexpected in Release.
        AppLog.error(AppLog.template, "Bundle JSON not found — using hardcoded catalogue (\(Self.bundledTemplates.count) templates)")
        return Self.bundledTemplates
    }

    // Mirrors Resources/templates.json — guarantees templates are always
    // available even when the resource file is absent from the bundle.
    static let bundledTemplates: [Template] = [
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

        // ── Phase B4 catalog expansion ───────────────────────────────────────
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000040")!,
                 name: "Afternoon Tea",
                 category: .lifestyle,
                 difficulty: .medium,
                 svgFilename: "afternoon_tea.svg",
                 thumbnailFilename: "thumb_afternoon_tea.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000041")!,
                 name: "Camping Night",
                 category: .lifestyle,
                 difficulty: .medium,
                 svgFilename: "camping_night.svg",
                 thumbnailFilename: "thumb_camping_night.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000042")!,
                 name: "Fish Scales",
                 category: .abstract,
                 difficulty: .easy,
                 svgFilename: "fish_scales.svg",
                 thumbnailFilename: "thumb_fish_scales.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000043")!,
                 name: "Fox Portrait",
                 category: .animals,
                 difficulty: .medium,
                 svgFilename: "fox_portrait.svg",
                 thumbnailFilename: "thumb_fox_portrait.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000044")!,
                 name: "Geometric Star Mandala",
                 category: .mandalas,
                 difficulty: .hard,
                 svgFilename: "geometric_star_mandala.svg",
                 thumbnailFilename: "thumb_geometric_star_mandala.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000045")!,
                 name: "Lighthouse",
                 category: .architecture,
                 difficulty: .medium,
                 svgFilename: "lighthouse.svg",
                 thumbnailFilename: "thumb_lighthouse.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000046")!,
                 name: "Lion Portrait",
                 category: .animals,
                 difficulty: .hard,
                 svgFilename: "lion_portrait.svg",
                 thumbnailFilename: "thumb_lion_portrait.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000047")!,
                 name: "Sea Turtle",
                 category: .animals,
                 difficulty: .medium,
                 svgFilename: "sea_turtle.svg",
                 thumbnailFilename: "thumb_sea_turtle.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000048")!,
                 name: "Snowflake Mandala",
                 category: .mandalas,
                 difficulty: .medium,
                 svgFilename: "snowflake_mandala.svg",
                 thumbnailFilename: "thumb_snowflake_mandala.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000049")!,
                 name: "Stained Glass Abstract",
                 category: .abstract,
                 difficulty: .medium,
                 svgFilename: "stained_glass_abstract.svg",
                 thumbnailFilename: "thumb_stained_glass_abstract.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000050")!,
                 name: "Sunflower Mandala",
                 category: .mandalas,
                 difficulty: .easy,
                 svgFilename: "sunflower_mandala.svg",
                 thumbnailFilename: "thumb_sunflower_mandala.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000051")!,
                 name: "Tropical Leaves",
                 category: .botanicals,
                 difficulty: .easy,
                 svgFilename: "tropical_leaves.svg",
                 thumbnailFilename: "thumb_tropical_leaves.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000052")!,
                 name: "Victorian House",
                 category: .architecture,
                 difficulty: .hard,
                 svgFilename: "victorian_house.svg",
                 thumbnailFilename: "thumb_victorian_house.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000053")!,
                 name: "Wildflower Meadow",
                 category: .botanicals,
                 difficulty: .medium,
                 svgFilename: "wildflower_meadow.svg",
                 thumbnailFilename: "thumb_wildflower_meadow.png"),
    ]
}
