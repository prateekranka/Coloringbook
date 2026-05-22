import CoreGraphics
import Darwin
import Foundation
import Observation

@MainActor
@Observable
final class CanvasDebugDiagnostics {
    enum EventKind: String {
        case lifecycle = "life"
        case input
        case fill
        case stroke
        case viewport
        case warning = "warn"
        case scale
        case compare
    }

    var isEnabled: Bool
    private(set) var latestEvent: CanvasDebugEvent?
    private(set) var events: [CanvasDebugEvent] = []

    let sessionID: String
    private let fileWriter: CanvasDiagnosticsFileWriter?
    private var lastEmittedAtByKey: [String: TimeInterval] = [:]
    private let maxStoredEvents = 8

    init(isEnabled: Bool? = nil, sessionID: String? = nil) {
        let enabled = isEnabled ?? Self.defaultIsEnabled
        self.isEnabled = enabled
        self.sessionID = sessionID ?? Self.environmentSessionID ?? UUID().uuidString
        if enabled, let url = Self.makeLogFileURL() {
            fileWriter = CanvasDiagnosticsFileWriter(
                url: url,
                resetsExistingLog: Self.shouldResetLog
            )
        } else {
            fileWriter = nil
        }
    }

    func record(
        _ kind: EventKind,
        _ message: String,
        hit: CanvasDebugHit? = nil,
        throttleKey: String? = nil,
        minimumInterval: TimeInterval = 0
    ) {
        guard isEnabled else { return }

        let now = Date()
        if let throttleKey, minimumInterval > 0 {
            let timestamp = now.timeIntervalSince1970
            if let previous = lastEmittedAtByKey[throttleKey],
               timestamp - previous < minimumInterval {
                return
            }
            lastEmittedAtByKey[throttleKey] = timestamp
        }

        let event = CanvasDebugEvent(date: now, kind: kind, message: message, hit: hit)
        latestEvent = event
        events.insert(event, at: 0)
        if events.count > maxStoredEvents {
            events.removeLast(events.count - maxStoredEvents)
        }

        let line = "[GouacheCanvas][\(kind.rawValue)] session=\(sessionID) \(event.consoleLine)"
        AppLog.trace(AppLog.canvas, line)

        #if DEBUG
        if Self.shouldMirrorToStderr {
            fputs(line + "\n", stderr)
            fflush(stderr)
        }
        #endif
        appendToFile(line)
    }

    nonisolated static var defaultIsEnabled: Bool {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS"] == "1"
            || processInfo.arguments.contains("--gouache-canvas-diagnostics")
            || UserDefaults.standard.bool(forKey: "gouache.canvasDiagnostics.enabled")
        #else
        return false
        #endif
    }

    nonisolated private static var shouldResetLog: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_RESET_LOG"] == "1"
        #else
        false
        #endif
    }

    nonisolated private static var environmentSessionID: String? {
        #if DEBUG
        let rawValue = ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_SESSION_ID"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rawValue?.isEmpty == false ? rawValue : nil
        #else
        return nil
        #endif
    }

    nonisolated private static var shouldMirrorToStderr: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_STDERR"] == "1"
        #else
        false
        #endif
    }

    private static func makeLogFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("canvas-diagnostics.log")
    }

    private func appendToFile(_ line: String) {
        guard let fileWriter else { return }
        Task(priority: .utility) {
            await fileWriter.append(line)
        }
    }
}

private actor CanvasDiagnosticsFileWriter {
    private let fileHandle: FileHandle

    init?(url: URL, resetsExistingLog: Bool) {
        let fileManager = FileManager.default
        if resetsExistingLog {
            try? fileManager.removeItem(at: url)
        }
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        guard let fileHandle = try? FileHandle(forWritingTo: url) else {
            return nil
        }
        self.fileHandle = fileHandle
        try? fileHandle.seekToEnd()
    }

    deinit {
        try? fileHandle.close()
    }

    func append(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        try? fileHandle.write(contentsOf: data)
    }
}

struct CanvasDebugEvent: Identifiable {
    let id = UUID()
    let date: Date
    let kind: CanvasDebugDiagnostics.EventKind
    let message: String
    let hit: CanvasDebugHit?

    var consoleLine: String {
        if let hit {
            return "\(message) | \(hit.consoleSummary)"
        }
        return message
    }

