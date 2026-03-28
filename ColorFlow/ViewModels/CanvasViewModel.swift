import SwiftUI
import PencilKit
import Combine

// MARK: - Fill Mode

enum FillMode { case flat, gradient, pattern }

// MARK: - Fill Undo/Redo Action

struct FillAction {
    let regionID: String
    let previousHex: String?
    let newHex: String
}

// MARK: - CanvasViewModel

@MainActor
class CanvasViewModel: ObservableObject {

    // MARK: - Published State

    @Published var drawing = PKDrawing()
    @Published var brushSettings = BrushSettings()
    @Published var backgroundColor: Color = .white
    @Published var templateImage: UIImage?
    @Published var fillLayerImage: UIImage?
    @Published var recentColors: [Color] = []
    @Published var palettes: [ColorPalette] = []
    @Published var isFilling = false
    @Published var showLineArt = true
    @Published var showColorLayer = true

    /// Currently highlighted/selected region ID.
    @Published var selectedRegionID: String?

    /// Canvas size derived from the SVG viewBox after loading.
    @Published var canvasSize: CGSize = .zero
    @Published var loadError: String?
    @Published var saveError: Bool = false
    @Published var lastSaveTime: Date?
    @Published var fitToScreenTrigger: Bool = false
    @Published var completionPercentage: Double = 0
    @Published var favoriteColors: [Color] = []

    // MARK: - Fill Mode & Gradient / Pattern / Stamp State

    @Published var fillMode: FillMode = .flat
    @Published var gradientStartColor: Color = .red
    @Published var gradientEndColor: Color = .blue
    @Published var gradientAngle: Double = 0
    @Published var selectedFillPattern: FillPattern = .none
    @Published var selectedStampShape: StampShape = .star
    @Published var stampSize: Double = 30
    @Published var symmetryEnabled: Bool = false

    // MARK: - Layer Visibility Helpers

    var effectiveTemplateImage: UIImage? { showLineArt ? templateImage : nil }

    /// Read-only access to the current region fill map (for export).
    var regionFills: [String: String] { paintState.regionFills }

    // MARK: - Internal State

    private(set) var project: Project
    private(set) var template: Template
    weak var pencilCanvas: PKCanvasView?
    private var autoSaveTask: Task<Void, Never>?
    private let storageService = StorageService()

    /// Parsed SVG geometry — nil until loadTemplate() succeeds.
    private(set) var templateGeometry: TemplateGeometry?

    /// Mutable per-project fill state.
    private var paintState = ProjectPaintState()

    /// Undo/redo stacks for region fills.
    private var fillUndoStack: [FillAction] = []
    private var fillRedoStack: [FillAction] = []

    // MARK: - Persistence path

    private var paintStatePath: String { "fills/\(project.id.uuidString).json" }

    // MARK: - Init

    init(project: Project, template: Template) {
        self.project = project
        self.template = template
        self.palettes = ColorPalette.loadAll()
        loadRecentColors()
        loadFavoriteColors()
    }

    // MARK: - Current PK Tool

    var currentPKTool: PKTool {
        brushSettings.tool.pkTool(
            color: UIColor(brushSettings.color).withAlphaComponent(brushSettings.opacity),
            width: brushSettings.size
        )
    }

    // MARK: - Template Loading

