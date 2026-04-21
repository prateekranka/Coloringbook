import PencilKit
import CoreGraphics

struct StrokeClipper {
    static func clipStroke(_ stroke: PKStroke, using geometry: TemplateGeometry) -> [PKStroke] {
        let controlPoints = Array(stroke.path)
        guard let firstControl = controlPoints.first else { return [] }

        guard let region = geometry.region(at: firstControl.location) else { return [] }
        let regionPath = region.path
        let fillRule = region.fillRule

        let samples = interpolate(stroke.path)
        guard samples.count >= 2 else {
            return regionPath.contains(firstControl.location, using: fillRule)
                ? [stroke] : []
        }

        var runs: [[PKStrokePoint]] = []
        var current: [PKStrokePoint] = []
        for p in samples {
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

    private static func interpolate(_ path: PKStrokePath) -> [PKStrokePoint] {
        let controls = Array(path)
        guard controls.count >= 2 else { return controls }

        let substeps: CGFloat = 4
        var result: [PKStrokePoint] = []

        for i in 0..<(controls.count - 1) {
            let a = controls[i]
            let b = controls[i + 1]
            for j in 0..<Int(substeps) {
                let t = CGFloat(j) / substeps
                let loc = CGPoint(
                    x: a.location.x + (b.location.x - a.location.x) * t,
                    y: a.location.y + (b.location.y - a.location.y) * t
                )
                result.append(PKStrokePoint(
                    location: loc,
                    timeOffset: a.timeOffset + (b.timeOffset - a.timeOffset) * Double(t),
                    size: CGSize(
                        width: a.size.width + (b.size.width - a.size.width) * t,
                        height: a.size.height + (b.size.height - a.size.height) * t
                    ),
                    opacity: a.opacity + (b.opacity - a.opacity) * Double(t),
                    force: a.force + (b.force - a.force) * Double(t),
                    azimuth: a.azimuth + (b.azimuth - a.azimuth) * Double(t),
                    altitude: a.altitude + (b.altitude - a.altitude) * Double(t)
                ))
            }
        }
        if let last = controls.last {
            result.append(last)
        }

        return result
    }
}
