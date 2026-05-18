import CoreGraphics
import Foundation
import QuartzCore

struct StrokePoint: Equatable {
    var position: CGPoint
    var pressure: Float
    var timestamp: CFTimeInterval
    var altitude: Float?
    var azimuth: Float?
    var predicted: Bool

    init(
        position: CGPoint,
        pressure: Float = 1.0,
        timestamp: CFTimeInterval = CACurrentMediaTime(),
        altitude: Float? = nil,
        azimuth: Float? = nil,
        predicted: Bool = false
    ) {
        self.position = position
        self.pressure = max(0, min(1, pressure))
        self.timestamp = timestamp
        self.altitude = altitude
        self.azimuth = azimuth
        self.predicted = predicted
    }

    init(from sample: StrokeSample) {
        self.position = sample.cgPoint
        self.pressure = Float(sample.force ?? 1.0)
        self.timestamp = sample.timestamp ?? CACurrentMediaTime()
        self.altitude = sample.altitude.map(Float.init)
        self.azimuth = sample.azimuth.map(Float.init)
        self.predicted = sample.isPredicted ?? false
    }

    var codablePoint: CodablePoint {
        CodablePoint(position)
    }
}
