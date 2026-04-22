import SwiftUI
import PencilKit
import Observation

struct FillAction {
    let regionID: String
    let previousHex: String?
    let newHex: String
}

@MainActor
@Observable
final class CanvasViewModel {

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

    var canvasSize: CGSize = .zero

    var effectiveTemplateImage: UIImage? { showLineArt ? templateImage : nil }

    private(set) var project: Project
    private(set) var template: Template
    weak var pencilCanvas: PKCanvasView?
    private var autoSaveTask: Task<Void, Never>?
    private let storageService = StorageService()

    private(set) var templateGeometry: TemplateGeometry?

    private var paintState = ProjectPaintState()

    private var fillUndoStack: [FillAction] = []
    private var fillRedoStack: [FillAction] = []

    private var paintStatePath: String { "fills/\(project.id.uuidString).json" }

    init(project: Project, template: Template) {
        self.project = project
        self.template = template
        Task { @MainActor in
            self.palettes = ColorPalette.loadAll()
            loadRecentColors()
        }
    }

    var currentPKTool: PKTool {
        brushSettings.tool.pkTool(
            color: UIColor(brushSettings.color).withAlphaComponent(brushSettings.opacity),
            width: brushSettings.size
        )
    }

    func loadTemplate() async {
        AppLog.trace(AppLog.canvas, "loadTemplate: \(template.svgFilename)")

        guard let svgURL = template.svgURL else {
            AppLog.error(AppLog.canvas, "loadTemplate: svgURL is nil for '\(template.svgFilename)'")
            return
        }

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

            canvasSize = geometry.viewBox.size

            let stateURL = StorageService.documentsURL
                .appendingPathComponent(paintStatePath)
            if let data = try? Data(contentsOf: stateURL),
               let saved = try? JSONDecoder().decode(ProjectPaintState.self, from: data) {
                paintState = saved
            }

            if let savedDrawing = storageService.loadDrawing(for: project) {
                drawing = savedDrawing
            }

            let size = canvasSize
            let fills = paintState.regionFills
            let lineArtColor = UIColor.black

            async let lineArtTask = Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderLineArt(geometry: geometry, size: size, strokeColor: lineArtColor)
            }.value

            async let fillLayerTask = Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, size: size)
            }.value

            let (lineArt, fillLayer) = await (lineArtTask, fillLayerTask)
            templateImage = lineArt
            fillLayerImage = fillLayer
        }
    }

    func reloadLineArt() {
        guard let geometry = templateGeometry else { return }
        let size = canvasSize
        let lineArtColor = UIColor.black

        Task {
            let image = await Task.detached(priority: .userInitiated) {
                TemplateRenderer.renderLineArt(geometry: geometry, size: size, strokeColor: lineArtColor)
            }.value
            self.templateImage = image
        }
    }

    func performRegionFill(atDocumentPoint docPoint: CGPoint) async {
        guard let geometry = templateGeometry else { return }

        guard let region = geometry.region(at: docPoint) else {
            AppLog.trace(
                AppLog.canvas,
                "performRegionFill — no region at (\(Int(docPoint.x)),\(Int(docPoint.y)))"
            )
            return
        }

        isFilling = true

        let hexColor = UIColor(brushSettings.color).hexString
        let previousHex = paintState.regionFills[region.id]

        let action = FillAction(regionID: region.id, previousHex: previousHex, newHex: hexColor)
        fillUndoStack.append(action)
        fillRedoStack.removeAll()

        paintState.regionFills[region.id] = hexColor

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
    }

    func pickColor(atDocumentPoint docPoint: CGPoint) {
        guard let geometry = templateGeometry else { return }

        guard
            let region = geometry.region(at: docPoint),
            let hexColor = paintState.regionFills[region.id]
        else { return }

        brushSettings.color = Color(hex: hexColor)
        brushSettings.tool = .floodFill
        addRecentColor(brushSettings.color)
    }

    func undo() {
        if let action = fillUndoStack.popLast() {
            if let prev = action.previousHex {
                paintState.regionFills[action.regionID] = prev
            } else {
                paintState.regionFills.removeValue(forKey: action.regionID)
            }
            fillRedoStack.append(action)
            rerenderFillLayer()
            scheduleAutoSave()
        } else {
            pencilCanvas?.undoManager?.undo()
        }
    }

    func redo() {
        if let action = fillRedoStack.popLast() {
            paintState.regionFills[action.regionID] = action.newHex
            fillUndoStack.append(action)
            rerenderFillLayer()
            scheduleAutoSave()
        } else {
            pencilCanvas?.undoManager?.redo()
        }
    }

    func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func save() {
        let stateURL = StorageService.documentsURL
            .appendingPathComponent(paintStatePath)

        let fillsDir = StorageService.documentsURL.appendingPathComponent("fills")
        try? FileManager.default.createDirectory(
            at: fillsDir,
            withIntermediateDirectories: true
        )

        if let data = try? JSONEncoder().encode(paintState) {
            try? data.write(to: stateURL, options: .atomic)
        }

        storageService.save(
            project: &project,
            drawing: drawing,
            fillLayer: fillLayerImage,
            templateImage: templateImage
        )
        ProjectThumbnailCache.shared.invalidate(id: project.id)
    }

    private static let recentColorsKey = "recentColors"

    private func loadRecentColors() {
        let raw = UserDefaults.standard.string(forKey: Self.recentColorsKey) ?? "[]"
        guard let data = raw.data(using: .utf8),
              let hexArray = try? JSONDecoder().decode([String].self, from: data) else { return }
        recentColors = hexArray.map { Color(hex: $0) }
    }

    func addRecentColor(_ color: Color) {
        let hex = UIColor(color).hexString
        if let first = recentColors.first, UIColor(first).hexString == hex { return }

        var updated = recentColors.filter { UIColor($0).hexString != hex }
        updated.insert(color, at: 0)
        recentColors = Array(updated.prefix(12))

        let hexArray = recentColors.map { UIColor($0).hexString }
        if let data = try? JSONEncoder().encode(hexArray),
           let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: Self.recentColorsKey)
        }
    }

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
