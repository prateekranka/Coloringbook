import XCTest

final class PersonaHarness: @unchecked Sendable {
    let app: XCUIApplication
    let udid: String
    private let axePath = "/opt/homebrew/bin/axe"
    private let bundleID = "com.prateekranka.colorflow"
    private var lastTree: String = ""

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
        self.udid = udid
    }

    // MARK: - Actions

    func tap(id: String, timeout: TimeInterval = 3) throws {
        let cmd = [axePath, "tap", "--id", id, "--wait-timeout", "\(Int(timeout))", "--poll-interval", "0.25"]
        try runWithRetry(cmd)
    }

    func tap(label: String, timeout: TimeInterval = 3) throws {
        let cmd = [axePath, "tap", "--label", label, "--wait-timeout", "\(Int(timeout))", "--poll-interval", "0.25"]
        try runWithRetry(cmd)
    }

    func swipe(fromId id: String, to end: CGPoint) throws {
        let frame = try resolveFrame(id: id)
        let start = CGPoint(x: frame.midX, y: frame.midY)
        let cmd = [axePath, "swipe", "--start-x", "\(start.x)", "--start-y", "\(start.y)", "--end-x", "\(end.x)", "--end-y", "\(end.y)"]
        try runWithRetry(cmd)
    }

    func longPress(id: String, duration: TimeInterval = 1.0) throws {
        let cmd = [axePath, "touch", "--id", id, "--duration", "\(duration)"]
        try runWithRetry(cmd)
    }

    func rotate(to orientation: UIDeviceOrientation) throws {
        let orientationStr: String
        switch orientation {
        case .landscapeLeft: orientationStr = "landscape"
        case .portrait: orientationStr = "portrait"
        default: orientationStr = "portrait"
        }
        let cmd = ["/usr/bin/xcrun", "simctl", "status_bar", udid, "override", "--orientation", orientationStr]
        try runProcess(cmd)
        sleep(1)
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
        let cmd = [axePath, "batch", "--file", batchFile, "--ax-cache", "perBatch"]
        try runWithRetry(cmd)
    }

    // MARK: - State

    func describeUI() throws -> String {
        let cmd = [axePath, "describe-ui"]
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
        let cmd = ["/usr/bin/xcrun", "simctl", "get_app_container", udid, bundleID, "data"]
        let result = try runProcess(cmd)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func documentsSnapshot() throws -> [URL] {
        let container = try dataContainerPath()
        let docsURL = URL(fileURLWithPath: container).appendingPathComponent("Documents")
        guard let enumerator = FileManager.default.enumerator(at: docsURL, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.allObjects.compactMap { $0 as? URL }
    }

    func projectsJSONData() throws -> Data? {
        let container = try dataContainerPath()
        let url = URL(fileURLWithPath: container).appendingPathComponent("Documents/projects.json")
        return try? Data(contentsOf: url)
    }

    func captureDiagnostics(testCase: XCTestCase) {
        let attachment = XCTAttachment(string: lastTree)
        attachment.name = "Last describe-ui tree"
        testCase.add(attachment)
    }

    // MARK: - Process

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
        case processFailed(String, Int, String)

        var description: String {
            switch self {
            case .elementNotFound(let id): return "Element not found: \(id)"
            case .frameNotFound(let id): return "Frame not found for element: \(id)"
            case .processFailed(let cmd, let code, let output): return "Process failed (exit \(code)): \(cmd)\n\(output)"
            }
        }
    }
}