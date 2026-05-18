import Foundation

struct RenderInstrument {
    var rawInputTimestamp: CFTimeInterval
    var smoothedEmitTimestamp: CFTimeInterval
    var rendererSubmitTimestamp: CFTimeInterval
    var frameCompleteTimestamp: CFTimeInterval

    var smoothingLatencyMs: Float {
        Float((smoothedEmitTimestamp - rawInputTimestamp) * 1000)
    }

    var renderLatencyMs: Float {
        Float((rendererSubmitTimestamp - smoothedEmitTimestamp) * 1000)
    }

    var gpuLatencyMs: Float {
        Float((frameCompleteTimestamp - rendererSubmitTimestamp) * 1000)
    }

    var totalLatencyMs: Float {
        Float((frameCompleteTimestamp - rawInputTimestamp) * 1000)
    }
}

struct RenderInstrumentCollector {
    private(set) var samples: [RenderInstrument] = []
    private let maxSamples: Int

    init(maxSamples: Int = 120) {
        self.maxSamples = maxSamples
    }

    mutating func record(_ instrument: RenderInstrument) {
        samples.append(instrument)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    var averageTotalLatencyMs: Float {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0) { $0 + $1.totalLatencyMs } / Float(samples.count)
    }

    var averageSmoothingLatencyMs: Float {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0) { $0 + $1.smoothingLatencyMs } / Float(samples.count)
    }

    var averageRenderLatencyMs: Float {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0) { $0 + $1.renderLatencyMs } / Float(samples.count)
    }

    var averageGPULatencyMs: Float {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0) { $0 + $1.gpuLatencyMs } / Float(samples.count)
    }

    func frameBudgetStatus(targetFPS: Int = 120) -> String {
        let budgetMs = 1000.0 / Float(targetFPS)
        let avg = averageTotalLatencyMs
        if avg <= budgetMs * 0.5 {
            return "well within \(targetFPS) fps budget"
        } else if avg <= budgetMs {
            return "within \(targetFPS) fps budget"
        } else {
            return "exceeds \(targetFPS) fps budget (\(String(format: "%.1f", avg))ms vs \(String(format: "%.1f", budgetMs))ms)"
        }
    }

    #if DEBUG
    func debugSummary() -> String {
        """
        [RenderInstrument] avg total: \(String(format: "%.2f", averageTotalLatencyMs))ms \
        (smooth: \(String(format: "%.2f", averageSmoothingLatencyMs))ms, \
        render: \(String(format: "%.2f", averageRenderLatencyMs))ms, \
        gpu: \(String(format: "%.2f", averageGPULatencyMs))ms) \
        over \(samples.count) samples — \(frameBudgetStatus())
        """
    }
    #endif

    mutating func reset() {
        samples.removeAll()
    }
}
