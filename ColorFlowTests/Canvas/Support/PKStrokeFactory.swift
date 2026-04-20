import UIKit
import PencilKit
import CoreGraphics

/// Deterministic PKStroke construction for tests.
///
/// PencilKit has no Pencil hardware in the Simulator and `drawingPolicy =
/// .pencilOnly` rejects finger input, so U7 (brush verification) and U8
/// (stay-in-the-lines clipping) build strokes directly in memory instead of
/// synthesizing touches. This factory keeps that construction in one place.
enum PKStrokeFactory {

    /// Build a `PKStroke` along a straight line from `start` to `end` (both in
    /// document-space points), sampling `steps` points evenly.
    ///
    /// - Parameters:
    ///   - start: first point, document space.
    ///   - end: last point, document space.
    ///   - steps: number of samples. Must be >= 2. Defaults to 20, dense enough
    ///            to survive PencilKit's internal smoothing while staying cheap.
    ///   - ink: the ink to apply (e.g. `PKInkingTool(.pencil, color:, width:).ink`).
    ///   - strokeSize: size of each `PKStrokePoint` (width/height at the point).
    ///   - force: stroke force per point (0.0 to 1.0). Defaults to 1.0.
    static func straightLine(
        from start: CGPoint,
        to end: CGPoint,
        steps: Int = 20,
        ink: PKInk,
        strokeSize: CGSize = CGSize(width: 8, height: 8),
        force: CGFloat = 1.0
    ) -> PKStroke {
        precondition(steps >= 2, "Need at least 2 samples for a stroke path")

        var points: [PKStrokePoint] = []
        points.reserveCapacity(steps)

        let baseTime: TimeInterval = 0
        let dt: TimeInterval = 1.0 / 60.0

        for i in 0..<steps {
            let t = CGFloat(i) / CGFloat(steps - 1)
            let location = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            let point = PKStrokePoint(
                location: location,
                timeOffset: baseTime + Double(i) * dt,
                size: strokeSize,
                opacity: 1.0,
                force: force,
                azimuth: 0,
                altitude: .pi / 2
            )
            points.append(point)
        }

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }

    /// Convenience: build a pencil stroke at the given color/width along a
    /// straight line in document space. Keeps tests concise.
    static func pencilLine(
        from start: CGPoint,
        to end: CGPoint,
        color: UIColor,
        width: CGFloat = 8,
        steps: Int = 20
    ) -> PKStroke {
        let tool = PKInkingTool(.pencil, color: color, width: width)
        return straightLine(
            from: start,
            to: end,
            steps: steps,
            ink: tool.ink,
            strokeSize: CGSize(width: width, height: width)
        )
    }

    /// Convenience: wrap a single stroke (or many) into a `PKDrawing`.
    static func drawing(with strokes: [PKStroke]) -> PKDrawing {
        PKDrawing(strokes: strokes)
    }
}
