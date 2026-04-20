import PencilKit
import CoreGraphics

struct StrokeClipper {
    static func clipStroke(_ stroke: PKStroke, toRegion region: RegionGeometry) -> PKStroke? {
        let regionPath = region.path
        let fillRule = region.fillRule

        let points = Array(stroke.path)

        guard points.count >= 2 else {
            if let first = points.first, regionPath.contains(first.location, using: fillRule) {
                return stroke
            }
            return nil
        }

        var resultPaths: [[PKStrokePoint]] = []
        var currentRun: [PKStrokePoint] = []

        for point in points {
            let inside = regionPath.contains(point.location, using: fillRule)

            if inside {
                currentRun.append(point)
            } else {
                if !currentRun.isEmpty {
                    if currentRun.count >= 2 {
                        resultPaths.append(currentRun)
                    }
                    currentRun = []
                }
            }
        }

        if currentRun.count >= 2 {
            resultPaths.append(currentRun)
        }

        guard let longestRun = resultPaths.max(by: { $0.count < $1.count }) else {
            return nil
        }

        let newPath = PKStrokePath(controlPoints: longestRun, creationDate: stroke.path.creationDate)
        return PKStroke(ink: stroke.ink, path: newPath, transform: stroke.transform, mask: stroke.mask)
    }
}
