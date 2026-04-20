import PencilKit
import CoreGraphics

struct StrokeClipper {
    static func clipStroke(_ stroke: PKStroke, using geometry: TemplateGeometry) -> [PKStroke] {
        let points = Array(stroke.path)
        guard !points.isEmpty else { return [] }

        guard let firstRegion = geometry.region(at: points[0].location) else {
            return []
        }
        let regionPath = firstRegion.path
        let fillRule = firstRegion.fillRule

        var runs: [[PKStrokePoint]] = []
        var current: [PKStrokePoint] = []
        for p in points {
            if regionPath.contains(p.location, using: fillRule) {
                current.append(p)
            } else if !current.isEmpty {
                if current.count >= 2 { runs.append(current) }
                current = []
            }
        }
        if current.count >= 2 { runs.append(current) }

        return runs.map { run in
            PKStroke(
                ink: stroke.ink,
                path: PKStrokePath(controlPoints: run, creationDate: stroke.path.creationDate),
                transform: stroke.transform,
                mask: stroke.mask
            )
        }
    }
}
