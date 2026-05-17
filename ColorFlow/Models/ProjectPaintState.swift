import Foundation

/// Mutable per-project paint state, persisted as JSON alongside the project.
/// Separated from TemplateGeometry so geometry can be shared/cached across projects.
struct ProjectPaintState: Codable {
    var version: Int = 2

    var pigmentLayerFilename: String?

    /// Region fill colors: regionID → hex color string (e.g., "petal-1": "#FF6B6B")
    var regionFills: [String: String] = [:]

    /// PencilKit freehand drawing data (PKDrawing serialized)
    var freehandDrawingData: Data?

    /// Structured stroke/action history for the hybrid canvas foundation.
    var strokeActions: [StrokeAction] = []

    var canvasState = CanvasState()

    init(
        regionFills: [String: String] = [:],
        pigmentLayerFilename: String? = nil,
        freehandDrawingData: Data? = nil,
        strokeActions: [StrokeAction] = [],
        canvasState: CanvasState = CanvasState()
    ) {
        self.version = 2
        self.regionFills = regionFills
        self.pigmentLayerFilename = pigmentLayerFilename
        self.freehandDrawingData = freehandDrawingData
        self.strokeActions = strokeActions
        self.canvasState = canvasState
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case pigmentLayerFilename
        case regionFills
        case freehandDrawingData
        case strokeActions
        case canvasState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        pigmentLayerFilename = try container.decodeIfPresent(String.self, forKey: .pigmentLayerFilename)
        regionFills = try container.decodeIfPresent([String: String].self, forKey: .regionFills) ?? [:]
        freehandDrawingData = try container.decodeIfPresent(Data.self, forKey: .freehandDrawingData)
        strokeActions = try container.decodeIfPresent([StrokeAction].self, forKey: .strokeActions) ?? []
        canvasState = try container.decodeIfPresent(CanvasState.self, forKey: .canvasState) ?? CanvasState()
    }
}
