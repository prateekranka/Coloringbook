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
    let svgFilename: String       // e.g. "mandala_lotus.svg" inside Resources/Templates/
    let thumbnailFilename: String // pre-rendered 400×400 PNG cached on first launch

    // MARK: - Remote content hooks (workstream B)
    // All optional so existing bundled manifests decode unchanged.

    /// When this template was added to the catalogue. Used to flag "NEW" badges.
    var addedAt: Date?

    /// Whether this template is hand-picked to appear in the editorial hero.
    var featured: Bool?

    /// Curated collection keys — e.g. ["spring_mandalas", "cozy_lifestyles"].
    var collections: [String]?

    /// Remote URL that hosts the raw SVG when the file isn't bundled. When
    /// present and the file isn't already cached locally, `ContentService`
    /// fetches it to `Caches/content/svgs/` before rendering.
    var remoteSVGURL: URL?

    /// Remote URL for a pre-rendered preview PNG. When present, views should
    /// prefer it to avoid rasterising the SVG on-device.
    var remotePreviewURL: URL?

    init(
        id: UUID,
        name: String,
        category: TemplateCategory,
        difficulty: Difficulty,
        svgFilename: String,
        thumbnailFilename: String,
        addedAt: Date? = nil,
        featured: Bool? = nil,
        collections: [String]? = nil,
        remoteSVGURL: URL? = nil,
        remotePreviewURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.svgFilename = svgFilename
        self.thumbnailFilename = thumbnailFilename
        self.addedAt = addedAt
        self.featured = featured
        self.collections = collections
        self.remoteSVGURL = remoteSVGURL
        self.remotePreviewURL = remotePreviewURL
    }

    /// Resolves a usable SVG URL. Priority:
    /// 1. Bundled resource (Templates subdirectory, then flat bundle root)
    /// 2. Downloaded file in the content cache (`Caches/content/svgs/<filename>`)
    /// 3. nil (caller may trigger a remote download via ContentService)
    var svgURL: URL? {
        let name = (svgFilename as NSString).deletingPathExtension
        let ext  = (svgFilename as NSString).pathExtension

        if let bundled = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Templates") {
            return bundled
        }
        if let flat = Bundle.main.url(forResource: name, withExtension: ext) {
            return flat
        }
        if let manualBundle = Bundle.main.resourceURL?
            .appendingPathComponent("Templates/\(svgFilename)"),
           FileManager.default.fileExists(atPath: manualBundle.path) {
            return manualBundle
        }
        // Remote-cached fallback.
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("content/svgs/\(svgFilename)")
        if let cache, FileManager.default.fileExists(atPath: cache.path) {
            return cache
        }
        return nil
    }

    static func == (lhs: Template, rhs: Template) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Manifest Loading

extension Template {
    static func loadAll() -> [Template] {
        // Remote-backed manifest takes priority if ContentService has fetched one.
        if let remote = ContentService.shared.cachedTemplates(), !remote.isEmpty {
            return remote
        }
        // Bundled JSON fallback.
        if let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let templates = try? JSONDecoder.contentDecoder.decode([Template].self, from: data),
           !templates.isEmpty {
            AppLog.trace(AppLog.template, "Loaded \(templates.count) templates from bundle JSON")
            return templates
        }
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
    ]
}

// MARK: - JSON helpers

extension JSONDecoder {
    /// JSON decoder used for template manifests. Accepts ISO-8601 dates so a
    /// hosted `templates.json` can include readable `addedAt` strings.
    static let contentDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension JSONEncoder {
    static let contentEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
