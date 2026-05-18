import Foundation
import os.log

struct SmootherConfig: Codable, Sendable, Equatable {
    var smoothingFactor: Float
    var predictionStrength: Float
    var velocityWeight: Float
    var pressureSmoothing: Float
    var minDistance: Float

    init(
        smoothingFactor: Float = 0.4,
        predictionStrength: Float = 0.3,
        velocityWeight: Float = 0.6,
        pressureSmoothing: Float = 0.3,
        minDistance: Float = 0.5
    ) {
        self.smoothingFactor = smoothingFactor
        self.predictionStrength = predictionStrength
        self.velocityWeight = velocityWeight
        self.pressureSmoothing = pressureSmoothing
        self.minDistance = minDistance
    }
}

final class StrokeSmoother: @unchecked Sendable {
    private var config: SmootherConfig
    private var smoothedX: CGFloat?
    private var smoothedY: CGFloat?
    private var smoothedPressure: Float?
    private var velocityX: CGFloat = 0
    private var velocityY: CGFloat = 0
    private var previousTimestamp: CFTimeInterval?
    private var previousRawX: CGFloat?
    private var previousRawY: CGFloat?

    init(config: SmootherConfig = SmootherConfig()) {
        self.config = config
    }

    convenience init(
        smoothingFactor: Float = 0.4,
        predictionStrength: Float = 0.3,
        velocityWeight: Float = 0.6,
        pressureSmoothing: Float = 0.3,
        minimumPointDistance: Float = 0.5
    ) {
        self.init(config: SmootherConfig(
            smoothingFactor: smoothingFactor,
            predictionStrength: predictionStrength,
            velocityWeight: velocityWeight,
            pressureSmoothing: pressureSmoothing,
            minDistance: minimumPointDistance
        ))
    }

    func smooth(next point: StrokePoint) -> StrokePoint? {
        if smoothedX == nil {
            smoothedX = point.position.x
            smoothedY = point.position.y
            smoothedPressure = point.pressure
            previousRawX = point.position.x
            previousRawY = point.position.y
            previousTimestamp = point.timestamp
            velocityX = 0
            velocityY = 0
            return point
        }

        let dx = point.position.x - previousRawX!
        let dy = point.position.y - previousRawY!
        let distance = sqrt(dx * dx + dy * dy)

        previousRawX = point.position.x
        previousRawY = point.position.y

        let minDist = CGFloat(config.minDistance)
        guard distance >= minDist else {
            return nil
        }

        let dt: CGFloat = point.timestamp > previousTimestamp!
            ? CGFloat(point.timestamp - previousTimestamp!)
            : CGFloat(1.0 / 120.0)
        previousTimestamp = point.timestamp

        let velocity = distance / max(dt, CGFloat.ulpOfOne)
        let speedFactor = min(Float(velocity) / 2000.0, 1.0)
        let adaptiveAlpha = config.smoothingFactor + (1.0 - config.smoothingFactor) * config.velocityWeight * speedFactor
        let alpha = CGFloat(min(max(adaptiveAlpha, 0.0), 1.0))

        let newSmoothedX = smoothedX! + alpha * (point.position.x - smoothedX!)
        let newSmoothedY = smoothedY! + alpha * (point.position.y - smoothedY!)
        let newSmoothedPressure = smoothedPressure! + config.pressureSmoothing * (point.pressure - smoothedPressure!)

        velocityX = velocityX * (1.0 - alpha) + (point.position.x - smoothedX!) / max(dt, CGFloat.ulpOfOne) * alpha
        velocityY = velocityY * (1.0 - alpha) + (point.position.y - smoothedY!) / max(dt, CGFloat.ulpOfOne) * alpha

        smoothedX = newSmoothedX
        smoothedY = newSmoothedY
        smoothedPressure = newSmoothedPressure

        return StrokePoint(
            position: CGPoint(x: newSmoothedX, y: newSmoothedY),
            pressure: newSmoothedPressure,
            timestamp: point.timestamp,
            altitude: point.altitude,
            azimuth: point.azimuth,
            predicted: point.predicted
        )
    }

    func addSample(_ point: StrokePoint) -> [StrokePoint] {
        if let smoothed = smooth(next: point) {
            return [smoothed]
        }
        return []
    }

    func finishStroke() -> [StrokePoint] {
        guard let lastRawX = previousRawX, let lastRawY = previousRawY,
              let ps = smoothedPressure,
              let ts = previousTimestamp,
              velocityX != 0 || velocityY != 0 else {
            return []
        }

        let dt: CGFloat = CGFloat(1.0 / 120.0)
        let predictedX = lastRawX + velocityX * CGFloat(config.predictionStrength) * dt
        let predictedY = lastRawY + velocityY * CGFloat(config.predictionStrength) * dt

        let predicted = StrokePoint(
            position: CGPoint(x: predictedX, y: predictedY),
            pressure: ps,
            timestamp: ts + TimeInterval(dt),
            predicted: true
        )
        return [predicted]
    }

    func reset() {
        smoothedX = nil
        smoothedY = nil
        smoothedPressure = nil
        velocityX = 0
        velocityY = 0
        previousTimestamp = nil
        previousRawX = nil
        previousRawY = nil
    }
}