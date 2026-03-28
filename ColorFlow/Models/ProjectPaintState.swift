import Foundation

// MARK: - StampEntry

struct StampEntry: Codable {
    let id: UUID
    let shape: StampShape
    let centerX: Double   // document coordinate
    let centerY: Double
    let size: Double      // radius in document points
    let hexColor: String
}

// MARK: - ProjectPaintState

/// Mutable per-project paint state, persisted as JSON alongside the project.
/// Separated from TemplateGeometry so geometry can be shared/cached across projects.
struct ProjectPaintState: Codable {
    /// Region fill colors: regionID → hex color string (e.g., "petal-1": "#FF6B6B")
    var regionFills: [String: String] = [:]

    /// PencilKit freehand drawing data (PKDrawing serialized)
    var freehandDrawingData: Data?

    /// Currently selected region ID (transient — not persisted)
    var selectedRegionID: String?

    /// Placed stamps (persisted)
    var stamps: [StampEntry] = []

    enum CodingKeys: String, CodingKey {
        case regionFills
        case freehandDrawingData
        case stamps
        // selectedRegionID is intentionally excluded — it's transient
    }
}
