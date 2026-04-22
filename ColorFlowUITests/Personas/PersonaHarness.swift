import XCTest

final class PersonaHarness: @unchecked Sendable {
    let app: XCUIApplication
    let udid: String
    private let axePath = "/opt/homebrew/bin/axe"
    private let bundleID = "com.prateekranka.colorflow"
    private var lastTree: String = ""
    private var preResolvedContainerPath: String = ""

    struct BatchStep {
        let action: String
        let id: String?
        let label: String?
        let startX: Double?
        let startY: Double?
        let endX: Double?
        let endY: Double?
        let duration: Double?

        static func tap(id: String) -> BatchStep {
            BatchStep(action: "tap", id: id, label: nil, startX: nil, startY: nil, endX: nil, endY: nil, duration: nil)
        }

        static func tap(label: String) -> BatchStep {
            BatchStep(action: "tap", id: nil, label: label, startX: nil, startY: nil, endX: nil, endY: nil, duration: nil)
        }

        static func swipe(from startX: Double, _ startY: Double, to endX: Double, _ endY: Double) -> BatchStep {
            BatchStep(action: "swipe", id: nil, label: nil, startX: startX, startY: startY, endX: endX, endY: endY, duration: nil)
        }

        static func longPress(id: String, duration: Double = 1.0) -> BatchStep {
            BatchStep(action: "touch", id: id, label: nil, startX: nil, startY: nil, endX: nil, endY: nil, duration: duration)
        }
    }

    init(app: XCUIApplication, udid: String) {
        self.app = app
        if udid.isEmpty {
            self.udid = Self.resolveBootedSimulatorUDID()
        } else {
            self.udid = udid
        }
        // Pre-resolve container path on the host before sandbox restrictions apply.
        // This is called in setUp, where posix_spawn still has host access.
        preResolvedContainerPath = Self.resolveContainerPath(udid: self.udid, bundleID: bundleID)
        app.launchEnvironment["COLORFLOW_CONTAINER_PATH"] = preResolvedContainerPath
    }

