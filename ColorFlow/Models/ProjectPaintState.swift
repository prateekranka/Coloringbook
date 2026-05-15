import Foundation

/// Mutable per-project paint state, persisted as JSON alongside the project.
/// Separated from TemplateGeometry so geometry can be shared/cached across projects.
struct ProjectPaintState: Codable {
    /// Region fill colors: regionID → hex color string (e.g., "petal-1": "#FF6B6B")
    var regionFills: [String: String] = [:]

    /// PencilKit freehand drawing data (PKDrawing serialized)
    var freehandDrawingData: Data?

    /// Structured stroke/action history for the hybrid canvas foundation.
    var strokeActions: [StrokeAction] = []

    var canvasState = CanvasState()

    init(
        regionFills: [String: String] = [:],
        freehandDrawingData: Data? = nil,
        strokeActions: [StrokeAction] = [],
        canvasState: CanvasState = CanvasState()
    ) {
        self.regionFills = regionFills
        self.freehandDrawingData = freehandDrawingData
        self.strokeActions = strokeActions
        self.canvasState = canvasState
    }

    private enum CodingKeys: String, CodingKey {
        case regionFills
        case freehandDrawingData
        case strokeActions
        case canvasState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        regionFills = try container.decodeIfPresent([String: String].self, forKey: .regionFills) ?? [:]
        freehandDrawingData = try container.decodeIfPresent(Data.self, forKey: .freehandDrawingData)
        strokeActions = try container.decodeIfPresent([StrokeAction].self, forKey: .strokeActions) ?? []
        canvasState = try container.decodeIfPresent(CanvasState.self, forKey: .canvasState) ?? CanvasState()
    }
}
