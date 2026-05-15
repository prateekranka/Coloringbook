import Foundation
import Observation

@MainActor
@Observable
final class RenderTuningStore {
    var thumbnailStrokeWidth: Double {
        didSet { defaults.set(thumbnailStrokeWidth, forKey: Self.thumbnailStrokeWidthKey) }
    }

    var canvasStrokeWidth: Double {
        didSet { defaults.set(canvasStrokeWidth, forKey: Self.canvasStrokeWidthKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.thumbnailStrokeWidth = defaults.object(forKey: Self.thumbnailStrokeWidthKey) as? Double ?? Self.defaultThumbnailStrokeWidth
        self.canvasStrokeWidth = defaults.object(forKey: Self.canvasStrokeWidthKey) as? Double ?? Self.defaultCanvasStrokeWidth
    }

    func reset() {
        thumbnailStrokeWidth = Self.defaultThumbnailStrokeWidth
        canvasStrokeWidth = Self.defaultCanvasStrokeWidth
    }

    nonisolated static let defaultThumbnailStrokeWidth = 1.2
    nonisolated static let defaultCanvasStrokeWidth = 5.0
    nonisolated static let thumbnailStrokeWidthRange = 0.2...5.0
    nonisolated static let canvasStrokeWidthRange = 0.5...8.0

    nonisolated private static let thumbnailStrokeWidthKey = "renderTuning.thumbnailStrokeWidth"
    nonisolated private static let canvasStrokeWidthKey = "renderTuning.canvasStrokeWidth"
}
