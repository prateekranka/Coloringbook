import XCTest

final class PencilHIDReplayUITests: XCTestCase {
    private var app: XCUIApplication!
    private let hid = PrivatePencilHIDDevice()

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 600
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GOUACHE_PENCIL_HID_TEST"] == "1",
            "Run through Scripts/run_pencil_hid_canvas_matrix_ipad.sh"
        )
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil ||
            ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil,
            "Pencil HID replay must run on a physical iPad."
        )
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func test_probePrivateHIDRecording() throws {
        try requireMode(.probe)
        launchCanvas()
        try hid.requireAvailable()

        let url = temporaryRecordingURL(name: "probe")
        try hid.startRecording()
        Thread.sleep(forTimeInterval: 0.5)
        try hid.stopRecording(to: url)
        try attachRecording(at: url, name: "probe.hidrecording")
    }

    func test_recordPencilHIDClip() throws {
        try requireMode(.record)
        let clip = try requestedClip()
        launchCanvas()
        prepareCanvasForRecording(clip)

        Thread.sleep(forTimeInterval: 0.8)
        let url = temporaryRecordingURL(name: clip.rawValue)
        try hid.startRecording()
        Thread.sleep(forTimeInterval: recordDuration(for: clip))
        try hid.stopRecording(to: url)
        try attachRecording(at: url, name: clip.fileName)
    }

    func test_replayPencilHIDClip() throws {
        try requireMode(.replay)
        let clip = try requestedClip()
        launchCanvas()
        prepareCanvasForRecording(clip)

        let url = try materializeRecordingURL(for: clip)
        try hid.playBackRecording(from: url)
        Thread.sleep(forTimeInterval: 1.5)
    }

    func test_replayCanvasMatrixWithPencilHIDClips() throws {
        try requireMode(.matrix)
        for clip in PencilHIDClip.allCases {
            _ = try materializeRecordingURL(for: clip)
        }

        launchCanvas()
        dismissGestureTipIfNeeded()

        selectMode("Clean")
        selectTool("canvas.tool.fill-bucket")
        try replay(.fillTap)
        Thread.sleep(forTimeInterval: 0.5)

        for tool in cleanStrokeTools {
            selectTool(tool)
            try replay(.scribble)
            Thread.sleep(forTimeInterval: 0.7)
        }

        selectTool("canvas.tool.eraser")
        try replay(.outsideErase)
        Thread.sleep(forTimeInterval: 1.0)

        chooseColor(identifier: "canvas.color.2bbcb3")
        selectMode("Free")
        selectTool("canvas.tool.fill-bucket")
        try replay(.fillTap)
        Thread.sleep(forTimeInterval: 0.5)

        for tool in freeStrokeTools {
            selectTool(tool)
            try replay(.scribble)
            Thread.sleep(forTimeInterval: 0.7)
        }

        Thread.sleep(forTimeInterval: 3.0)
    }

    private var cleanStrokeTools: [String] {
        [
            "canvas.tool.crayon",
            "canvas.tool.watercolor",
            "canvas.tool.marker"
        ]
    }

    private var freeStrokeTools: [String] {
        cleanStrokeTools + ["canvas.tool.eraser"]
    }

    private func replay(_ clip: PencilHIDClip) throws {
        try hid.playBackRecording(from: materializeRecordingURL(for: clip))
    }

    private func launchCanvas() {
        let sessionID = ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_SESSION_ID"] ?? UUID().uuidString.uppercased()
        app = XCUIApplication()
        app.launchArguments = [
            "-resetSableProjects",
            "-sableUITestSeed",
            "-disableAnimations",
            "-disableTemplateThumbnailRendering",
            "--gouache-canvas-diagnostics",
            "-gouacheOpenTemplate",
            "wildflowers"
        ]
        app.launchEnvironment = [
            "GOUACHE_CANVAS_DIAGNOSTICS": "1",
            "GOUACHE_CANVAS_DIAGNOSTICS_PENCIL_MOVEMENT": "1",
            "GOUACHE_CANVAS_DIAGNOSTICS_RESET_LOG": "1",
            "GOUACHE_CANVAS_DIAGNOSTICS_LOG_EVERY_SAMPLE": "0",
            "GOUACHE_CANVAS_DIAGNOSTICS_SESSION_ID": sessionID
        ]
        app.launch()
        _ = requireCanvas()
        dismissGestureTipIfNeeded()
    }

    private func prepareCanvasForRecording(_ clip: PencilHIDClip) {
        switch clip {
        case .fillTap:
            selectMode("Clean")
            selectTool("canvas.tool.fill-bucket")
        case .scribble:
            selectMode("Clean")
            selectTool("canvas.tool.crayon")
        case .outsideErase:
            selectMode("Clean")
            selectTool("canvas.tool.crayon")
            if let scribbleURL = try? materializeRecordingURL(for: .scribble) {
                try? hid.playBackRecording(from: scribbleURL)
                Thread.sleep(forTimeInterval: 0.7)
            }
            selectTool("canvas.tool.eraser")
        }
    }

    private func requireCanvas() -> XCUIElement {
        let canvas = app.descendants(matching: .any)["canvas.surface"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 8), "Canvas did not appear.")
        return canvas
    }

    private func dismissGestureTipIfNeeded() {
        let tip = app.descendants(matching: .any)["canvas.gestureTip"]
        if tip.waitForExistence(timeout: 1), tip.isHittable {
            tip.tap()
        }
    }

    private func selectMode(_ title: String) {
        let toggle = app.descendants(matching: .any)["canvas.cleanFreeToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2), "Mode toggle did not appear.")

        if let value = toggle.value as? String, value.hasPrefix(title) {
            return
        }

        toggle.tap()
        Thread.sleep(forTimeInterval: 0.25)

        if let value = toggle.value as? String, value.hasPrefix(title) {
            return
        }
    }

    private func selectTool(_ identifier: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 2), "Tool button \(identifier) did not appear.")
        button.tap()
        Thread.sleep(forTimeInterval: 0.25)
    }

    private func chooseColor(identifier: String) {
        app.buttons["canvas.pigmentWell"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["canvas.colorTray"].waitForExistence(timeout: 2), "Color tray did not appear.")
        let colorButton = app.buttons[identifier]
        XCTAssertTrue(colorButton.waitForExistence(timeout: 2), "Color button \(identifier) did not appear.")
        colorButton.tap()
        if app.buttons["Close palette"].waitForExistence(timeout: 1) {
            app.buttons["Close palette"].tap()
        }
        XCTAssertTrue(app.buttons["canvas.pigmentWell"].waitForExistence(timeout: 2), "Pigment well did not appear.")
        Thread.sleep(forTimeInterval: 0.3)
    }

    private func requireMode(_ mode: PencilHIDMode) throws {
        let current = ProcessInfo.processInfo.environment["GOUACHE_PENCIL_HID_MODE"]
        try XCTSkipUnless(current == mode.rawValue, "Only runs with GOUACHE_PENCIL_HID_MODE=\(mode.rawValue).")
    }

    private func requestedClip() throws -> PencilHIDClip {
        let rawValue = ProcessInfo.processInfo.environment["GOUACHE_PENCIL_HID_CLIP"] ?? ""
        guard let clip = PencilHIDClip(rawValue: rawValue) else {
            XCTFail("Set GOUACHE_PENCIL_HID_CLIP to one of: \(PencilHIDClip.allCases.map(\.rawValue).joined(separator: ", "))")
            throw PencilHIDError.missingClip(rawValue)
        }
        return clip
    }

    private func recordDuration(for clip: PencilHIDClip) -> TimeInterval {
        if let rawValue = ProcessInfo.processInfo.environment["GOUACHE_PENCIL_HID_RECORD_SECONDS"],
           let value = TimeInterval(rawValue),
           value > 0 {
            return value
        }

        switch clip {
        case .fillTap:
            return 5
        case .scribble, .outsideErase:
            return 10
        }
    }

    private func temporaryRecordingURL(name: String) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString).hidrecording")
        try? FileManager.default.removeItem(at: url)
        return url
    }

    private func attachRecording(at url: URL, name: String) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? NSNumber
        XCTAssertGreaterThan(size?.intValue ?? 0, 0, "HID recording was empty.")
        let attachment = XCTAttachment(contentsOfFile: url, uniformTypeIdentifier: "public.data")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func materializeRecordingURL(for clip: PencilHIDClip) throws -> URL {
        let data = try recordingData(for: clip)
        let url = temporaryRecordingURL(name: clip.rawValue)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func recordingData(for clip: PencilHIDClip) throws -> Data {
        let environment = ProcessInfo.processInfo.environment
        let base64Keys = [
            "GOUACHE_PENCIL_HID_\(clip.environmentKey)_BASE64",
            "GOUACHE_PENCIL_HID_CLIP_DATA_BASE64"
        ]
        for key in base64Keys {
            if let encoded = environment[key], let data = Data(base64Encoded: encoded) {
                return data
            }
        }

        if let directory = environment["GOUACHE_PENCIL_HID_DIR"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(clip.fileName)
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }

        if let url = Bundle(for: Self.self).url(forResource: clip.rawValue, withExtension: "hidrecording"),
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }

        XCTFail("Missing Pencil HID recording for \(clip.rawValue).")
        throw PencilHIDError.missingRecording(clip)
    }
}

