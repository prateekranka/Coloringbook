import Foundation
import OSLog

/// Central logging helper.
///
/// Verbose breadcrumbs (`trace`) are compiled out of Release builds so they
/// never reach Console or sysdiagnose on a user's device. `error` remains in
/// Release — reserve it for conditions that actually represent a bug.
///
/// Never call `NSLog` directly: it bypasses the unified-logging system, can't
/// be filtered or redacted, and shows up in Console on production devices.
enum AppLog {

    static let app      = Logger(subsystem: subsystem, category: "App")
    static let template = Logger(subsystem: subsystem, category: "Template")
    static let canvas   = Logger(subsystem: subsystem, category: "Canvas")

    private static let subsystem = "com.colorflow.app"

    /// Debug-only breadcrumb. Compiled out of Release builds.
    static func trace(
        _ logger: Logger,
        _ message: @autoclosure () -> String
    ) {
        #if DEBUG
        let text = message()
        logger.debug("\(text, privacy: .public)")
        #endif
    }

    /// Unexpected but recoverable. Kept in Release so Console/crash triage can see it.
    static func error(
        _ logger: Logger,
        _ message: @autoclosure () -> String
    ) {
        let text = message()
        logger.error("\(text, privacy: .public)")
    }
}
