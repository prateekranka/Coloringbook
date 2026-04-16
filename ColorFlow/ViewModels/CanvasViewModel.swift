import SwiftUI
import PencilKit
import Observation

// MARK: - Fill Undo/Redo Action

struct FillAction {
    let regionID: String
    let previousHex: String?
    let newHex: String
}

// MARK: - CanvasViewModel

@MainActor
@Observable
final class CanvasViewModel {

    // MARK: - State

    var drawing = PKDrawing()
    var brushSettings = BrushSettings()
    var backgroundColor: Color = .white
    var templateImage: UIImage?
    var fillLayerImage: UIImage?
    var recentColors: [Color] = []
    var palettes: [ColorPalette] = []
    var isFilling = false
    var showLineArt = true
    var showColorLayer = true

    /// Currently highlighted/selected region ID.
    var selectedRegionID: String?

    /// Canvas size derived from the SVG viewBox after loading.
    var canvasSize: CGSize = .zero

    // MARK: - Layer Visibility Helpers

    var effectiveTemplateImage: UIImage? { showLineArt ? templateImage : nil }

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
        resolveInitialTool()
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
        AppLog.trace(AppLog.canvas, "loadTemplate: \(template.svgFilename)")

        guard let svgURL = template.svgURL else {
            AppLog.error(AppLog.canvas, "loadTemplate: svgURL is nil for '\(template.svgFilename)'")
            return
        }

        // Parse the SVG on a background thread.
        let parseResult = await Task.detached(priority: .userInitiated) {
            SVGParser.parse(url: svgURL)
        }.value

        switch parseResult {
        case .failure(let error):
            AppLog.error(AppLog.canvas, "loadTemplate: SVG parse failed for '\(template.svgFilename)' — \(error.localizedDescription)")
            return

        case .success(let geometry):
            AppLog.trace(AppLog.canvas, "loadTemplate: parse OK — \(geometry.regions.count) regions")
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

            // Load saved PKDrawing if available.
            if let savedDrawing = storageService.loadDrawing(for: project) {
                drawing = savedDrawing
            }

            // Render line art and fill layer on a background thread.
            let size = canvasSize
            let fills = paintState.regionFills

            async let lineArtTask = Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderLineArt(geometry: geometry, size: size)
            }.value

            async let fillLayerTask = Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, size: size)
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
        let previousHex = paintState.regionFills[region.id]

        // Record undo action and clear redo stack.
        let action = FillAction(regionID: region.id, previousHex: previousHex, newHex: hexColor)
        fillUndoStack.append(action)
        fillRedoStack.removeAll()

        // Apply the fill.
        paintState.regionFills[region.id] = hexColor

        // Re-render fill layer in the background.
        let fills = paintState.regionFills
        let size = canvasSize
        let updatedFillLayer = await Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, size: size)
        }.value

        fillLayerImage = updatedFillLayer
        isFilling = false

        HapticService.shared.impact(.light)
        addRecentColor(brushSettings.color)
        scheduleAutoSave()

        if !UserDefaults.standard.bool(forKey: "hasCompletedFirstFill") {
            UserDefaults.standard.set(true, forKey: "hasCompletedFirstFill")
        }
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
        if let action = fillUndoStack.popLast() {
            // Reverse the fill action.
            if let prev = action.previousHex {
                paintState.regionFills[action.regionID] = prev
            } else {
                paintState.regionFills.removeValue(forKey: action.regionID)
            }
            fillRedoStack.append(action)
            rerenderFillLayer()
            scheduleAutoSave()
        } else {
            // Fall through to PencilKit undo.
            pencilCanvas?.undoManager?.undo()
        }
    }

    func redo() {
        if let action = fillRedoStack.popLast() {
            // Re-apply the fill action.
            paintState.regionFills[action.regionID] = action.newHex
            fillUndoStack.append(action)
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
        storageService.save(project: &project, drawing: drawing, fillLayer: fillLayerImage)
    }

    // MARK: - Recent Colors

    private static let recentColorsKey = "recentColors"

    private func resolveInitialTool() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "lastUsedTool"),
           let tool = DrawingTool(rawValue: raw) {
            brushSettings.tool = tool
        } else if defaults.bool(forKey: "hasSeenOnboarding") {
            brushSettings.tool = .floodFill
        }
    }

    private func loadRecentColors() {
        let raw = UserDefaults.standard.string(forKey: Self.recentColorsKey) ?? "[]"
        guard let data = raw.data(using: .utf8),
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
            UserDefaults.standard.set(str, forKey: Self.recentColorsKey)
        }
    }

    // MARK: - Private Helpers

    /// Re-render the fill layer image from the current paint state.
    /// Called synchronously from undo/redo — fires a detached task and updates
    /// `fillLayerImage` back on the main actor when done.
    private func rerenderFillLayer() {
        guard let geometry = templateGeometry else { return }
        let fills = paintState.regionFills
        let size = canvasSize

        Task {
            let image = await Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, size: size)
            }.value
            self.fillLayerImage = image
        }
    }
}
