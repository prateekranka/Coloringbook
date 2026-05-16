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
    @ObservationIgnored private var paintState = ProjectPaintState()
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var lastSavedRegionFills: [String: String] = [:]
    @ObservationIgnored private var lastSavedStrokeActions: [StrokeAction] = []
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
        !paintState.regionFills.isEmpty || !paintState.strokeActions.isEmpty
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
        guard previousHex != selectedColorHex else { return false }

        let action = FillAction(
            regionID: region.id,
            previousHex: previousHex,
            newHex: selectedColorHex
        )
        undoStack.append(.fill(action))
        redoStack.removeAll()
        syncUndoRedoState()

        applyFill(regionID: region.id, hex: selectedColorHex)
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
        guard !paintState.regionFills.isEmpty || !paintState.strokeActions.isEmpty else { return }
        paintState.regionFills.removeAll()
        paintState.strokeActions.removeAll()
        clearUndoHistory()
        await refreshArtworkAfterEdit()
        HapticService.shared.impact(.medium)
    }

    func save() {
        guard var mutableProject = project else { return }
        autosaveTask?.cancel()
        paintState.canvasState.selectedTool = selectedTool
        paintState.canvasState.coloringMode = coloringMode
        storeViewportState()
        saveState = .saving
        storageService.savePaintState(paintState, for: mutableProject)
        storageService.save(
            project: &mutableProject,
            drawing: PKDrawing(),
            fillLayer: fillLayerImage,
            templateImage: lineArtImage
        )
        project = mutableProject
        ProjectThumbnailCache.shared.invalidate(id: mutableProject.id)
        lastSavedRegionFills = paintState.regionFills
        lastSavedStrokeActions = paintState.strokeActions
        saveState = .saved
    }

    func saveNow() {
        guard saveState == .dirty else { return }
        save()
    }

    @discardableResult
    func drawStroke(canvasPoints: [CGPoint], canvasSize: CGSize) async -> Bool {
        guard let geometry, !canvasPoints.isEmpty else { return false }

        if selectedTool == .fillBucket, let firstPoint = canvasPoints.first {
            return await fill(atCanvasPoint: firstPoint, canvasSize: canvasSize)
        }

        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        ).inverted()
        let documentPoints = canvasPoints.map { $0.applying(transform) }
        let clippedRegionID = coloringMode == .clean
            ? documentPoints.first.flatMap { geometry.region(at: $0)?.id }
            : nil

        if coloringMode == .clean, clippedRegionID == nil {
            return false
        }

        let action = StrokeAction(
            tool: selectedTool,
            colorHex: selectedColorHex,
            points: documentPoints.map { CodablePoint(x: $0.x, y: $0.y) },
            clippedRegionID: clippedRegionID,
            size: selectedToolSettings.size,
            opacity: selectedToolSettings.opacity
        )

        paintState.strokeActions.append(action)
        undoStack.append(.stroke(action))
        redoStack.removeAll()
        syncUndoRedoState()
        await refreshArtworkAfterEdit()
        HapticService.shared.impact(.light)
        return true
    }

    private func resolveSeed() async -> (project: Project, template: Template)? {
        if let initialProject, let initialTemplate {
            return (initialProject, initialTemplate)
        }
        return await repository.resolveProject(projectId: projectId, templateId: templateId)
    }

    private func renderImages(geometry: TemplateGeometry) async {
        let fills = paintState.regionFills
        let size = geometry.viewBox.size
        let lineArtURL = template?.lineArtURL

        async let lineArtTask = renderLineArtImage(
            geometry: geometry,
            lineArtURL: lineArtURL,
            strokeWidthPixels: CGFloat(RenderTuningStore.defaultCanvasStrokeWidth)
        )

        async let fillLayerTask = Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, size: size)
        }.value

        let (lineArt, renderedFillLayer) = await (lineArtTask, fillLayerTask)
        lineArtImage = lineArt
        let baseLayer = fills.isEmpty && paintState.strokeActions.isEmpty
            ? project.flatMap { storageService.loadFillLayer(for: $0) } ?? renderedFillLayer
            : renderedFillLayer
        fillLayerImage = renderStrokeActions(on: baseLayer, geometry: geometry)
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
        await renderCurrentFillLayer()
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
        guard let geometry else { return }
        let fills = paintState.regionFills
        let size = geometry.viewBox.size
        let renderedFillLayer = await Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderFillLayer(
                geometry: geometry,
                fills: fills,
                size: size
            )
        }.value
        fillLayerImage = renderStrokeActions(on: renderedFillLayer, geometry: geometry)
    }

    private func updateSaveStateForCurrentPaint() {
        guard saveState != .saving else { return }
        saveState = paintState.regionFills == lastSavedRegionFills
            && paintState.strokeActions == lastSavedStrokeActions ? .saved : .dirty
        if saveState == .dirty {
            scheduleAutosave()
        }
    }

    private func markCanvasStateDirty() {
        guard hasLoaded else { return }
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
        case .fill(let fillAction):
            applyFill(regionID: fillAction.regionID, hex: fillAction.previousHex)
        case .stroke(let strokeAction):
            paintState.strokeActions.removeAll { $0.id == strokeAction.id }
        case .clear(let previousFills, let previousStrokes):
            paintState.regionFills = previousFills
            paintState.strokeActions = previousStrokes
        }
    }

    private func applyRedo(_ action: CanvasEditAction) {
        switch action {
        case .fill(let fillAction):
            applyFill(regionID: fillAction.regionID, hex: fillAction.newHex)
        case .stroke(let strokeAction):
            paintState.strokeActions.append(strokeAction)
        case .clear:
            paintState.regionFills.removeAll()
            paintState.strokeActions.removeAll()
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
        guard action.points.count > 1 else { return }
        context.saveGState()
        if let regionID = action.clippedRegionID,
           let region = geometry.regions.first(where: { $0.id == regionID }) {
            context.addPath(region.path)
            context.clip(using: region.fillRule == .evenOdd ? .evenOdd : .winding)
        }

        if action.tool == .eraser {
            context.setBlendMode(.clear)
            context.setStrokeColor(UIColor.clear.cgColor)
        } else {
            context.setBlendMode(action.tool == .marker ? .multiply : .normal)
            context.setStrokeColor(UIColor(Color(hex: action.colorHex)).withAlphaComponent(action.opacity).cgColor)
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(action.size)
        context.beginPath()
        context.move(to: action.points[0].cgPoint)
        for point in action.points.dropFirst() {
            context.addLine(to: point.cgPoint)
        }
        context.strokePath()
        context.restoreGState()
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

private struct FillAction {
    let regionID: String
    let previousHex: String?
    let newHex: String
}

private enum CanvasEditAction {
    case fill(FillAction)
    case stroke(StrokeAction)
    case clear(previousFills: [String: String], previousStrokes: [StrokeAction])
}