    private static func resolveBootedSimulatorUDID() -> String {
        let cmd = ["/opt/homebrew/bin/axe", "list-simulators"]
        guard let output = try? runProcessStatic(cmd) else { return "" }
        for line in output.split(separator: "\n") {
            guard line.contains("Booted") else { continue }
            let pattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: String(line), range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range, in: line) else { continue }
            return String(line[range])
        }
        return ""
    }

    private static func resolveContainerPath(udid: String, bundleID: String) -> String {
        let cmd = ["/usr/bin/xcrun", "simctl", "get_app_container", udid, bundleID, "data"]
        guard let output = try? runProcessStatic(cmd) else { return "" }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("/") ? trimmed : ""
    }

    // MARK: - Actions

    func tap(id: String, timeout: TimeInterval = 3) throws {
        let cmd = [axePath, "tap", "--udid", udid, "--id", id, "--wait-timeout", "\(Int(timeout))", "--poll-interval", "0.25"]
        try runWithRetry(cmd)
    }

    func tap(label: String, timeout: TimeInterval = 3) throws {
        let cmd = [axePath, "tap", "--udid", udid, "--label", label, "--wait-timeout", "\(Int(timeout))", "--poll-interval", "0.25"]
        try runWithRetry(cmd)
    }

    func swipe(fromId id: String, to end: CGPoint) throws {
        let frame = try resolveFrame(id: id)
        let start = CGPoint(x: frame.midX, y: frame.midY)
        let cmd = [axePath, "swipe", "--udid", udid, "--start-x", "\(start.x)", "--start-y", "\(start.y)", "--end-x", "\(end.x)", "--end-y", "\(end.y)"]
        try runWithRetry(cmd)
    }

    func longPress(id: String, duration: TimeInterval = 1.0) throws {
        let cmd = [axePath, "touch", "--udid", udid, "--id", id, "--duration", "\(duration)"]
        try runWithRetry(cmd)
    }

    @MainActor
    func rotate(to orientation: UIDeviceOrientation) throws {
        XCUIDevice.shared.orientation = orientation
        Thread.sleep(forTimeInterval: 1)
    }

    func batch(_ steps: [BatchStep]) throws {
        let batchFile = NSTemporaryDirectory() + "axe_batch_\(UUID().uuidString).json"
        let entries = steps.map { step -> [String: Any] in
            var dict: [String: Any] = ["action": step.action]
            if let id = step.id { dict["id"] = id }
            if let label = step.label { dict["label"] = label }
            if let sx = step.startX { dict["startX"] = sx }
            if let sy = step.startY { dict["startY"] = sy }
            if let ex = step.endX { dict["endX"] = ex }
            if let ey = step.endY { dict["endY"] = ey }
            if let d = step.duration { dict["duration"] = d }
            return dict
        }
        let data = try JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted)
        try data.write(to: URL(fileURLWithPath: batchFile))
        defer { try? FileManager.default.removeItem(atPath: batchFile) }
        let cmd = [axePath, "batch", "--udid", udid, "--file", batchFile, "--ax-cache", "perBatch"]
        try runWithRetry(cmd)
    }

    // MARK: - State

    func describeUI() throws -> String {
        let cmd = [axePath, "describe-ui", "--udid", udid]
        return try runProcess(cmd)
    }

    func resolveFrame(id: String) throws -> CGRect {
        let tree = try describeUI()
        lastTree = tree
        guard let range = tree.range(of: "\"\(id)\"") else {
            throw PersonaError.elementNotFound(id)
        }
        let searchStart = tree.index(range.lowerBound, offsetBy: -500, limitedBy: tree.startIndex) ?? tree.startIndex
        let snippet = String(tree[searchStart..<tree.endIndex])
        let pattern = #"frame\:\s*\{[^}]*x\:\s*([0-9.]+)[^}]*y\:\s*([0-9.]+)[^}]*width\:\s*([0-9.]+)[^}]*height\:\s*([0-9.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: snippet, range: NSRange(snippet.startIndex..., in: snippet)),
              match.numberOfRanges == 5 else {
            throw PersonaError.frameNotFound(id)
        }
        let x = Double(snippet[Range(match.range(at: 1), in: snippet)!]) ?? 0
        let y = Double(snippet[Range(match.range(at: 2), in: snippet)!]) ?? 0
        let w = Double(snippet[Range(match.range(at: 3), in: snippet)!]) ?? 0
        let h = Double(snippet[Range(match.range(at: 4), in: snippet)!]) ?? 0
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func dataContainerPath() throws -> String {
        // Resolve on the host before the test runs. The harness init
        // pre-resolves this via xcrun simctl (called from setUp).
        guard !preResolvedContainerPath.isEmpty else {
            throw PersonaError.containerNotFound(udid)
        }
        return preResolvedContainerPath
    }

    func documentsSnapshot() throws -> [URL] {
        guard let container = try? dataContainerPath() else { return [] }
        let docsURL = URL(fileURLWithPath: container).appendingPathComponent("Documents")
        guard let enumerator = FileManager.default.enumerator(at: docsURL, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.allObjects.compactMap { $0 as? URL }
    }

    func projectsJSONData() throws -> Data? {
        guard let container = try? dataContainerPath() else { return nil }
        let url = URL(fileURLWithPath: container).appendingPathComponent("Documents/projects.json")
        return try? Data(contentsOf: url)
    }

    func captureDiagnostics(testCase: XCTestCase) {
        let attachment = XCTAttachment(string: lastTree)
        attachment.name = "Last describe-ui tree"
        testCase.add(attachment)
    }

    // MARK: - Process

    private static func runProcessStatic(_ args: [String]) throws -> String {
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        var stdoutPipe: [CInt] = [-1, -1]
        var stderrPipe: [CInt] = [-1, -1]
        pipe(&stdoutPipe)
        pipe(&stderrPipe)

        posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[1])
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[1])

        let cArgs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0)! } + [nil]
        defer { for ptr in cArgs { if let p = ptr { free(p) } } }

        var pid: pid_t = 0
        let spawnResult = posix_spawn(&pid, args[0], &fileActions, nil, cArgs, nil)

        if spawnResult != 0 {
            close(stdoutPipe[0])
            close(stdoutPipe[1])
            close(stderrPipe[0])
            close(stderrPipe[1])
            throw PersonaError.processFailed(args.joined(separator: " "), Int(spawnResult), "posix_spawn error \(spawnResult)")
        }

        close(stdoutPipe[1])
        close(stderrPipe[1])

        var output = ""
        var buffer = [UInt8](repeating: 0, count: 4096)
        var bytesRead: Int
        repeat {
            bytesRead = read(stdoutPipe[0], &buffer, buffer.count)
            if bytesRead > 0 {
                output += String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
            }
        } while bytesRead > 0
        close(stdoutPipe[0])

        close(stderrPipe[0])
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        return output
    }

    private func runWithRetry(_ args: [String], maxRetries: Int = 2) throws {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                _ = try runProcess(args)
                return
            } catch {
                lastError = error
                if attempt < maxRetries {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
        throw lastError!
    }

    @discardableResult
    private func runProcess(_ args: [String]) throws -> String {
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        var stdoutPipe: [CInt] = [-1, -1]
        var stderrPipe: [CInt] = [-1, -1]
        pipe(&stdoutPipe)
        pipe(&stderrPipe)

        posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[1])
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[1])

        let cArgs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0)! } + [nil]
        defer { for ptr in cArgs { if let p = ptr { free(p) } } }

        var pid: pid_t = 0
        let spawnResult = posix_spawn(&pid, args[0], &fileActions, nil, cArgs, nil)

        if spawnResult != 0 {
            close(stdoutPipe[0])
            close(stdoutPipe[1])
            close(stderrPipe[0])
            close(stderrPipe[1])
            throw PersonaError.processFailed(args.joined(separator: " "), Int(spawnResult), "posix_spawn error \(spawnResult)")
        }

        close(stdoutPipe[1])
        close(stderrPipe[1])

        var output = ""
        var buffer = [UInt8](repeating: 0, count: 4096)
        var bytesRead: Int
        repeat {
            bytesRead = read(stdoutPipe[0], &buffer, buffer.count)
            if bytesRead > 0 {
                output += String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
            }
        } while bytesRead > 0
        close(stdoutPipe[0])

        var stderrOutput = ""
        repeat {
            bytesRead = read(stderrPipe[0], &buffer, buffer.count)
            if bytesRead > 0 {
                stderrOutput += String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
            }
        } while bytesRead > 0
        close(stderrPipe[0])

        var status: Int32 = 0
        waitpid(pid, &status, 0)

        let exitCode = (status >> 8) & 0xFF
        if exitCode != 0 {
            throw PersonaError.processFailed(args.joined(separator: " "), Int(exitCode), output + stderrOutput)
        }
        return output
    }

    enum PersonaError: Error, CustomStringConvertible {
        case elementNotFound(String)
        case frameNotFound(String)
        case containerNotFound(String)
        case processFailed(String, Int, String)

        var description: String {
            switch self {
            case .elementNotFound(let id): return "Element not found: \(id)"
            case .frameNotFound(let id): return "Frame not found for element: \(id)"
            case .containerNotFound(let udid): return "App data container not found for simulator: \(udid)"
            case .processFailed(let cmd, let code, let output): return "Process failed (exit \(code)): \(cmd)\n\(output)"
            }
        }
    }
}