// LoggingGatingTests.swift
//
// Guards the release-log policy established in A3:
//   - No `NSLog(...)` calls in shipping source.
//   - No `.fault(...)` calls on `Logger` (fault is intentionally shown even
//     in production; reserve for crash-worthy conditions, not breadcrumbs).
//   - All verbose breadcrumbs route through `AppLog.trace(_:_:)`, which is
//     compiled out of Release.
//
// This is a **source scan**, not a runtime test. It runs under the same
// `ColorFlowTests` target as the other A1/A2 files and shares the same
// follow-up (test target not yet wired in project.yml — tracked as F-05).

import XCTest

final class LoggingGatingTests: XCTestCase {

    /// Absolute path to the `ColorFlow/` source tree. Resolved relative to
    /// this source file so it works under `xcodebuild test` regardless of
    /// the working directory.
    private var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // ColorFlowTests/
            .deletingLastPathComponent()          // repo root
            .appendingPathComponent("ColorFlow")
    }

    private func swiftSources() throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(url)
        }
        return files
    }

    // MARK: - Release logging contract

    func test_noNSLogCallsInShippingSources() throws {
        let offenders = try swiftSources().filter { url in
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return text.range(of: #"\bNSLog\("#, options: .regularExpression) != nil
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "NSLog must not be called from shipping sources. Use AppLog.trace / AppLog.error instead. Offenders: \(offenders.map(\.lastPathComponent))"
        )
    }

    func test_noLoggerFaultCallsInShippingSources() throws {
        // `.fault(` paired with a Logger is what we're banning. The regex is
        // narrow enough to not catch unrelated identifiers ending in `fault`.
        let offenders = try swiftSources().filter { url in
            // AppLog.swift itself never uses .fault, but exclude it anyway so
            // future edits to the helper file don't accidentally trip the test.
            guard url.lastPathComponent != "AppLog.swift" else { return false }
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return text.range(of: #"Logger[^\n]*\n?\s*\.fault\(|\)\.fault\(|Logger\.[A-Za-z]+\.fault\(|\w+\.fault\("#, options: .regularExpression) != nil
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "Logger.fault is reserved for crash-worthy conditions, not breadcrumbs. Demote to AppLog.trace or AppLog.error. Offenders: \(offenders.map(\.lastPathComponent))"
        )
    }

    // MARK: - AppLog wiring

    func test_appLogHelper_exists() throws {
        let appLogPath = sourceRoot
            .appendingPathComponent("Utilities")
            .appendingPathComponent("AppLog.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: appLogPath.path),
            "ColorFlow/Utilities/AppLog.swift is the sanctioned logging helper; removing it breaks the contract."
        )
    }
}
