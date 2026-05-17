import CoreGraphics
import Observation
import PencilKit
import SwiftUI
import UIKit

@MainActor
@Observable
final class ColoringSessionViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    enum SaveState: Equatable {
        case saved
        case dirty
        case saving

        var label: String {
            switch self {
            case .saved:
                return "Saved"
            case .dirty:
                return "Unsaved changes"
            case .saving:
                return "Saving..."
            }
        }

        var systemImageName: String {
            switch self {
            case .saved:
                return "checkmark.circle.fill"
            case .dirty:
                return "circle.dashed"
            case .saving:
                return "arrow.triangle.2.circlepath"
            }
        }
    }

    var state: LoadState = .idle
    var project: Project?
    var template: Template?
    var lineArtImage: UIImage?
    var fillLayerImage: UIImage?
    var freehandDrawing = PKDrawing()
    var selectedColorHex = SableTheme.progressPinkHex
    var selectedPaletteID = ColoringSessionViewModel.essentialsPalette.id
    var selectedTool: ToolType = .crayon
    var selectedToolSettings = ToolType.crayon.defaultSettings
    var coloringMode: CanvasColoringMode = .clean
    var recentColorHexes: [String] = [SableTheme.progressPinkHex]
    var canvasDocumentSize = CGSize(width: 800, height: 800)
    var viewport = CanvasViewport()
    var saveState: SaveState = .saved
    var canUndo = false
    var canRedo = false

    @ObservationIgnored private let repository: any ColoringFlowRepositoryProtocol
    @ObservationIgnored private let storageService: StorageService
    @ObservationIgnored private let initialProject: Project?
    @ObservationIgnored private let initialTemplate: Template?
    @ObservationIgnored private let projectId: UUID?
    @ObservationIgnored private let templateId: UUID?
    @ObservationIgnored private var geometry: TemplateGeometry?
    @ObservationIgnored private var pigmentEngine: RegionPigmentEngine?
    @ObservationIgnored var paintState = ProjectPaintState()
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var lastSavedRegionFills: [String: String] = [:]
    @ObservationIgnored private var lastSavedStrokeActions: [StrokeAction] = []
    @ObservationIgnored private var hasUnsavedPigmentChanges = false
    @ObservationIgnored private var undoStack: [CanvasEditAction] = []
    @ObservationIgnored private var redoStack: [CanvasEditAction] = []
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    @ObservationIgnored private var toolSettingsCache: [ToolType: ToolSettings] = Dictionary(
        uniqueKeysWithValues: ToolType.allCases.map { ($0, $0.defaultSettings) }
    )

    let fallbackTitle: String
    let palettes: [ColorPalette]

    init(
        project: Project,
        template: Template,
        storageService: StorageService = StorageService()
    ) {
        self.initialProject = project
        self.initialTemplate = template
        self.projectId = project.id
        self.templateId = template.id
        self.fallbackTitle = template.name
        self.repository = SableHomeRepository(storageService: storageService, templates: [template])
        self.storageService = storageService
        self.palettes = Self.makePalettes()
    }

    init(
        projectId: UUID?,
        templateId: UUID?,
        fallbackTitle: String,
        repository: any ColoringFlowRepositoryProtocol = SableHomeRepository(),
        storageService: StorageService = StorageService()
    ) {
        self.initialProject = nil
        self.initialTemplate = nil
        self.projectId = projectId
        self.templateId = templateId
        self.fallbackTitle = fallbackTitle
        self.repository = repository
        self.storageService = storageService
        self.palettes = Self.makePalettes()
    }

    var title: String {
        template?.name ?? project?.templateName ?? fallbackTitle
    }

    var progress: Double {
        project?.completionPercentage ?? 0
    }

    var progressLabel: String {
        "\(Int((progress * 100).rounded()))%"
    }

    var filledRegionCount: Int {
        paintState.regionFills.count
    }

    var isSaving: Bool {
        saveState == .saving
    }

    var canSave: Bool {
        saveState == .dirty
    }

    var hasArtwork: Bool {
        !paintState.regionFills.isEmpty || !paintState.strokeActions.isEmpty || !freehandDrawing.bounds.isEmpty
    }

    var selectedPalette: ColorPalette {
        palettes.first { $0.id == selectedPaletteID } ?? Self.essentialsPalette
    }

    var selectedSwatches: [ColorSwatch] {
        selectedPalette.swatches
    }

    var selectedColorName: String {
        palettes
            .flatMap(\.swatches)
            .first { $0.hex.caseInsensitiveCompare(selectedColorHex) == .orderedSame }?
            .name ?? selectedColorHex
    }

    func selectPalette(_ palette: ColorPalette) {
        selectedPaletteID = palette.id
    }

    func selectColor(hex: String) {
        selectedColorHex = hex
        recentColorHexes.removeAll { $0.caseInsensitiveCompare(hex) == .orderedSame }
        recentColorHexes.insert(hex, at: 0)
        recentColorHexes = Array(recentColorHexes.prefix(8))
    }

    func selectTool(_ tool: ToolType) {
        selectedTool = tool
        selectedToolSettings = toolSettingsCache[tool] ?? tool.defaultSettings
        paintState.canvasState.selectedTool = tool
        markCanvasStateDirty()
    }

    func updateSelectedToolSize(_ size: CGFloat) {
        guard selectedTool.supportsSizeControl else { return }
        selectedToolSettings.size = min(max(size, ToolSettings.sizeRange.lowerBound), ToolSettings.sizeRange.upperBound)
        toolSettingsCache[selectedTool] = selectedToolSettings
    }

    func updateSelectedToolOpacity(_ opacity: Double) {
        guard selectedTool.supportsOpacityControl else { return }
        selectedToolSettings.opacity = min(max(opacity, ToolSettings.opacityRange.lowerBound), ToolSettings.opacityRange.upperBound)
        toolSettingsCache[selectedTool] = selectedToolSettings
    }

    func selectColoringMode(_ mode: CanvasColoringMode) {
        coloringMode = mode
        paintState.canvasState.coloringMode = mode
        markCanvasStateDirty()
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        state = .loading

        guard let seed = await resolveSeed() else {
            state = .failed("This coloring page could not be found.")
            return
        }

        project = seed.project
        template = seed.template

        guard let svgURL = seed.template.svgURL else {
            state = .failed("Template file not found.")
            return
        }

        let parseResult = await Task.detached(priority: .userInitiated) {
            SVGParser.parse(url: svgURL)
        }.value

        switch parseResult {
        case .failure(let error):
            state = .failed(error.localizedDescription)
        case .success(let parsedGeometry):
            geometry = parsedGeometry
            canvasDocumentSize = parsedGeometry.viewBox.size
            paintState = storageService.loadPaintState(for: seed.project)
            let storedPigment = storageService.loadFillLayer(for: seed.project)
            if let storedPigment {
                pigmentEngine = RegionPigmentEngine(geometry: parsedGeometry, existingImage: storedPigment)
            } else {
                pigmentEngine = nil
            }
            if let drawing = storageService.loadDrawing(for: seed.project) {
                freehandDrawing = drawing
            } else if let data = paintState.freehandDrawingData,
                      let drawing = try? PKDrawing(data: data) {
                freehandDrawing = drawing
            }
            selectedTool = paintState.canvasState.selectedTool
            selectedToolSettings = toolSettingsCache[selectedTool] ?? selectedTool.defaultSettings
            coloringMode = paintState.canvasState.coloringMode
            viewport = CanvasViewport(canvasState: paintState.canvasState)
            lastSavedRegionFills = paintState.regionFills
            lastSavedStrokeActions = paintState.strokeActions
            clearUndoHistory()
            saveState = .saved
            await renderImages(geometry: parsedGeometry)
            hasLoaded = true
            state = .ready
        }
    }

    func updateCanvasStrokeWidth(_ strokeWidthPixels: Double) async {
        guard let geometry else { return }
        lineArtImage = await renderLineArtImage(
            geometry: geometry,
            lineArtURL: template?.lineArtURL,
            strokeWidthPixels: CGFloat(strokeWidthPixels)
        )
    }

    func updateViewport(_ nextViewport: CanvasViewport) {
        viewport = nextViewport
    }

    func commitViewportChange() {
        storeViewportState()
        markCanvasStateDirty()
    }

    @discardableResult
    func fill(atCanvasPoint point: CGPoint, canvasSize: CGSize) async -> Bool {
        guard let geometry else { return false }
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let documentPoint = point.applying(transform.inverted())
        return await fill(atDocumentPoint: documentPoint)
    }

    @discardableResult
    func fill(atDocumentPoint point: CGPoint) async -> Bool {
        guard let geometry,
              let region = geometry.region(at: point) else { return false }

        let previousHex = paintState.regionFills[region.id]
        guard let patch = pigmentEngine?.fill(regionID: region.id, colorHex: selectedColorHex) else { return false }
        paintState.regionFills[region.id] = selectedColorHex
        undoStack.append(.fillPatch(FillPatchAction(regionID: region.id, previousHex: previousHex, newHex: selectedColorHex, patch: patch)))
        redoStack.removeAll()
        syncUndoRedoState()
        fillLayerImage = pigmentEngine?.image
        hasUnsavedPigmentChanges = true
        await refreshArtworkAfterEdit()

        HapticService.shared.impact(.light)
        return true
    }

    func undoLastFill() async {
        guard let action = undoStack.popLast() else { return }
        redoStack.append(action)
        syncUndoRedoState()
        applyUndo(action)
        await refreshArtworkAfterEdit()
    }

    func redoFill() async {
        guard let action = redoStack.popLast() else { return }
        undoStack.append(action)
        syncUndoRedoState()
        applyRedo(action)
        await refreshArtworkAfterEdit()
    }

    func clearArtwork() async {
        guard hasArtwork else { return }
        paintState.regionFills.removeAll()
        paintState.strokeActions.removeAll()
        freehandDrawing = PKDrawing()
        if let geometry {
            pigmentEngine = RegionPigmentEngine(geometry: geometry)
            fillLayerImage = pigmentEngine?.image
        }
        clearUndoHistory()
        hasUnsavedPigmentChanges = true
        await refreshArtworkAfterEdit()
        HapticService.shared.impact(.medium)
    }

    func save() {
        guard var mutableProject = project else { return }
        autosaveTask?.cancel()
        paintState.canvasState.selectedTool = selectedTool
        paintState.canvasState.coloringMode = coloringMode
        paintState.freehandDrawingData = freehandDrawing.dataRepresentation()
        paintState.version = 2
        paintState.pigmentLayerFilename = mutableProject.fillLayerPath
        storeViewportState()
        saveState = .saving
        storageService.savePaintState(paintState, for: mutableProject)
        storageService.save(
            project: &mutableProject,
            drawing: freehandDrawing,
            fillLayer: pigmentEngine?.image ?? fillLayerImage,
            templateImage: lineArtImage
        )
        project = mutableProject
        ProjectThumbnailCache.shared.invalidate(id: mutableProject.id)
        lastSavedRegionFills = paintState.regionFills
        lastSavedStrokeActions = paintState.strokeActions
        hasUnsavedPigmentChanges = false
        saveState = .saved
    }

    func saveNow() {
        guard saveState == .dirty else { return }
        save()
    }

    func exportImage(backgroundColor: UIColor = .white) -> UIImage? {
        guard let geometry else { return nil }
        return ExportService().compositeImage(
            geometry: geometry,
            fills: paintState.regionFills,
            pigmentLayer: pigmentEngine?.image ?? fillLayerImage,
            drawing: freehandDrawing,
            backgroundColor: backgroundColor,
            size: geometry.viewBox.size
        )
    }

    @discardableResult
    func drawStroke(canvasPoints: [CGPoint], canvasSize: CGSize) async -> Bool {
        await drawStroke(
            samples: canvasPoints.map { StrokeSample(point: $0) },
            canvasSize: canvasSize
        )
    }

    @discardableResult
    func drawStroke(samples canvasSamples: [StrokeSample], canvasSize: CGSize) async -> Bool {
        guard let geometry, !canvasSamples.isEmpty else { return false }

        if selectedTool == .fillBucket, let firstPoint = canvasSamples.first?.cgPoint {
            return await fill(atCanvasPoint: firstPoint, canvasSize: canvasSize)
        }

        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        ).inverted()
        let documentSamples = canvasSamples.map { sample in
            StrokeSample(
                point: sample.cgPoint.applying(transform),
                timestamp: sample.timestamp,
                force: sample.force,
                altitude: sample.altitude,
                azimuth: sample.azimuth,
                isPredicted: sample.isPredicted
            )
        }
        let documentPoints = documentSamples.map(\.cgPoint)
        let clippedRegionID = coloringMode == .clean
            ? documentPoints.first.flatMap { geometry.region(at: $0)?.id }
            : nil

        let patch: PigmentPatch?
        if coloringMode == .clean {
            patch = pigmentEngine?.renderCleanStroke(
                tool: selectedTool,
                colorHex: selectedColorHex,
                points: documentPoints,
                size: selectedToolSettings.size,
                opacity: selectedTool == .eraser ? 1 : selectedToolSettings.opacity
            )
        } else {
            patch = pigmentEngine?.renderFreeStroke(
                tool: selectedTool,
                colorHex: selectedColorHex,
                points: documentPoints,
                size: selectedToolSettings.size,
                opacity: selectedTool == .eraser ? 1 : selectedToolSettings.opacity
            )
        }

        guard let patch else { return false }
        let action = StrokeAction(
            tool: selectedTool,
            colorHex: selectedTool == .eraser ? "#000000" : selectedColorHex,
            points: documentPoints.map { CodablePoint(x: $0.x, y: $0.y) },
            samples: documentSamples,
            clippedRegionID: clippedRegionID,
            size: selectedToolSettings.size,
            opacity: selectedTool == .eraser ? 1 : selectedToolSettings.opacity
        )
        paintState.strokeActions.append(action)
        undoStack.append(selectedTool == .eraser ? .erasePatch(StrokePatchAction(action: action, patch: patch)) : .pigmentStrokePatch(StrokePatchAction(action: action, patch: patch)))
        redoStack.removeAll()
        syncUndoRedoState()
        fillLayerImage = pigmentEngine?.image
        hasUnsavedPigmentChanges = true
        await refreshArtworkAfterEdit()
        HapticService.shared.impact(.light)
        return true
    }

    func updateFreehandDrawing(_ drawing: PKDrawing) {
        guard drawing.dataRepresentation() != freehandDrawing.dataRepresentation() else { return }
        freehandDrawing = drawing
        paintState.freehandDrawingData = drawing.dataRepresentation()
        markCanvasStateDirty()
    }

    func liveStrokeClip(samples canvasSamples: [StrokeSample], canvasSize: CGSize) -> StrokeRenderClip? {
        guard coloringMode == .clean,
              let geometry,
              let firstCanvasPoint = canvasSamples.first?.cgPoint else {
            return nil
        }

        var documentToCanvas = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let documentPoint = firstCanvasPoint.applying(documentToCanvas.inverted())
        guard let region = geometry.region(at: documentPoint),
              let canvasPath = region.path.copy(using: &documentToCanvas) else {
            return nil
        }

        return StrokeRenderClip(path: canvasPath, fillRule: region.fillRule)
    }

    private func resolveSeed() async -> (project: Project, template: Template)? {
        if let initialProject, let initialTemplate {
            return (initialProject, initialTemplate)
        }
        return await repository.resolveProject(projectId: projectId, templateId: templateId)
    }

    private func renderImages(geometry: TemplateGeometry) async {
        let size = geometry.viewBox.size
        let lineArtURL = template?.lineArtURL

        async let lineArtTask = renderLineArtImage(
            geometry: geometry,
            lineArtURL: lineArtURL,
            strokeWidthPixels: CGFloat(RenderTuningStore.defaultCanvasStrokeWidth)
        )

        let lineArt = await lineArtTask
        lineArtImage = lineArt
        if let engineImage = pigmentEngine?.image {
            fillLayerImage = engineImage
        } else if let project, let storedImage = storageService.loadFillLayer(for: project) {
            pigmentEngine = RegionPigmentEngine(geometry: geometry, existingImage: storedImage)
            fillLayerImage = storedImage
        } else {
            let renderedFillLayer = TemplateRenderer.renderFillLayer(geometry: geometry, fills: paintState.regionFills, size: size)
            let legacyLayer = renderStrokeActions(on: renderedFillLayer, geometry: geometry)
            pigmentEngine = RegionPigmentEngine(geometry: geometry, existingImage: legacyLayer)
            fillLayerImage = legacyLayer
        }
    }

    private func renderLineArtImage(
        geometry: TemplateGeometry,
        lineArtURL: URL?,
        strokeWidthPixels: CGFloat
    ) async -> UIImage {
        let size = geometry.viewBox.size
        if let lineArtURL {
            let image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: lineArtURL.path)
            }.value
            if let image {
                return image
            }
        }

        return await Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderLineArt(
                geometry: geometry,
                size: size,
                strokeWidthPixels: strokeWidthPixels
            )
        }.value
    }

    private func storeViewportState() {
        let values = viewport.canvasStateValues
        paintState.canvasState.zoomScale = values.zoomScale
        paintState.canvasState.offsetX = values.offsetX
        paintState.canvasState.offsetY = values.offsetY
    }

    private func applyFill(regionID: String, hex: String?) {
        if let hex {
            paintState.regionFills[regionID] = hex
        } else {
            paintState.regionFills.removeValue(forKey: regionID)
        }
    }

    private func refreshArtworkAfterEdit() async {
        updateProjectCompletion()
        fillLayerImage = pigmentEngine?.image ?? fillLayerImage
        updateSaveStateForCurrentPaint()
    }

    private func updateProjectCompletion() {
        guard let geometry, var mutableProject = project else { return }
        mutableProject.updateCompletion(
            filledRegionCount: paintState.regionFills.count,
            totalRegionCount: geometry.regions.count
        )
        project = mutableProject
    }

    private func renderCurrentFillLayer() async {
        guard geometry != nil else { return }
        fillLayerImage = pigmentEngine?.image
    }

    private func updateSaveStateForCurrentPaint() {
        guard saveState != .saving else { return }
        saveState = paintState.regionFills == lastSavedRegionFills
            && paintState.strokeActions == lastSavedStrokeActions
            && !hasUnsavedPigmentChanges ? .saved : .dirty
        if saveState == .dirty {
            scheduleAutosave()
        }
    }

    private func markCanvasStateDirty() {
        guard hasLoaded else { return }
        hasUnsavedPigmentChanges = true
        saveState = .dirty
        scheduleAutosave()
    }

    private func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        syncUndoRedoState()
    }

    private func syncUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func applyUndo(_ action: CanvasEditAction) {
        switch action {
        case .fillPatch(let action):
            applyFill(regionID: action.regionID, hex: action.previousHex)
            pigmentEngine?.restore(action.patch.before)
            fillLayerImage = action.patch.before
            hasUnsavedPigmentChanges = !(paintState.regionFills == lastSavedRegionFills && paintState.strokeActions == lastSavedStrokeActions)
        case .pigmentStrokePatch(let action), .erasePatch(let action):
            paintState.strokeActions.removeAll { $0.id == action.action.id }
            pigmentEngine?.restore(action.patch.before)
            fillLayerImage = action.patch.before
            hasUnsavedPigmentChanges = true
        case .clear(let previousFills, let previousStrokes, let previousImage, _):
            paintState.regionFills = previousFills
            paintState.strokeActions = previousStrokes
            pigmentEngine?.restore(previousImage)
            fillLayerImage = previousImage
            hasUnsavedPigmentChanges = true
        }
    }

    private func applyRedo(_ action: CanvasEditAction) {
        switch action {
        case .fillPatch(let action):
            applyFill(regionID: action.regionID, hex: action.newHex)
            pigmentEngine?.restore(action.patch.after)
            fillLayerImage = action.patch.after
            hasUnsavedPigmentChanges = true
        case .pigmentStrokePatch(let action), .erasePatch(let action):
            paintState.strokeActions.append(action.action)
            pigmentEngine?.restore(action.patch.after)
            fillLayerImage = action.patch.after
            hasUnsavedPigmentChanges = true
        case .clear(_, _, _, let clearedImage):
            paintState.regionFills.removeAll()
            paintState.strokeActions.removeAll()
            pigmentEngine?.restore(clearedImage)
            fillLayerImage = clearedImage
            hasUnsavedPigmentChanges = true
        }
    }

    private func renderStrokeActions(on baseImage: UIImage, geometry: TemplateGeometry) -> UIImage {
        guard !paintState.strokeActions.isEmpty else { return baseImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        return renderer.image { context in
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
            let cgContext = context.cgContext
            for action in paintState.strokeActions {
                draw(action: action, geometry: geometry, in: cgContext)
            }
        }
    }

    private func draw(action: StrokeAction, geometry: TemplateGeometry, in context: CGContext) {
        BrushRenderers.draw(action: action, geometry: geometry, in: context)
    }

    private static func makePalettes() -> [ColorPalette] {
        [essentialsPalette] + ColorPalette.loadAll()
    }

    private static let essentialsPalette = ColorPalette(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000100")!,
        name: "Essentials",
        swatches: [
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000100")!, name: "Signature Pink", hex: SableTheme.progressPinkHex),
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000101")!, name: "Crimson", hex: SableTheme.crimsonHex),
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000102")!, name: "Calm Teal", hex: MoodCategory.calm.accentHex),
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000103")!, name: "Playful Orange", hex: MoodCategory.playful.accentHex),
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000104")!, name: "Wild Amber", hex: MoodCategory.wild.accentHex),
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000105")!, name: "Dreamy Violet", hex: MoodCategory.dreamy.accentHex),
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000106")!, name: "Noir Blue", hex: MoodCategory.noir.accentHex),
            ColorSwatch(id: UUID(uuidString: "22222222-0000-0000-0000-000000000107")!, name: "Ink", hex: "#111111")
        ]
    )
}

private enum CanvasEditAction {
    case fillPatch(FillPatchAction)
    case pigmentStrokePatch(StrokePatchAction)
    case erasePatch(StrokePatchAction)
    case clear(previousFills: [String: String], previousStrokes: [StrokeAction], previousImage: UIImage, clearedImage: UIImage)
}

private struct FillPatchAction {
    let regionID: String
    let previousHex: String?
    let newHex: String
    let patch: PigmentPatch
}

private struct StrokePatchAction {
    let action: StrokeAction
    let patch: PigmentPatch
}
