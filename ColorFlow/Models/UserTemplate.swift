import Foundation

/// A line-art template created by the user (e.g. via photo import). Persisted in
/// `Documents/UserTemplates/<id>/`. The photo-import pipeline that produces these
/// is not yet built — this type exists as the persistence contract so that the
/// storage/index code can compile and run unchanged when that pipeline ships.
struct UserTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var preset: String
    var svgFilename: String
    var thumbnailFilename: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        preset: String = "Line Art",
        svgFilename: String = "template.svg",
        thumbnailFilename: String = "thumbnail.png",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.preset = preset
        self.svgFilename = svgFilename
        self.thumbnailFilename = thumbnailFilename
        self.createdAt = createdAt
    }

    var directoryPath: String { "UserTemplates/\(id.uuidString)" }
    var svgPath: String       { "\(directoryPath)/\(svgFilename)" }
    var thumbnailPath: String { "\(directoryPath)/\(thumbnailFilename)" }

    /// Bridge to the bundled `Template` model so the canvas can open a user template
    /// through the same code path as a bundled one.
    func asTemplate() -> Template {
        Template(
            id: id,
            name: name,
            category: .abstract,
            difficulty: .medium,
            svgFilename: svgFilename,
            thumbnailFilename: thumbnailFilename
        )
    }
}
