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
    let svgFilename: String
    let thumbnailFilename: String
    var lineArtFilename: String? = nil
    var userTemplateDirectoryPath: String?

    var slug: String {
        (svgFilename as NSString).deletingPathExtension
    }

    var addedSortIndex: Int {
        Self.expectedCatalogSlugs.firstIndex(of: slug) ?? -1
    }

    var svgURL: URL? {
        if let dirPath = userTemplateDirectoryPath {
            let url = StorageService.documentsURL
                .appendingPathComponent(dirPath)
                .appendingPathComponent(svgFilename)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }

        let name = (svgFilename as NSString).deletingPathExtension
        let ext = (svgFilename as NSString).pathExtension

        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Templates")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.resourceURL.flatMap {
                let url = $0.appendingPathComponent("Templates/\(svgFilename)")
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
    }

    var lineArtURL: URL? {
        let filename = lineArtFilename ?? "\(slug).png"
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "TemplateLineArt")
            ?? Bundle.main.resourceURL.flatMap {
                let url = $0.appendingPathComponent("TemplateLineArt/\(filename)")
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
    }

    static func == (lhs: Template, rhs: Template) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Template {
    static func loadAll() -> [Template] {
        if let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let templates = try? JSONDecoder().decode([Template].self, from: data),
           !templates.isEmpty {
            if hasExpectedCatalogSlugs(templates) {
                AppLog.trace(AppLog.template, "Loaded \(templates.count) templates from bundle JSON")
                return templates
            }
            AppLog.error(AppLog.template, "Bundle JSON has unexpected catalogue; using hardcoded catalogue (\(bundledTemplates.count) templates)")
            return bundledTemplates
        }

        AppLog.error(AppLog.template, "Bundle JSON not found; using hardcoded catalogue (\(bundledTemplates.count) templates)")
        return bundledTemplates
    }

    private static func hasExpectedCatalogSlugs(_ templates: [Template]) -> Bool {
        templates.count == expectedCatalogSlugs.count
            && Set(templates.map(\.slug)) == Set(expectedCatalogSlugs)
    }

    static let expectedCatalogSlugs = [
        "wildflowers",
        "lemon-branch",
        "sunday-light",
        "amalfi-afternoon",
        "toucan-canopy",
        "lemon-balcony",
        "quiet-balcony-room",
        "rainy-library",
        "mediterranean-kitchen-window",
        "florist-window"
    ]

    static let bundledTemplates: [Template] = [
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000101")!,
                 name: "Wildflowers",
                 category: .botanicals,
                 difficulty: .easy,
                 svgFilename: "wildflowers.svg",
                 thumbnailFilename: "thumb-wildflowers.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000102")!,
                 name: "Lemon Branch",
                 category: .botanicals,
                 difficulty: .easy,
                 svgFilename: "lemon-branch.svg",
                 thumbnailFilename: "thumb-lemon-branch.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000103")!,
                 name: "Sunday Light",
                 category: .lifestyle,
                 difficulty: .medium,
                 svgFilename: "sunday-light.svg",
                 thumbnailFilename: "thumb-sunday-light.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000104")!,
                 name: "Amalfi Afternoon",
                 category: .architecture,
                 difficulty: .medium,
                 svgFilename: "amalfi-afternoon.svg",
                 thumbnailFilename: "thumb-amalfi-afternoon.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000105")!,
                 name: "Toucan Canopy",
                 category: .animals,
                 difficulty: .medium,
                 svgFilename: "toucan-canopy.svg",
                 thumbnailFilename: "thumb-toucan-canopy.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000106")!,
                 name: "Lemon Balcony",
                 category: .lifestyle,
                 difficulty: .medium,
                 svgFilename: "lemon-balcony.svg",
                 thumbnailFilename: "thumb-lemon-balcony.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000107")!,
                 name: "Quiet Balcony Room",
                 category: .lifestyle,
                 difficulty: .easy,
                 svgFilename: "quiet-balcony-room.svg",
                 thumbnailFilename: "thumb-quiet-balcony-room.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000108")!,
                 name: "Rainy Library",
                 category: .lifestyle,
                 difficulty: .medium,
                 svgFilename: "rainy-library.svg",
                 thumbnailFilename: "thumb-rainy-library.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000109")!,
                 name: "Mediterranean Kitchen Window",
                 category: .lifestyle,
                 difficulty: .medium,
                 svgFilename: "mediterranean-kitchen-window.svg",
                 thumbnailFilename: "thumb-mediterranean-kitchen-window.png"),
        Template(id: UUID(uuidString: "33333333-0000-0000-0000-000000000110")!,
                 name: "Florist Window",
                 category: .botanicals,
                 difficulty: .hard,
                 svgFilename: "florist-window.svg",
                 thumbnailFilename: "thumb-florist-window.png"),
    ]
}