private enum PencilHIDMode: String {
    case probe
    case record
    case replay
    case matrix
}

private enum PencilHIDClip: String, CaseIterable {
    case fillTap = "fill-tap"
    case scribble
    case outsideErase = "outside-erase"

    var fileName: String {
        "\(rawValue).hidrecording"
    }

    var environmentKey: String {
        rawValue.uppercased().replacingOccurrences(of: "-", with: "_")
    }
}

private enum PencilHIDError: Error {
    case privateSelectorUnavailable(String)
    case privateCallFailed(String)
    case missingClip(String)
    case missingRecording(PencilHIDClip)
}

private struct PrivatePencilHIDDevice {
    private let startSelector = NSSelectorFromString("startHIDEventRecordingWithError:")
    private let stopSelector = NSSelectorFromString("stopHIDEventRecordingAndSaveToURL:error:")
    private let playbackSelector = NSSelectorFromString("playBackHIDEventRecordingFromURL:error:")

    func requireAvailable() throws {
        let device = XCUIDevice.shared as NSObject
        for selector in [startSelector, stopSelector, playbackSelector] where !device.responds(to: selector) {
            XCTFail("XCUIDevice does not respond to private selector \(selector).")
            throw PencilHIDError.privateSelectorUnavailable(String(describing: selector))
        }
    }