    func loadTemplate() async {
        NSLog("[CanvasVM] loadTemplate: svgFilename=%@", template.svgFilename)
        NSLog("[CanvasVM] loadTemplate: svgURL=%@", template.svgURL?.path ?? "nil")
        NSLog("[CanvasVM] loadTemplate: bundleResourceURL=%@", Bundle.main.resourceURL?.path ?? "nil")

        guard let svgURL = template.svgURL else {
            NSLog("[CanvasVM] loadTemplate: FAILED — svgURL is nil for '%@'", template.svgFilename)
            loadError = "This template couldn't be loaded."
            return
        }

        NSLog("[CanvasVM] loadTemplate: parsing SVG...")

        // Parse the SVG on a background thread.
        let parseResult = await Task.detached(priority: .userInitiated) {
            SVGParser.parse(url: svgURL)
        }.value

        switch parseResult {
        case .failure(let error):
            NSLog("[CanvasVM] loadTemplate: SVG parse FAILED — %@", error.localizedDescription)
            loadError = "This template couldn't be loaded."
            return

        case .success(let geometry):
            NSLog("[CanvasVM] loadTemplate: parse OK — %d regions, viewBox=%@",
                  geometry.regions.count,
                  NSCoder.string(for: geometry.viewBox))
            templateGeometry = geometry

            // Derive canvas size from viewBox.
            canvasSize = geometry.viewBox.size

            // Load persisted paint state if available.
            let stateURL = StorageService.documentsURL
                .appendingPathComponent(paintStatePath)
            if let data = try? Data(contentsOf: stateURL),
               let saved = try? JSONDecoder().decode(ProjectPaintState.self, from: data) {
                paintState = saved
            }
            updateCompletionPercentage()

            // Load saved PKDrawing if available.
            if let savedDrawing = storageService.loadDrawing(for: project) {
                drawing = savedDrawing
            }

            // Render line art and fill layer on a background thread.
            let size = canvasSize
            let fills = paintState.regionFills
            let stamps = paintState.stamps

            async let lineArtTask = Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderLineArt(geometry: geometry, size: size)
            }.value

            async let fillLayerTask = Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, stamps: stamps, size: size)
            }.value

            let (lineArt, fillLayer) = await (lineArtTask, fillLayerTask)
            templateImage = lineArt
            fillLayerImage = fillLayer
        }
    }

    // MARK: - Region Fill (replaces flood fill)

    /// Convert a view-space tap point to document space, hit-test the geometry,
    /// apply the current brush color, and re-render the fill layer.
    func performRegionFill(at viewPoint: CGPoint, in viewSize: CGSize) async {
        guard let geometry = templateGeometry else {
            print("[ViewModel] performRegionFill — SKIPPED: templateGeometry is nil")
            return
        }

        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: viewSize
        )
        let docPoint = viewPoint.applying(transform.inverted())

        print("[ViewModel] performRegionFill — viewPoint=(\(Int(viewPoint.x)),\(Int(viewPoint.y))) viewSize=\(viewSize) viewBox=\(geometry.viewBox) docPoint=(\(Int(docPoint.x)),\(Int(docPoint.y))) regions=\(geometry.regions.count)")

        guard let region = geometry.region(at: docPoint) else {
            print("[ViewModel] performRegionFill — NO region hit at docPoint=(\(Int(docPoint.x)),\(Int(docPoint.y)))")
            return
        }
        print("[ViewModel] performRegionFill — hit region '\(region.id)' filling with \(UIColor(brushSettings.color).hexString)")

        isFilling = true

        let hexColor = UIColor(brushSettings.color).hexString

        // Build fill value based on current fill mode.
        let fillValue: String
        switch fillMode {
        case .flat:
            fillValue = hexColor
        case .gradient:
            let startHex = UIColor(gradientStartColor).hexString
            let endHex   = UIColor(gradientEndColor).hexString
            fillValue    = "gradient:\(startHex):\(endHex):\(Int(gradientAngle))"
        case .pattern:
            if selectedFillPattern == .none {
                fillValue = hexColor
            } else {
                fillValue = "pattern:\(selectedFillPattern.rawValue.lowercased()):\(hexColor)"
            }
        }

        let previousHex = paintState.regionFills[region.id]

        // Record undo action and clear redo stack.
        let action = FillAction(regionID: region.id, previousHex: previousHex, newHex: fillValue)
        fillUndoStack.append(action)
        if fillUndoStack.count > 50 { fillUndoStack.removeFirst() }
        fillRedoStack.removeAll()
        updateCompletionPercentage()

        // Apply the fill.
        paintState.regionFills[region.id] = fillValue

        // Re-render fill layer in the background.
        let fills = paintState.regionFills
        let size = canvasSize
        let currentStamps = paintState.stamps
        let updatedFillLayer = await Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, stamps: currentStamps, size: size)
        }.value

        fillLayerImage = updatedFillLayer
        isFilling = false

        HapticService.shared.impact(.light)
        SoundService.shared.playFillPop()
        addRecentColor(brushSettings.color)
        scheduleAutoSave()
    }

    // MARK: - Region Selection

    /// Hit-test the geometry and set selectedRegionID.
    func selectRegion(at viewPoint: CGPoint, in viewSize: CGSize) {
        guard let geometry = templateGeometry else { return }

        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: viewSize
        )
        let docPoint = viewPoint.applying(transform.inverted())
        selectedRegionID = geometry.region(at: docPoint)?.id
        paintState.selectedRegionID = selectedRegionID
    }

    /// Clear the current region selection.
    func clearSelection() {
        selectedRegionID = nil
        paintState.selectedRegionID = nil
    }

    // MARK: - Eyedropper

    /// Hit-test the region at the given point and read its stored fill color
    /// back into the current brush settings.
    func pickColor(at viewPoint: CGPoint, in viewSize: CGSize) {
        guard let geometry = templateGeometry else { return }

        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: viewSize
        )
        let docPoint = viewPoint.applying(transform.inverted())

        guard
            let region = geometry.region(at: docPoint),
            let hexColor = paintState.regionFills[region.id]
        else { return }

        brushSettings.color = Color(hex: hexColor)
        brushSettings.tool = .floodFill  // switch back to fill after picking
        addRecentColor(brushSettings.color)
    }

    // MARK: - Undo / Redo

    func undo() {
        HapticService.shared.impact(.light)
        if let action = fillUndoStack.popLast() {
            // Reverse the fill action.
            if let prev = action.previousHex {
                paintState.regionFills[action.regionID] = prev
            } else {
                paintState.regionFills.removeValue(forKey: action.regionID)
            }
            fillRedoStack.append(action)
            updateCompletionPercentage()
            rerenderFillLayer()
            scheduleAutoSave()
        } else {
            // Fall through to PencilKit undo.
            pencilCanvas?.undoManager?.undo()
        }
    }

    func redo() {
        HapticService.shared.impact(.light)
        if let action = fillRedoStack.popLast() {
            // Re-apply the fill action.
            paintState.regionFills[action.regionID] = action.newHex
            fillUndoStack.append(action)
            updateCompletionPercentage()
            rerenderFillLayer()
            scheduleAutoSave()
        } else {
            // Fall through to PencilKit redo.
            pencilCanvas?.undoManager?.redo()
        }
    }

    // MARK: - Auto-save

    func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func save() {
        // Persist ProjectPaintState as JSON.
        let stateURL = StorageService.documentsURL
            .appendingPathComponent(paintStatePath)

        // Ensure the fills subdirectory exists.
        let fillsDir = StorageService.documentsURL.appendingPathComponent("fills")
        try? FileManager.default.createDirectory(
            at: fillsDir,
            withIntermediateDirectories: true
        )

        if let data = try? JSONEncoder().encode(paintState) {
            try? data.write(to: stateURL, options: .atomic)
        }

        // Save PKDrawing + fill layer PNG via StorageService (also updates project index).
        do {
            project.completionFraction = completionPercentage
            try storageService.save(project: &project, drawing: drawing, fillLayer: fillLayerImage)
            lastSaveTime = Date()
            HapticService.shared.notify(.success)
            SoundService.shared.playSaveChime()
        } catch {
            NSLog("[CanvasVM] save FAILED: %@", error.localizedDescription)
            saveError = true
        }
    }

    // MARK: - Recent Colors

    @AppStorage("recentColors") private var recentColorsRaw: String = "[]"

    private func loadRecentColors() {
        guard let data = recentColorsRaw.data(using: .utf8),
              let hexArray = try? JSONDecoder().decode([String].self, from: data) else { return }
        recentColors = hexArray.map { Color(hex: $0) }
    }

    func addRecentColor(_ color: Color) {
        var updated = recentColors.filter { $0 != color }
        updated.insert(color, at: 0)
        recentColors = Array(updated.prefix(12))

        let hexArray = recentColors.map { UIColor($0).hexString }
        if let data = try? JSONEncoder().encode(hexArray),
           let str = String(data: data, encoding: .utf8) {
            recentColorsRaw = str
        }
    }

    // MARK: - Favorite Colors

    @AppStorage("favoriteColors") private var favoriteColorsRaw: String = "[]"

    private func loadFavoriteColors() {
        guard let data = favoriteColorsRaw.data(using: .utf8),
              let hexArray = try? JSONDecoder().decode([String].self, from: data) else { return }
        favoriteColors = hexArray.map { Color(hex: $0) }
    }

    func toggleFavoriteColor(_ color: Color) {
        if favoriteColors.contains(color) {
            favoriteColors.removeAll { $0 == color }
        } else {
            favoriteColors.insert(color, at: 0)
        }
        let hexArray = favoriteColors.map { UIColor($0).hexString }
        if let data = try? JSONEncoder().encode(hexArray),
           let str = String(data: data, encoding: .utf8) {
            favoriteColorsRaw = str
        }
    }

    // MARK: - Canvas Actions

    func fitToScreen() {
        fitToScreenTrigger.toggle()
    }

    var soundEnabled: Bool {
        get { SoundService.shared.isEnabled }
        set { SoundService.shared.isEnabled = newValue; objectWillChange.send() }
    }

    private func updateCompletionPercentage() {
        guard let geometry = templateGeometry, !geometry.regions.isEmpty else { return }
        completionPercentage = Double(paintState.regionFills.count) / Double(geometry.regions.count)
    }

    // MARK: - Private Helpers

    /// Re-render the fill layer image from the current paint state.
    /// Called synchronously from undo/redo — fires a detached task and updates
    /// `fillLayerImage` back on the main actor when done.
    func rerenderFillLayer() {
        guard let geometry = templateGeometry else { return }
        let fills = paintState.regionFills
        let stamps = paintState.stamps
        let size = canvasSize

        Task {
            let image = await Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, stamps: stamps, size: size)
            }.value
            self.fillLayerImage = image
        }
    }

    // MARK: - Stamp Placement

    /// Place a stamp at the given document-space point.
    func placeStamp(at docPoint: CGPoint) {
        let hex = UIColor(brushSettings.color).hexString
        let entry = StampEntry(
            id: UUID(),
            shape: selectedStampShape,
            centerX: Double(docPoint.x),
            centerY: Double(docPoint.y),
            size: stampSize,
            hexColor: hex
        )
        paintState.stamps.append(entry)
        HapticService.shared.impact(.light)
        rerenderFillLayer()
        addRecentColor(brushSettings.color)
        scheduleAutoSave()
    }
}
