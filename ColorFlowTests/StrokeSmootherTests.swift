import XCTest
import CoreGraphics
@testable import ColorFlow

final class StrokeSmootherTests: XCTestCase {

    func testFirstPointPassesThroughUnchanged() {
        let smoother = StrokeSmoother(config: SmootherConfig())
        let point = StrokePoint(
            position: CGPoint(x: 100, y: 200),
            pressure: 0.7,
            timestamp: 1.0
        )
        let result = smoother.addSample(point)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].position.x, 100)
        XCTAssertEqual(result[0].position.y, 200)
        XCTAssertEqual(result[0].pressure, 0.7, accuracy: 0.01)
    }

    func testSmoothedPointsReduceJitter() {
        let config = SmootherConfig(
            smoothingFactor: 0.5,
            predictionStrength: 0,
            velocityWeight: 0,
            pressureSmoothing: 0.3,
            minDistance: 0
        )
        let smoother = StrokeSmoother(config: config)

        let jitter: [CGFloat] = [5, -3, 4, -2, 6, -4, 3, -5, 2, -1, 4, -3, 5, -2, 3, -4, 1, 5, -3, 2]

        var rawVariance: CGFloat = 0
        var smoothVariance: CGFloat = 0

        for i in 0..<100 {
            let t = Double(i) / 100.0
            let jx = jitter[i % jitter.count]
            let jy = jitter[(i + 3) % jitter.count]
            let point = StrokePoint(
                position: CGPoint(x: 200 * t + jx, y: 200 * t + jy),
                pressure: 0.5,
                timestamp: t
            )
            rawVariance += abs(jx) + abs(jy)
            let smoothed = smoother.addSample(point)
            for s in smoothed {
                smoothVariance += abs(s.position.x - 200 * t) + abs(s.position.y - 200 * t)
            }
        }

        let count = CGFloat(100)
        XCTAssertLessThan(smoothVariance / count, rawVariance / count * 1.1,
            "Smoothed deviation should be at most 10% worse than raw jitter")
    }

    func testPredictionExtrapolatesPosition() {
        let config = SmootherConfig(
            smoothingFactor: 0.2,
            predictionStrength: 1.0,
            velocityWeight: 0.6,
            pressureSmoothing: 0.3,
            minDistance: 0
        )
        let smoother = StrokeSmoother(config: config)

        let points: [StrokePoint] = [
            StrokePoint(position: CGPoint(x: 0, y: 0), pressure: 0.5, timestamp: 0),
            StrokePoint(position: CGPoint(x: 20, y: 0), pressure: 0.5, timestamp: 0.1),
            StrokePoint(position: CGPoint(x: 40, y: 0), pressure: 0.5, timestamp: 0.2),
            StrokePoint(position: CGPoint(x: 60, y: 0), pressure: 0.5, timestamp: 0.3),
        ]

        for point in points {
            _ = smoother.addSample(point)
        }

        let predicted = smoother.finishStroke()
        XCTAssertGreaterThan(predicted.count, 0)

        for point in predicted {
            XCTAssertTrue(point.predicted)
        }
    }

    func testPressurePreservation() {
        let config = SmootherConfig(
            smoothingFactor: 0.3,
            predictionStrength: 0,
            velocityWeight: 0,
            pressureSmoothing: 0.3,
            minDistance: 0
        )
        let smoother = StrokeSmoother(config: config)

        let pressures: [Float] = [0.1, 0.3, 0.5, 0.7, 0.9, 1.0, 0.8, 0.6, 0.4, 0.2]
        var smoothedPressures: [Float] = []

        for (i, pressure) in pressures.enumerated() {
            let point = StrokePoint(
                position: CGPoint(x: Double(i) * 20, y: 0),
                pressure: pressure,
                timestamp: Double(i) * 0.05
            )
            let results = smoother.addSample(point)
            smoothedPressures.append(contentsOf: results.map(\.pressure))
        }

        guard !smoothedPressures.isEmpty else {
            XCTFail("Expected smoothed pressure values")
            return
        }

        for pressure in smoothedPressures {
            XCTAssertGreaterThanOrEqual(pressure, 0)
            XCTAssertLessThanOrEqual(pressure, 1)
        }

        let inputMax = pressures.max() ?? 0
        let inputMin = pressures.min() ?? 0
        let outputMax = smoothedPressures.max() ?? 0
        let outputMin = smoothedPressures.min() ?? 0

        XCTAssertLessThanOrEqual(outputMax, inputMax + 0.2)
        XCTAssertGreaterThanOrEqual(outputMin, inputMin - 0.2)
    }

    func testMonotonicTimestamps() {
        let config = SmootherConfig(
            smoothingFactor: 0.3,
            predictionStrength: 0.1,
            velocityWeight: 0.2,
            pressureSmoothing: 0.3,
            minDistance: 0
        )
        let smoother = StrokeSmoother(config: config)

        let points: [StrokePoint] = [
            StrokePoint(position: CGPoint(x: 0, y: 0), pressure: 0.5, timestamp: 0),
            StrokePoint(position: CGPoint(x: 30, y: 20), pressure: 0.5, timestamp: 0.1),
            StrokePoint(position: CGPoint(x: 60, y: 40), pressure: 0.5, timestamp: 0.2),
            StrokePoint(position: CGPoint(x: 90, y: 60), pressure: 0.5, timestamp: 0.3),
        ]

        var allOutput: [StrokePoint] = []
        for point in points {
            allOutput.append(contentsOf: smoother.addSample(point))
        }
        allOutput.append(contentsOf: smoother.finishStroke())

        for i in 1..<allOutput.count {
            XCTAssertGreaterThanOrEqual(
                allOutput[i].timestamp,
                allOutput[i - 1].timestamp,
                "Output timestamps should be non-decreasing"
            )
        }
    }

    func testMinDistanceFiltersClosePoints() {
        let config = SmootherConfig(
            smoothingFactor: 0.3,
            predictionStrength: 0,
            velocityWeight: 0,
            pressureSmoothing: 0.3,
            minDistance: 10.0
        )
        let smoother = StrokeSmoother(config: config)

        let points: [StrokePoint] = [
            StrokePoint(position: CGPoint(x: 0, y: 0), pressure: 0.5, timestamp: 0),
            StrokePoint(position: CGPoint(x: 1, y: 0), pressure: 0.5, timestamp: 0.01),
            StrokePoint(position: CGPoint(x: 2, y: 0), pressure: 0.5, timestamp: 0.02),
            StrokePoint(position: CGPoint(x: 3, y: 0), pressure: 0.5, timestamp: 0.03),
            StrokePoint(position: CGPoint(x: 20, y: 0), pressure: 0.5, timestamp: 0.04),
            StrokePoint(position: CGPoint(x: 21, y: 0), pressure: 0.5, timestamp: 0.05),
            StrokePoint(position: CGPoint(x: 40, y: 0), pressure: 0.5, timestamp: 0.06),
        ]

        var outputCount = 0
        for point in points {
            let results = smoother.addSample(point)
            outputCount += results.count
        }

        XCTAssertLessThan(outputCount, points.count)
        XCTAssertGreaterThan(outputCount, 0)
    }

    func testResetClearsState() {
        let config = SmootherConfig(
            smoothingFactor: 0.3,
            predictionStrength: 0.1,
            velocityWeight: 0.2,
            pressureSmoothing: 0.3,
            minDistance: 0
        )
        let smoother = StrokeSmoother(config: config)

        let firstPoints: [StrokePoint] = [
            StrokePoint(position: CGPoint(x: 0, y: 0), pressure: 0.5, timestamp: 0),
            StrokePoint(position: CGPoint(x: 30, y: 20), pressure: 0.5, timestamp: 0.1),
            StrokePoint(position: CGPoint(x: 60, y: 40), pressure: 0.5, timestamp: 0.2),
        ]

        for point in firstPoints {
            _ = smoother.addSample(point)
        }
        smoother.reset()

        let freshPoint = StrokePoint(position: CGPoint(x: 50, y: 50), pressure: 0.8, timestamp: 1.0)
        let result = smoother.addSample(freshPoint)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].position.x, 50)
        XCTAssertEqual(result[0].position.y, 50)
        XCTAssertEqual(result[0].pressure, 0.8, accuracy: 0.01)
    }

    func testFinishStrokeFlushesPending() {
        let config = SmootherConfig(
            smoothingFactor: 0.3,
            predictionStrength: 0.5,
            velocityWeight: 0.6,
            pressureSmoothing: 0.3,
            minDistance: 0
        )
        let smoother = StrokeSmoother(config: config)

        let points: [StrokePoint] = [
            StrokePoint(position: CGPoint(x: 0, y: 0), pressure: 0.5, timestamp: 0),
            StrokePoint(position: CGPoint(x: 30, y: 20), pressure: 0.5, timestamp: 0.1),
            StrokePoint(position: CGPoint(x: 60, y: 40), pressure: 0.5, timestamp: 0.2),
        ]

        for point in points {
            _ = smoother.addSample(point)
        }

        let flushed = smoother.finishStroke()
        XCTAssertGreaterThan(flushed.count, 0)

        for point in flushed {
            XCTAssertTrue(point.predicted)
        }

        smoother.reset()
        let afterReset = smoother.finishStroke()
        XCTAssertEqual(afterReset.count, 0)
    }

    func testBrushConfigurationDefaults() {
        let pencil = BrushConfiguration.defaultBrush(kind: .pencil)
        XCTAssertEqual(pencil.brushType, .pencil)
        XCTAssertGreaterThanOrEqual(pencil.size, 0.1)

        let watercolor = BrushConfiguration.defaultBrush(kind: .watercolor)
        XCTAssertGreaterThanOrEqual(watercolor.softness, 0.5)

        let marker = BrushConfiguration.defaultBrush(kind: .marker)
        XCTAssertGreaterThanOrEqual(marker.opacity, 0.9)

        let spray = BrushConfiguration.defaultBrush(kind: .spray)
        XCTAssertGreaterThan(spray.noiseIntensity, 0)

        for brushType in BrushType.allCases {
            let config = BrushConfiguration.defaultBrush(kind: brushType)
            XCTAssertGreaterThanOrEqual(config.size, 0.1)
            XCTAssertLessThanOrEqual(config.opacity, 1.0)
            XCTAssertGreaterThanOrEqual(config.softness, 0)
            XCTAssertLessThanOrEqual(config.softness, 1.0)
        }
    }

    func testSmootherConfigDefaults() {
        let config = SmootherConfig()
        XCTAssertEqual(config.smoothingFactor, 0.4)
        XCTAssertEqual(config.predictionStrength, 0.3)
        XCTAssertEqual(config.velocityWeight, 0.6)
        XCTAssertEqual(config.pressureSmoothing, 0.3)
        XCTAssertEqual(config.minDistance, 0.5)
    }

    func testSmootherConfigEquality() {
        let a = SmootherConfig(smoothingFactor: 0.5, predictionStrength: 0.2, velocityWeight: 0.7, pressureSmoothing: 0.4, minDistance: 1.0)
        let b = SmootherConfig(smoothingFactor: 0.5, predictionStrength: 0.2, velocityWeight: 0.7, pressureSmoothing: 0.4, minDistance: 1.0)
        let c = SmootherConfig(smoothingFactor: 0.6, predictionStrength: 0.2, velocityWeight: 0.7, pressureSmoothing: 0.4, minDistance: 1.0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testDrawingEngineModeRoundTrip() {
        for mode in DrawingEngineMode.allCases {
            let encoded = mode.rawValue
            let decoded = DrawingEngineMode(rawValue: encoded)
            XCTAssertEqual(decoded, mode)
        }
    }

    @MainActor func testFrameInstrumentationLatency() {
        let instr = FrameInstrumentation(enabled: true)
        instr.markRawInput(timestamp: 0.0)
        instr.markSmoothed(timestamp: 0.002)
        instr.markRenderSubmitted(timestamp: 0.004)
        instr.markFrameDrawn(timestamp: 0.006)

        instr.markRawInput(timestamp: 0.010)
        instr.markSmoothed(timestamp: 0.012)
        instr.markRenderSubmitted(timestamp: 0.014)
        instr.markFrameDrawn(timestamp: 0.016)

        let avg = instr.averageLatencyMs()
        XCTAssertEqual(avg, 6.0, accuracy: 0.01)

        instr.reset()
        XCTAssertEqual(instr.averageLatencyMs(), 0)
    }
}