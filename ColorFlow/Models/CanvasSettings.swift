import Foundation

@MainActor
@Observable
final class CanvasSettings {
    var stayInTheLines: Bool {
        didSet {
            UserDefaults.standard.set(stayInTheLines, forKey: Self.stayInTheLinesKey)
        }
    }

    init() {
        self.stayInTheLines = UserDefaults.standard.object(forKey: Self.stayInTheLinesKey) as? Bool ?? true
    }

    private static let stayInTheLinesKey = "canvas.stayInTheLines"
}

#if DEBUG
enum CanvasDiagnosticsSettings {
    static let enabledKey = "gouache.canvasDiagnostics.enabled"
    static let pencilMovementEnabledKey = "gouache.canvasDiagnostics.pencilMovementEnabled"
    static let pencilTraceOverlayEnabledKey = "gouache.canvasDiagnostics.pencilTraceOverlayEnabled"
    static let pencilSampleDotsEnabledKey = "gouache.canvasDiagnostics.pencilSampleDotsEnabled"
    static let pencilVelocityEnabledKey = "gouache.canvasDiagnostics.pencilVelocityEnabled"
    static let pencilPressureEnabledKey = "gouache.canvasDiagnostics.pencilPressureEnabled"
    static let logEveryPencilSampleKey = "gouache.canvasDiagnostics.logEveryPencilSample"
    static let minimumMovementLogIntervalMsKey = "gouache.canvasDiagnostics.minimumMovementLogIntervalMs"
    static let persistPencilTraceKey = "gouache.canvasDiagnostics.persistPencilTrace"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var pencilMovementEnabled: Bool {
        get {
            ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_PENCIL_MOVEMENT"] == "1"
                || UserDefaults.standard.object(forKey: pencilMovementEnabledKey) as? Bool ?? false
        }
        set { UserDefaults.standard.set(newValue, forKey: pencilMovementEnabledKey) }
    }

    static var pencilTraceOverlayEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pencilTraceOverlayEnabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: pencilTraceOverlayEnabledKey) }
    }

    static var pencilSampleDotsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pencilSampleDotsEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pencilSampleDotsEnabledKey) }
    }

    static var pencilVelocityEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pencilVelocityEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pencilVelocityEnabledKey) }
    }

    static var pencilPressureEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pencilPressureEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pencilPressureEnabledKey) }
    }

    static var logEveryPencilSample: Bool {
        get {
            ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_LOG_EVERY_SAMPLE"] == "1"
                || UserDefaults.standard.object(forKey: logEveryPencilSampleKey) as? Bool ?? false
        }
        set { UserDefaults.standard.set(newValue, forKey: logEveryPencilSampleKey) }
    }

    static var minimumMovementLogIntervalMs: Double {
        get {
            if ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_LOG_EVERY_SAMPLE"] == "1" {
                return 0
            }
            let value = UserDefaults.standard.double(forKey: minimumMovementLogIntervalMsKey)
            return value > 0 ? value : 50
        }
        set { UserDefaults.standard.set(newValue, forKey: minimumMovementLogIntervalMsKey) }
    }

    static var persistPencilTrace: Bool {
        get { UserDefaults.standard.object(forKey: persistPencilTraceKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: persistPencilTraceKey) }
    }
}
#endif
