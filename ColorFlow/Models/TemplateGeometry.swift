import Foundation
@preconcurrency import CoreGraphics

/// Immutable geometry for a fully parsed SVG coloring template.
/// Contains all fillable regions and decorative paths.
struct TemplateGeometry: Sendable {
    let viewBox: CGRect
    let regions: [RegionGeometry]     // fillable regions (paths with IDs)
    let decorativePaths: [CGPath]     // non-fillable detail strokes (paths without IDs)

    func region(at point: CGPoint) -> RegionGeometry? {
        region(at: point, in: regionsInHitTestOrder)
    }

    func region(near point: CGPoint, radius: CGFloat) -> RegionGeometry? {
        let orderedRegions = regionsInHitTestOrder
        if let exactRegion = region(at: point, in: orderedRegions) {
            return exactRegion
        }
        guard radius > 0 else { return nil }

        let ringCount = 4
        let pointsPerRing = 16
        for ring in 1...ringCount {
            let distance = radius * CGFloat(ring) / CGFloat(ringCount)
            for index in 0..<pointsPerRing {
                let angle = (CGFloat(index) / CGFloat(pointsPerRing)) * .pi * 2
                let candidate = CGPoint(
                    x: point.x + cos(angle) * distance,
                    y: point.y + sin(angle) * distance
                )
                if let region = region(at: candidate, in: orderedRegions) {
                    return region
                }
            }
        }

        return nil
    }

    private var regionsInHitTestOrder: [RegionGeometry] {
        regions.sorted(by: { $0.zIndex > $1.zIndex })
    }

    private func region(at point: CGPoint, in orderedRegions: [RegionGeometry]) -> RegionGeometry? {
        for region in orderedRegions {
            guard region.bounds.contains(point) else { continue }
            if region.path.contains(point, using: region.fillRule, transform: .identity) {
                return region
            }
        }
        return nil
    }
}
