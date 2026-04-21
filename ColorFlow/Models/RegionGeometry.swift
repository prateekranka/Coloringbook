import Foundation
@preconcurrency import CoreGraphics

/// Immutable geometry for a single fillable region parsed from an SVG template.
/// Parsed once at load time and shared across all projects using the same template.
struct RegionGeometry: Identifiable, Sendable {
    let id: String              // from SVG path id attribute (e.g., "petal-1")
    let path: CGPath            // the region boundary
    let bounds: CGRect          // path.boundingBoxOfPath (cached for fast rejection)
    let fillRule: CGPathFillRule // .evenOdd or .winding
    let zIndex: Int             // order in SVG document (higher = rendered later / hit-test first)
}