    var shortTimestamp: String {
        Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

struct CanvasDebugHit {
    let input: String
    let phase: String
    let viewportPoint: CGPoint?
    let canvasPoint: CGPoint?
    let documentPoint: CGPoint?
    let regionID: String?
    let regionBounds: CGRect?
    let tool: ToolType
    let mode: CanvasColoringMode
    let colorHex: String
    let sampleCount: Int?
    let touchTimestamp: TimeInterval?
    let sequenceNumber: Int?
    let coalescedCount: Int?
    let predictedCount: Int?
    let force: Double?
    let altitude: Double?
    let azimuth: Double?
    let delta: CGSize?
    let distance: CGFloat?
    let velocity: CGFloat?
    let isPredicted: Bool
    let canvasSize: CGSize
    let viewportSize: CGSize
    let viewportScale: CGFloat
    let viewportOffset: CGSize
    let documentToCanvasScale: CGFloat?
    let documentToBitmapScale: CGFloat?
    let previewStrokeSize: CGFloat?
    let committedStrokeSize: CGFloat?
    let bitmapPixelSize: CGSize?

    var regionSummary: String {
        regionID ?? "none"
    }

    var consoleSummary: String {
        var parts = [
            "input=\(input)",
            "phase=\(phase)",
            "tool=\(tool.rawValue)",
            "mode=\(mode.rawValue)",
            "color=\(colorHex)",
            "viewport=\(Self.format(viewportPoint))",
            "canvas=\(Self.format(canvasPoint))",
            "document=\(Self.format(documentPoint))",
            "region=\(regionSummary)",
            "scale=\(Self.format(viewportScale))",
            "offset=\(Self.format(viewportOffset))"
        ]
        if let sampleCount {
            parts.append("samples=\(sampleCount)")
        }
        if let touchTimestamp {
            parts.append("touchTs=\(Self.format(touchTimestamp))")
        }
        if let sequenceNumber {
            parts.append("seq=\(sequenceNumber)")
        }
        if let coalescedCount {
            parts.append("coalesced=\(coalescedCount)")
        }
        if let predictedCount {
            parts.append("predictedCount=\(predictedCount)")
        }
        if let force {
            parts.append("force=\(Self.format(force))")
        }
        if let altitude {
            parts.append("altitude=\(Self.format(altitude))")
        }
        if let azimuth {
            parts.append("azimuth=\(Self.format(azimuth))")
        }
        if let delta {
            parts.append("delta=\(Self.format(delta))")
        }
        if let distance {
            parts.append("distance=\(Self.format(distance))")
        }
        if let velocity {
            parts.append("velocity=\(Self.format(velocity))")
        }
        if isPredicted {
            parts.append("predicted=true")
        }
        if let dcs = documentToCanvasScale {
            parts.append("docToCanvasScale=\(Self.format(dcs))")
        }
        if let dbs = documentToBitmapScale {
            parts.append("docToBitmapScale=\(Self.format(dbs))")
        }
        if let ps = previewStrokeSize {
            parts.append("previewSize=\(Self.format(ps))")
        }
        if let cs = committedStrokeSize {
            parts.append("committedSize=\(Self.format(cs))")
        }
        if let bps = bitmapPixelSize {
            parts.append("bitmapSize=\(Self.format(bps.width))x\(Self.format(bps.height))")
        }
        return parts.joined(separator: " ")
    }

    private static func format(_ point: CGPoint?) -> String {
        guard let point else { return "nil" }
        return "(\(format(point.x)),\(format(point.y)))"
    }

    private static func format(_ size: CGSize) -> String {
        "(\(format(size.width)),\(format(size.height)))"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

struct CanvasDebugInput {
    let phase: Phase
    let input: Input
    let viewportPoint: CGPoint?
    let canvasPoint: CGPoint?
    let canvasSize: CGSize
    let viewportSize: CGSize
    let viewport: CanvasViewport
    let sampleCount: Int?
    let touchTimestamp: TimeInterval?
    let sequenceNumber: Int?
    let coalescedCount: Int?
    let predictedCount: Int?
    let force: Double?
    let altitude: Double?
    let azimuth: Double?
    let delta: CGSize?
    let distance: CGFloat?
    let velocity: CGFloat?
    let isPredicted: Bool
    let detail: String?

    enum Phase: String {
        case tap
        case pencilBegan
        case pencilMoved
        case pencilEnded
        case pencilCancelled
        case fingerBegan
        case fingerMoved
        case fingerEnded
        case panBegan
        case panEnded
        case pinchBegan
        case pinchChanged
        case pinchEnded
    }

    enum Input: String {
        case direct
        case pencil
        case gesture
    }

    var message: String {
        if let detail, !detail.isEmpty {
            return "\(phase.rawValue): \(detail)"
        }
        return phase.rawValue
    }

    var throttleKey: String? {
        switch phase {
        case .pencilMoved, .fingerMoved, .pinchChanged:
            return "\(input.rawValue).\(phase.rawValue)"
        default:
            return nil
        }
    }

    var minimumInterval: TimeInterval {
        switch phase {
        case .pencilMoved, .fingerMoved:
            #if DEBUG
            if input == .pencil, CanvasDiagnosticsSettings.logEveryPencilSample {
                return 0
            }
            if input == .pencil, CanvasDiagnosticsSettings.pencilMovementEnabled {
                return CanvasDiagnosticsSettings.minimumMovementLogIntervalMs / 1000.0
            }
            #endif
            return 0.18
        case .pinchChanged:
            return 0.25
        default:
            return 0
        }
    }
}
