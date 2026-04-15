import Foundation

/// A coloring template generated from a user's photo.
///
/// Distinct from `Template` (bundled catalog). Lives in `Documents/UserTemplates/<id>/`
/// and is indexed by `Documents/user_templates.json`.
///
/// A `UserTemplate` represents the line-art source only (no fill state).
/// Projects started from a user template are stored in `projects.json` as normal.
struct UserTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    let preset: String           // PhotoStylePreset.rawValue at creation time

    // File names within the template's subdirectory
    let svgFilename: String
    let thumbnailFilename: String

    // MARK: - Derived paths (relative to Documents/)

    var directoryPath: String  { "UserTemplates/\(id.uuidString)" }
    var svgPath: String        { "\(directoryPath)/\(svgFilename)" }
    var thumbnailPath: String  { "\(directoryPath)/\(thumbnailFilename)" }

    // MARK: - Initialiser

    init(id: UUID = UUID(), name: String, preset: String) {
        self.id               = id
        self.name             = name
        self.createdAt        = Date()
        self.preset           = preset
        self.svgFilename      = "template.svg"
        self.thumbnailFilename = "thumbnail.png"
    }

    // MARK: - Conversion to catalog Template

    /// Produce a transient `Template` so the existing `CanvasViewModel` can
    /// load this user template without any changes to the canvas path.
    func asTemplate() -> Template {
        Template(
            id: id,
            name: name,
            category: .lifestyle,
            difficulty: .medium,
            svgFilename: svgFilename,
            thumbnailFilename: thumbnailFilename,
            userTemplateDirectoryPath: directoryPath
        )
    }

    // MARK: - Equatable / Hashable

    static func == (lhs: UserTemplate, rhs: UserTemplate) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
