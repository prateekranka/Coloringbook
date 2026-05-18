import CoreGraphics
import Foundation

struct MetalRegionClipper {
    let regionBounds: CGRect?
    let regionPath: CGPath?

    init(region: RegionGeometry?) {
        self.regionBounds = region?.bounds
        self.regionPath = region?.path
    }

    func clip(point: StrokePoint) -> StrokePoint? {
        guard let bounds = regionBounds else { return point }
        if bounds.contains(point.position) { return point }

        let clippedX = min(max(point.position.x, bounds.minX), bounds.maxX)
        let clippedY = min(max(point.position.y, bounds.minY), bounds.maxY)
        return StrokePoint(
            position: CGPoint(x: clippedX, y: clippedY),
            pressure: point.pressure,
            timestamp: point.timestamp,
            altitude: point.altitude,
            azimuth: point.azimuth,
            predicted: point.predicted
        )
    }
}