    func startRecording() throws {
        try requireAvailable()
        let device = XCUIDevice.shared as NSObject
        typealias StartIMP = @convention(c) (NSObject, Selector, UnsafeMutablePointer<NSError?>?) -> Bool
        let function = unsafeBitCast(device.method(for: startSelector), to: StartIMP.self)
        var error: NSError?
        guard function(device, startSelector, &error) else {
            throw error ?? PencilHIDError.privateCallFailed("startHIDEventRecordingWithError:")
        }
    }

    func stopRecording(to url: URL) throws {
        try requireAvailable()
        let device = XCUIDevice.shared as NSObject
        typealias StopIMP = @convention(c) (NSObject, Selector, NSURL, UnsafeMutablePointer<NSError?>?) -> Bool
        let function = unsafeBitCast(device.method(for: stopSelector), to: StopIMP.self)
        var error: NSError?
        guard function(device, stopSelector, url as NSURL, &error) else {
            throw error ?? PencilHIDError.privateCallFailed("stopHIDEventRecordingAndSaveToURL:error:")
        }
    }

    func playBackRecording(from url: URL) throws {
        try requireAvailable()
        let device = XCUIDevice.shared as NSObject
        typealias PlaybackIMP = @convention(c) (NSObject, Selector, NSURL, UnsafeMutablePointer<NSError?>?) -> Bool
        let function = unsafeBitCast(device.method(for: playbackSelector), to: PlaybackIMP.self)
        var error: NSError?
        guard function(device, playbackSelector, url as NSURL, &error) else {
            throw error ?? PencilHIDError.privateCallFailed("playBackHIDEventRecordingFromURL:error:")
        }
    }
}
