import Foundation

/// Mutable per-project paint state, persisted as JSON alongside the project.
/// Separated from TemplateGeometry so geometry can be shared/cached across projects.
struct ProjectPaintState: Codable {
    /// Region fill colors: regionID → hex color string (e.g., "petal-1": "#FF6B6B")
    var regionFills: [String: String] = [:]

    /// PencilKit freehand drawing data (PKDrawing serialized)
    var freehandDrawingData: Data?
}
