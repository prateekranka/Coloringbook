import Foundation
import CoreGraphics

/// Immutable geometry for a fully parsed SVG coloring template.
/// Contains all fillable regions and decorative paths.
struct TemplateGeometry {
    let viewBox: CGRect
    let regions: [RegionGeometry]     // fillable regions (paths with IDs)
    let decorativePaths: [CGPath]     // non-fillable detail strokes (paths without IDs)

    /// Hit-test: find the topmost region containing the given point (in document coordinates).
    /// Iterates in reverse z-order so the topmost visible region wins.
    func region(at point: CGPoint) -> RegionGeometry? {
        // Fast rejection using bounds before expensive CGPath.contains
        for region in regions.sorted(by: { $0.zIndex > $1.zIndex }) {
            guard region.bounds.contains(point) else { continue }
            if region.path.contains(point, using: region.fillRule, transform: .identity) {
                return region
            }
        }
        return nil
    }
}
