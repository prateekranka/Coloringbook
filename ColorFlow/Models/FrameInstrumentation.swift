import Foundation
import os.log
import os.signpost

struct StrokeTimingMark: Sendable {
    var rawInputTimestamp: CFTimeInterval = 0
    var smoothedTimestamp: CFTimeInterval = 0
    var renderSubmittedTimestamp: CFTimeInterval = 0
    var frameDrawnTimestamp: CFTimeInterval = 0
}

@MainActor
final class FrameInstrumentation {
    private var activeMark = StrokeTimingMark()
    private var completedMarks: [StrokeTimingMark] = []
    private let enabled: Bool
    private static let maxMarks = 120
    private static let log = OSLog(subsystem: "com.prateekranka.colorflow", category: "FrameInstrumentation")

    init(enabled: Bool = true) {
        self.enabled = enabled
    }

    func markRawInput(timestamp: CFTimeInterval) {
        guard enabled else { return }
        activeMark.rawInputTimestamp = timestamp
    }

    func markSmoothed(timestamp: CFTimeInterval) {
        guard enabled else { return }
        activeMark.smoothedTimestamp = timestamp
    }

    func markRenderSubmitted(timestamp: CFTimeInterval) {
        guard enabled else { return }
        activeMark.renderSubmittedTimestamp = timestamp
    }

    func markFrameDrawn(timestamp: CFTimeInterval) {
        guard enabled else { return }
        activeMark.frameDrawnTimestamp = timestamp
        completedMarks.append(activeMark)
        if completedMarks.count > Self.maxMarks {
            completedMarks.removeFirst(completedMarks.count - Self.maxMarks)
        }
    }

    func currentMark() -> StrokeTimingMark { activeMark }

    func resetMark() -> StrokeTimingMark {
        let old = activeMark
        activeMark = StrokeTimingMark()
        return old
    }

    func logLatency() {
        #if DEBUG
        guard enabled, !completedMarks.isEmpty else { return }
        let avg = averageLatencyMs()
        os_log(.info, log: Self.log, "Frame latency: %.2f ms (avg over %d frames)", avg, completedMarks.count)
        #endif
    }

    func averageLatencyMs() -> Double {
        guard !completedMarks.isEmpty else { return 0 }
        var total: Double = 0
        for mark in completedMarks {
            total += (mark.frameDrawnTimestamp - mark.rawInputTimestamp) * 1000
        }
        return total / Double(completedMarks.count)
    }

    func reset() {
        completedMarks.removeAll()
        activeMark = StrokeTimingMark()
    }
}