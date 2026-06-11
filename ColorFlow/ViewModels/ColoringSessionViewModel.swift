import CoreGraphics
import Observation
import os.signpost
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
    var freehandExternalRevision = 0
    var selectedColorHex = SableTheme.progressPinkHex
    var selectedPaletteID = ColoringSessionViewModel.essentialsPalette.id
    var selectedTool: ToolType = .watercolor
    var selectedToolSettings = ToolType.watercolor.defaultSettings
    var coloringMode: CanvasColoringMode = .clean
    var fingerPaints = false
    var recentColorHexes: [String] = [SableTheme.progressPinkHex]
    var canvasDocumentSize = CGSize(width: 800, height: 800)
    var viewport = CanvasViewport()
    var saveState: SaveState = .saved
    var canUndo = false
    var canRedo = false
    let canvasDiagnostics = CanvasDebugDiagnostics()

    @ObservationIgnored private let repository: any ColoringFlowRepositoryProtocol
    @ObservationIgnored private let storageService: StorageService
    @ObservationIgnored private let initialProject: Project?
    @ObservationIgnored private let initialTemplate: Template?
    @ObservationIgnored private let projectId: UUID?
    @ObservationIgnored private let templateId: UUID?
    @ObservationIgnored private let renderTargetLongestSide: CGFloat
    @ObservationIgnored private var geometry: TemplateGeometry?
    @ObservationIgnored private var pigmentEngine: RegionPigmentEngine?
    @ObservationIgnored var paintState = ProjectPaintState()
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var lastSavedRegionFills: [String: String] = [:]
    @ObservationIgnored private var lastSavedStrokeActions: [StrokeAction] = []
    @ObservationIgnored private var hasUnsavedPigmentChanges = false
    @ObservationIgnored private var activePigmentStroke: ActivePigmentStroke?
    @ObservationIgnored private var undoStack: [CanvasEditAction] = []
    @ObservationIgnored private var redoStack: [CanvasEditAction] = []
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    @ObservationIgnored private var isLiveDrawing = false
    @ObservationIgnored private var lastCommitTask: Task<Void, Never>?
    @ObservationIgnored private var pendingPigmentCommitCount = 0
    @ObservationIgnored private var commitGeneration = 0
    @ObservationIgnored private var lastRecordedCanvasInputAtByKey: [String: TimeInterval] = [:]
    #if DEBUG
    @ObservationIgnored private var pixelCompareStrokeCounter = 0
    #endif
    @ObservationIgnored private var toolSettingsCache: [ToolType: ToolSettings] = Dictionary(
        uniqueKeysWithValues: ToolType.allCases.map { ($0, $0.defaultSettings) }
    )

    let fallbackTitle: String
    let palettes: [ColorPalette]

    private struct ActivePigmentStroke {
        let beforeImage: UIImage
        let tool: ToolType
        let colorHex: String
        var regionID: String?
        let size: CGFloat
        let opacity: Double
        let seed: UInt64
        let freehandDrawingToFlatten: PKDrawing?
        var latestPatch: PigmentPatch?
        var latestDocumentSamples: [StrokeSample] = []
    }

    private struct PendingPigmentCommit {
        let projectID: UUID
        let generation: Int
        let geometry: TemplateGeometry
        let bitmapSize: CGSize
        let canvasSize: CGSize
        let action: StrokeAction
        let freehandDrawingToFlatten: PKDrawing?
        let strokeID: UUID
        let queuedAt: CFAbsoluteTime
    }

    private struct CommitSampleSimplificationProfile {
        let minimumDistance: CGFloat
        let cornerMinimumLeg: CGFloat
        let cornerCosineThreshold: CGFloat
        let rdpTolerance: CGFloat
        let maximumSamples: Int
    }

    /// Lightweight descriptor for the live-stroke preview renderer.
    /// The view reads this to draw the on-screen preview with the same
    /// pigment brush implementations used for final commit.
    struct LiveStrokePreviewDescriptor {
        let tool: ToolType
        let colorHex: String
        let size: CGFloat
        let opacity: Double
        let seed: UInt64
        let regionClip: StrokeRenderClip?
    }

    /// Returns the current live-stroke preview configuration, or nil if no
    /// stroke is in progress.  The view uses this to render the preview with
    /// the same pigment brush implementations as the final committed stroke.
    func liveStrokePreviewDescriptor(samples canvasSamples: [StrokeSample], canvasSize: CGSize) -> LiveStrokePreviewDescriptor? {
        guard let active = activePigmentStroke,
              let geometry,
              canvasSamples.count > 1 else {
            return nil
        }
        let regionClip: StrokeRenderClip?
        if let regionID = active.regionID,
           let region = geometry.regions.first(where: { $0.id == regionID }) {
            var documentToCanvas = TemplateRenderer.documentToViewTransform(
                viewBox: geometry.viewBox,
                viewSize: canvasSize
            )
            if let path = region.path.copy(using: &documentToCanvas) {
                regionClip = StrokeRenderClip(path: path, fillRule: region.fillRule)
            } else {
                regionClip = nil
            }
        } else {
            regionClip = nil
        }
        return LiveStrokePreviewDescriptor(
            tool: active.tool,
            colorHex: active.colorHex,
            size: active.size,
            opacity: active.opacity,
            seed: active.seed,
            regionClip: regionClip
        )
    }

    /// The seed for the current live stroke, or nil. Used by the preview
    /// renderer so it produces identical random variation as the final commit.
    var liveStrokeSeed: UInt64? {
        activePigmentStroke?.seed
    }

    #if DEBUG
    var debugTemplateGeometry: TemplateGeometry? {
        geometry
    }

    var debugPigmentLayerImage: UIImage? {
        pigmentEngine?.image
    }

    var debugPigmentBitmapSize: CGSize? {
        pigmentEngine?.bitmap.size
    }
    #endif

    #if DEBUG
    static var debugRenderTargetLongestSideOverride: CGFloat?
    #endif

    init(
        project: Project,
        template: Template,
        storageService: StorageService = StorageService(),
        renderTargetLongestSide: CGFloat? = nil
    ) {
        self.initialProject = project
        self.initialTemplate = template
        self.projectId = project.id
        self.templateId = template.id
        self.renderTargetLongestSide = renderTargetLongestSide ?? Self.defaultRenderTargetLongestSide
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
        storageService: StorageService = StorageService(),
        renderTargetLongestSide: CGFloat? = nil
    ) {
        self.initialProject = nil
        self.initialTemplate = nil
        self.projectId = projectId
        self.templateId = templateId
        self.renderTargetLongestSide = renderTargetLongestSide ?? Self.defaultRenderTargetLongestSide
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

    var hasPendingPigmentCommits: Bool {
        pendingPigmentCommitCount > 0
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
        canvasDiagnostics.record(.lifecycle, "selected color \(hex)")
    }

    func selectTool(_ tool: ToolType) {
        selectedTool = tool
        selectedToolSettings = toolSettingsCache[tool] ?? tool.defaultSettings
        paintState.canvasState.selectedTool = tool
        markCanvasStateDirty()
        canvasDiagnostics.record(.lifecycle, "selected tool \(tool.rawValue)")
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
        canvasDiagnostics.record(.lifecycle, "selected coloring mode \(mode.rawValue)")
    }

    func setFingerPaints(_ enabled: Bool) {
        guard fingerPaints != enabled else { return }
        fingerPaints = enabled
        paintState.fingerPaints = enabled
        markCanvasStateDirty()
        canvasDiagnostics.record(.lifecycle, "finger painting \(enabled ? "enabled" : "disabled")")
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        state = .loading
        commitGeneration += 1

        guard let seed = await resolveSeed() else {
            canvasDiagnostics.record(
                .warning,
                "load failed: project/template seed not found project=\(projectId?.uuidString ?? "nil") template=\(templateId?.uuidString ?? "nil")"
            )
            state = .failed("This coloring page could not be found.")
            return
        }

        project = seed.project
        template = seed.template

        guard let svgURL = seed.template.svgURL else {
            canvasDiagnostics.record(.warning, "load failed: missing SVG for template=\(seed.template.name)")
            state = .failed("Template file not found.")
            return
        }

        let parseResult = await Task.detached(priority: .userInitiated) {
            SVGParser.parse(url: svgURL)
        }.value

        switch parseResult {
        case .failure(let error):
            canvasDiagnostics.record(.warning, "load failed: SVG parse error \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        case .success(let parsedGeometry):
            geometry = parsedGeometry
            canvasDocumentSize = parsedGeometry.viewBox.size
            let pigmentBitmapSize = premiumPigmentBitmapSize(for: parsedGeometry.viewBox.size)
            paintState = storageService.loadPaintState(for: seed.project)
            let storedPigment = storageService.loadFillLayer(for: seed.project)
            if let storedPigment {
                pigmentEngine = RegionPigmentEngine(
                    geometry: parsedGeometry,
                    bitmapSize: pigmentBitmapSize,
                    existingImage: storedPigment
                )
            } else {
                pigmentEngine = nil
            }
            if let drawing = storageService.loadDrawing(for: seed.project) {
                freehandDrawing = drawing
                freehandExternalRevision += 1
            } else if let data = paintState.freehandDrawingData,
                      let drawing = try? PKDrawing(data: data) {
                freehandDrawing = drawing
                freehandExternalRevision += 1
            }
            selectedTool = paintState.canvasState.selectedTool
            selectedToolSettings = toolSettingsCache[selectedTool] ?? selectedTool.defaultSettings
            coloringMode = paintState.canvasState.coloringMode
            fingerPaints = paintState.fingerPaints
            // Viewport is transient: every canvas entry starts fit-to-screen.
            viewport = CanvasViewport()
            lastSavedRegionFills = paintState.regionFills
            lastSavedStrokeActions = paintState.strokeActions
            clearUndoHistory()
            saveState = .saved
            await renderImages(geometry: parsedGeometry)
            hasLoaded = true
            state = .ready
            canvasDiagnostics.record(
                .lifecycle,
                "canvas ready template=\(seed.template.name) project=\(seed.project.id.uuidString) viewBox=\(debugRect(parsedGeometry.viewBox)) regions=\(parsedGeometry.regions.count) tool=\(selectedTool.rawValue) mode=\(coloringMode.rawValue)"
            )
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
        canvasDiagnostics.record(
            .viewport,
            "viewport committed scale=\(debugNumber(viewport.scale)) offset=\(debugSize(viewport.offset))"
        )
    }

    @discardableResult
    func fill(atCanvasPoint point: CGPoint, canvasSize: CGSize) async -> Bool {
        guard let geometry else {
            canvasDiagnostics.record(
                .warning,
                "fill ignored: geometry unavailable",
                hit: canvasDebugHit(canvasPoint: point, canvasSize: canvasSize, phase: "fill", input: "tap")
            )
            return false
        }
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let documentPoint = point.applying(transform.inverted())
        let documentHitRadius = fillHitRadius(canvasSize: canvasSize, geometry: geometry)
        let hit = canvasDebugHit(canvasPoint: point, canvasSize: canvasSize, phase: "fill", input: "tap")
        canvasDiagnostics.record(.fill, "fill requested", hit: hit)
        let didFill = await fill(atDocumentPoint: documentPoint, hitRadius: documentHitRadius)
        canvasDiagnostics.record(
            didFill ? .fill : .warning,
            didFill ? "fill accepted" : "fill ignored after request",
            hit: hit
        )
        return didFill
    }

    @discardableResult
    func fill(atDocumentPoint point: CGPoint, hitRadius: CGFloat = 0) async -> Bool {
        await waitForPendingPigmentCommits()
        guard let geometry else {
            canvasDiagnostics.record(.warning, "fill ignored: geometry unavailable document=\(debugPoint(point))")
            return false
        }
        guard let region = geometry.region(near: point, radius: hitRadius) else {
            canvasDiagnostics.record(.warning, "fill ignored: no region document=\(debugPoint(point)) radius=\(debugNumber(hitRadius))")
            return false
        }

        let previousHex = paintState.regionFills[region.id]
        guard let patch = pigmentEngine?.fill(regionID: region.id, colorHex: selectedColorHex) else {
            canvasDiagnostics.record(.warning, "fill ignored: pigment patch failed region=\(region.id) document=\(debugPoint(point))")
            return false
        }
        paintState.regionFills[region.id] = selectedColorHex
        undoStack.append(.fillPatch(FillPatchAction(regionID: region.id, previousHex: previousHex, newHex: selectedColorHex, patch: patch)))
        redoStack.removeAll()
        syncUndoRedoState()
        fillLayerImage = pigmentEngine?.image
        hasUnsavedPigmentChanges = true
        refreshArtworkAfterEdit()

        HapticService.shared.impact(.light)
        canvasDiagnostics.record(.fill, "fill committed region=\(region.id) color=\(selectedColorHex)")
        return true
    }

    @discardableResult
    func sampleColor(atCanvasPoint point: CGPoint, canvasSize: CGSize) -> Bool {
        guard let geometry,
              let pigmentImage = pigmentEngine?.image else {
            canvasDiagnostics.record(.warning, "eyedropper ignored: pigment layer unavailable")
            return false
        }

        let canvasToDocument = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        ).inverted()
        let documentToBitmap = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: pigmentImage.size
        )
        let bitmapPoint = point
            .applying(canvasToDocument)
            .applying(documentToBitmap)

        guard let rgba = pigmentImage.rgbaPixel(at: bitmapPoint),
              rgba.a > 8 else {
            canvasDiagnostics.record(.warning, "eyedropper ignored: no pigment at canvas=\(debugPoint(point))")
            return false
        }

        let alpha = CGFloat(rgba.a) / 255
        let red = UInt8(Int(min(255, max(0, (CGFloat(rgba.r) / alpha).rounded()))))
        let green = UInt8(Int(min(255, max(0, (CGFloat(rgba.g) / alpha).rounded()))))
        let blue = UInt8(Int(min(255, max(0, (CGFloat(rgba.b) / alpha).rounded()))))
        let sampledHex = String(format: "#%02X%02X%02X", red, green, blue)
        selectColor(hex: sampledHex)
        canvasDiagnostics.record(.lifecycle, "eyedropper sampled \(sampledHex)")
        return true
    }

    private func fillHitRadius(canvasSize: CGSize, geometry: TemplateGeometry) -> CGFloat {
        let documentPointsPerCanvasPoint = max(
            geometry.viewBox.width / max(canvasSize.width, 1),
            geometry.viewBox.height / max(canvasSize.height, 1)
        )
        return max(6, documentPointsPerCanvasPoint * 14)
    }

    func undoLastFill() async {
        await waitForPendingPigmentCommits()
        guard let action = undoStack.popLast() else { return }
        redoStack.append(action)
        syncUndoRedoState()
        applyUndo(action)
        refreshArtworkAfterEdit()
    }

    func redoFill() async {
        await waitForPendingPigmentCommits()
        guard let action = redoStack.popLast() else { return }
        undoStack.append(action)
        syncUndoRedoState()
        applyRedo(action)
        refreshArtworkAfterEdit()
    }

    func clearArtwork() async {
        await waitForPendingPigmentCommits()
        guard hasArtwork else { return }
        commitGeneration += 1
        paintState.regionFills.removeAll()
        paintState.strokeActions.removeAll()
        freehandDrawing = PKDrawing()
        freehandExternalRevision += 1
        if let geometry {
            pigmentEngine = RegionPigmentEngine(
                geometry: geometry,
                bitmapSize: premiumPigmentBitmapSize(for: geometry.viewBox.size)
            )
            fillLayerImage = pigmentEngine?.image
        }
        clearUndoHistory()
        hasUnsavedPigmentChanges = true
        refreshArtworkAfterEdit()
        HapticService.shared.impact(.medium)
    }

    func save() {
        guard var mutableProject = project else { return }
        autosaveTask?.cancel()
        paintState.canvasState.selectedTool = selectedTool
        paintState.canvasState.coloringMode = coloringMode
        paintState.fingerPaints = fingerPaints
        paintState.freehandDrawingData = nil
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

    func saveNowAfterPendingPigmentCommits() async {
        await waitForPendingPigmentCommits()
        saveNow()
    }

    func exportImage(backgroundColor: UIColor = CanvasSnapshotRenderer.paperColor) -> UIImage? {
        guard let geometry else { return nil }
        return ExportService().compositeImage(
            lineArtImage: lineArtImage,
            pigmentLayer: pigmentEngine?.image ?? fillLayerImage,
            drawing: freehandDrawing,
            backgroundColor: backgroundColor,
            size: geometry.viewBox.size
        )
    }

    func exportImageAfterPendingPigmentCommits(backgroundColor: UIColor = CanvasSnapshotRenderer.paperColor) async -> UIImage? {
        await waitForPendingPigmentCommits()
        return exportImage(backgroundColor: backgroundColor)
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
        guard !canvasSamples.isEmpty else { return false }

        if selectedTool == .fillBucket, let firstPoint = canvasSamples.first?.cgPoint {
            return await fill(atCanvasPoint: firstPoint, canvasSize: canvasSize)
        }

        guard beginLiveStroke(samples: [canvasSamples[0]], canvasSize: canvasSize) else {
            return false
        }
        _ = updateLiveStroke(samples: canvasSamples, canvasSize: canvasSize)
        let didEnd = endLiveStroke(samples: canvasSamples, canvasSize: canvasSize)
        await waitForPendingPigmentCommits()
        return didEnd
    }

    @discardableResult
    func beginLiveStroke(samples canvasSamples: [StrokeSample], canvasSize: CGSize) -> Bool {
        guard let geometry,
              selectedTool != .fillBucket,
              let pigmentEngine,
              let firstSample = canvasSamples.first else {
            #if DEBUG
            AppLog.trace(AppLog.canvas, "beginLiveStroke failed: geometry=\(geometry != nil), tool=\(selectedTool.rawValue), engine=\(pigmentEngine != nil), samples=\(canvasSamples.count)")
            #endif
            canvasDiagnostics.record(
                .warning,
                "stroke begin rejected geometry=\(geometry != nil) tool=\(selectedTool.rawValue) engine=\(pigmentEngine != nil) samples=\(canvasSamples.count)",
                hit: canvasDebugHit(
                    canvasPoint: canvasSamples.first?.cgPoint,
                    canvasSize: canvasSize,
                    phase: "strokeBegan",
                    input: "sample",
                    sampleCount: canvasSamples.count
                )
            )
            return false
        }

        let documentSamples = documentSamples(from: canvasSamples, canvasSize: canvasSize, geometry: geometry)
        let firstDocumentPoint = documentSamples.first?.cgPoint ?? firstSample.cgPoint
        let regionID: String?
        if coloringMode == .clean {
            if let region = cleanStrokeRegion(
                for: documentSamples,
                firstDocumentPoint: firstDocumentPoint,
                tool: selectedTool,
                geometry: geometry
            ) {
                regionID = region.id
            } else if selectedTool == .eraser {
                regionID = nil
            } else {
                activePigmentStroke = nil
                #if DEBUG
                AppLog.trace(AppLog.canvas, "beginLiveStroke no region at point")
                #endif
                canvasDiagnostics.record(
                    .warning,
                    "stroke begin rejected: no clean-mode region",
                    hit: canvasDebugHit(
                        canvasPoint: firstSample.cgPoint,
                        canvasSize: canvasSize,
                        phase: "strokeBegan",
                        input: "sample",
                        sampleCount: canvasSamples.count,
                        force: firstSample.force,
                        altitude: firstSample.altitude,
                        azimuth: firstSample.azimuth
                    )
                )
                return false
            }
        } else {
            regionID = nil
        }

        let opacity = selectedTool == .eraser ? 1 : selectedToolSettings.opacity
        let colorHex = selectedTool == .eraser ? "#000000" : selectedColorHex
        let freehandDrawingToFlatten = selectedTool == .eraser
            && coloringMode == .clean
            && hasVisibleFreehandDrawing(freehandDrawing)
            ? freehandDrawing
            : nil
        activePigmentStroke = ActivePigmentStroke(
            beforeImage: pigmentEngine.image,
            tool: selectedTool,
            colorHex: colorHex,
            regionID: regionID,
            size: selectedToolSettings.size,
            opacity: opacity,
            seed: strokeSeed(
                tool: selectedTool,
                colorHex: colorHex,
                samples: documentSamples,
                size: selectedToolSettings.size,
                opacity: opacity
            ),
            freehandDrawingToFlatten: freehandDrawingToFlatten,
            latestDocumentSamples: documentSamples
        )
        isLiveDrawing = true
        let metrics = canvasScaleMetrics(canvasSize: canvasSize, toolSize: selectedToolSettings.size)
        canvasDiagnostics.record(
            .scale,
            "stroke scale toolSize=\(debugNumber(selectedToolSettings.size)) docToCanvas=\(debugNumber(metrics.documentToCanvasScale)) docToBitmap=\(debugNumber(metrics.documentToBitmapScale)) previewSize=\(debugNumber(metrics.previewStrokeSize)) committedSize=\(debugNumber(metrics.committedBitmapStrokeSize)) bitmapSize=\(debugSize(metrics.bitmapSize)) canvasDocSize=\(debugSize(metrics.canvasDocumentSize)) viewportScale=\(debugNumber(viewport.scale))",
            hit: canvasDebugHit(
                canvasPoint: firstSample.cgPoint,
                canvasSize: canvasSize,
                phase: "strokeBegan",
                input: "sample",
                sampleCount: canvasSamples.count,
                force: firstSample.force,
                altitude: firstSample.altitude,
                azimuth: firstSample.azimuth,
                documentToCanvasScale: metrics.documentToCanvasScale,
                documentToBitmapScale: metrics.documentToBitmapScale,
                previewStrokeSize: metrics.previewStrokeSize,
                committedStrokeSize: metrics.committedBitmapStrokeSize,
                bitmapPixelSize: metrics.bitmapSize
            )
        )
        canvasDiagnostics.record(
            .stroke,
            "stroke began region=\(regionID ?? "free") seed=\(activePigmentStroke?.seed ?? 0)",
            hit: canvasDebugHit(
                canvasPoint: firstSample.cgPoint,
                canvasSize: canvasSize,
                phase: "strokeBegan",
                input: "sample",
                sampleCount: canvasSamples.count,
                force: firstSample.force,
                altitude: firstSample.altitude,
                azimuth: firstSample.azimuth
            )
        )

        if canvasSamples.count > 1 {
            return updateLiveStroke(samples: canvasSamples, canvasSize: canvasSize)
        }
        return true
    }

    @discardableResult
    func updateLiveStroke(samples canvasSamples: [StrokeSample], canvasSize: CGSize) -> Bool {
        guard var activeStroke = activePigmentStroke,
              let geometry else {
            canvasDiagnostics.record(
                .warning,
                "stroke update ignored active=\(activePigmentStroke != nil) geometry=\(geometry != nil) samples=\(canvasSamples.count)",
                hit: canvasDebugHit(
                    canvasPoint: canvasSamples.last?.cgPoint,
                    canvasSize: canvasSize,
                    phase: "strokeMoved",
                    input: "sample",
                    sampleCount: canvasSamples.count
                ),
                throttleKey: "stroke.update.ignored",
                minimumInterval: 0.4
            )
            return false
        }

        let startIndex = max(0, activeStroke.latestDocumentSamples.count - 1)
        guard startIndex < canvasSamples.count else { return true }
        let nextDocumentSamples = documentSamples(
            from: Array(canvasSamples[startIndex...]),
            canvasSize: canvasSize,
            geometry: geometry
        )
        if activeStroke.latestDocumentSamples.isEmpty {
            activeStroke.latestDocumentSamples = nextDocumentSamples
        } else {
            activeStroke.latestDocumentSamples.append(contentsOf: nextDocumentSamples.dropFirst())
        }

        if coloringMode == .clean,
           activeStroke.tool == .eraser,
           activeStroke.regionID == nil,
           let region = cleanStrokeRegion(for: nextDocumentSamples, tool: activeStroke.tool, geometry: geometry) {
            activeStroke.regionID = region.id
        }

        guard activeStroke.latestDocumentSamples.count > 1 else {
            activePigmentStroke = activeStroke
            return true
        }

        activePigmentStroke = activeStroke
        CanvasPerformanceProbe.count(.cleanLiveStrokeUpdate)
        if let lastSample = canvasSamples.last {
            canvasDiagnostics.record(
                .stroke,
                "stroke updated region=\(activeStroke.regionID ?? "free") samples=\(activeStroke.latestDocumentSamples.count)",
                hit: canvasDebugHit(
                    canvasPoint: lastSample.cgPoint,
                    canvasSize: canvasSize,
                    phase: "strokeMoved",
                    input: "sample",
                    sampleCount: canvasSamples.count,
                    force: lastSample.force,
                    altitude: lastSample.altitude,
                    azimuth: lastSample.azimuth
                ),
                throttleKey: "stroke.update",
                minimumInterval: 0.18
            )
        }
        return true
    }

    @discardableResult
    func endLiveStroke(samples canvasSamples: [StrokeSample], canvasSize: CGSize) -> Bool {
        if activePigmentStroke == nil {
            guard beginLiveStroke(samples: canvasSamples, canvasSize: canvasSize) else { return false }
        }

        _ = updateLiveStroke(samples: canvasSamples, canvasSize: canvasSize)
        guard var activeStroke = activePigmentStroke,
              let pigmentEngine,
              let geometry,
              let projectID = project?.id,
              activeStroke.latestDocumentSamples.count > 1 else {
            #if DEBUG
            AppLog.trace(AppLog.canvas, "endLiveStroke aborted: samples=\(activePigmentStroke?.latestDocumentSamples.count ?? 0)")
            #endif
            canvasDiagnostics.record(
                .warning,
                "stroke end aborted active=\(activePigmentStroke != nil) engine=\(pigmentEngine != nil) samples=\(activePigmentStroke?.latestDocumentSamples.count ?? 0)",
                hit: canvasDebugHit(
                    canvasPoint: canvasSamples.last?.cgPoint,
                    canvasSize: canvasSize,
                    phase: "strokeEnded",
                    input: "sample",
                    sampleCount: canvasSamples.count
                )
            )
            activePigmentStroke = nil
            isLiveDrawing = false
            return false
        }

        if coloringMode == .clean,
           activeStroke.tool == .eraser,
           activeStroke.regionID == nil {
            activeStroke.regionID = cleanStrokeRegion(
                for: activeStroke.latestDocumentSamples,
                tool: activeStroke.tool,
                geometry: geometry
            )?.id
        }

        if coloringMode == .clean,
           activeStroke.tool == .eraser,
           activeStroke.regionID == nil {
            canvasDiagnostics.record(
                .warning,
                "stroke end aborted: clean eraser did not enter a region",
                hit: canvasDebugHit(
                    canvasPoint: canvasSamples.last?.cgPoint,
                    canvasSize: canvasSize,
                    phase: "strokeEnded",
                    input: "sample",
                    sampleCount: canvasSamples.count
                )
            )
            activePigmentStroke = nil
            isLiveDrawing = false
            return false
        }

        let compactDocumentSamples = simplifyCommitSamples(
            activeStroke.latestDocumentSamples,
            tool: activeStroke.tool,
            size: activeStroke.size
        )
        let compactDocumentPoints = compactDocumentSamples.map(\.cgPoint)
        let action = StrokeAction(
            tool: activeStroke.tool,
            colorHex: activeStroke.colorHex,
            points: compactDocumentPoints.map { CodablePoint(x: $0.x, y: $0.y) },
            samples: compactDocumentSamples,
            highFidelitySamples: activeStroke.latestDocumentSamples,
            seed: activeStroke.seed,
            clippedRegionID: activeStroke.regionID,
            size: activeStroke.size,
            opacity: activeStroke.opacity
        )
        let pendingCommit = PendingPigmentCommit(
            projectID: projectID,
            generation: commitGeneration,
            geometry: geometry,
            bitmapSize: pigmentEngine.bitmap.size,
            canvasSize: canvasSize,
            action: action,
            freehandDrawingToFlatten: activeStroke.freehandDrawingToFlatten,
            strokeID: action.id,
            queuedAt: CFAbsoluteTimeGetCurrent()
        )

        activePigmentStroke = nil
        isLiveDrawing = false
        pendingPigmentCommitCount += 1
        canvasDiagnostics.record(
            .stroke,
            "stroke queued tool=\(action.tool.rawValue) region=\(action.clippedRegionID ?? "free") samples=\(compactDocumentSamples.count) rawSamples=\(activeStroke.latestDocumentSamples.count) renderSamples=\(action.renderSamples.count) strokeID=\(action.id.uuidString)",
            hit: canvasDebugHit(
                canvasPoint: canvasSamples.last?.cgPoint,
                canvasSize: canvasSize,
                phase: "strokeEnded",
                input: "sample",
                sampleCount: canvasSamples.count
            )
        )
        enqueuePigmentCommit(pendingCommit)
        return true
    }

    private func simplifyCommitSamples(
        _ samples: [StrokeSample],
        tool: ToolType,
        size: CGFloat
    ) -> [StrokeSample] {
        guard samples.count > 2 else { return samples }

        let profile = commitSampleSimplificationProfile(tool: tool, size: size)
        var filtered: [StrokeSample] = [samples[0]]

        for index in 1..<(samples.count - 1) {
            let sample = samples[index]
            guard let previousKept = filtered.last else { continue }
            let distanceFromKept = distance(previousKept.cgPoint, sample.cgPoint)
            if distanceFromKept >= profile.minimumDistance
                || isCornerSample(
                    previous: samples[index - 1],
                    current: sample,
                    next: samples[index + 1],
                    minimumLeg: profile.cornerMinimumLeg,
                    cosineThreshold: profile.cornerCosineThreshold
                ) {
                appendSampleIfDistinct(sample, to: &filtered)
            }
        }

        appendSampleIfDistinct(samples[samples.count - 1], to: &filtered)
        guard filtered.count > profile.maximumSamples else { return filtered }

        var tolerance = profile.rdpTolerance
        var simplified = filtered
        while simplified.count > profile.maximumSamples, tolerance <= profile.rdpTolerance * 16 {
            simplified = ramerDouglasPeucker(samples: filtered, tolerance: tolerance)
            tolerance *= 1.35
        }
        return simplified
    }

    private func commitSampleSimplificationProfile(
        tool: ToolType,
        size: CGFloat
    ) -> CommitSampleSimplificationProfile {
        switch tool {
        case .crayon:
            return CommitSampleSimplificationProfile(
                minimumDistance: max(1.8, size * 0.08),
                cornerMinimumLeg: max(2.0, size * 0.10),
                cornerCosineThreshold: 0.88,
                rdpTolerance: max(0.9, size * 0.045),
                maximumSamples: 800
            )
        case .watercolor:
            return CommitSampleSimplificationProfile(
                minimumDistance: max(2.4, size * 0.10),
                cornerMinimumLeg: max(2.8, size * 0.12),
                cornerCosineThreshold: 0.84,
                rdpTolerance: max(1.35, size * 0.06),
                maximumSamples: 650
            )
        case .marker:
            return CommitSampleSimplificationProfile(
                minimumDistance: max(2.0, size * 0.075),
                cornerMinimumLeg: max(2.2, size * 0.10),
                cornerCosineThreshold: 0.86,
                rdpTolerance: max(1.0, size * 0.045),
                maximumSamples: 700
            )
        case .eraser:
            return CommitSampleSimplificationProfile(
                minimumDistance: max(2.3, size * 0.08),
                cornerMinimumLeg: max(2.5, size * 0.10),
                cornerCosineThreshold: 0.86,
                rdpTolerance: max(1.1, size * 0.05),
                maximumSamples: 550
            )
        case .fillBucket:
            return CommitSampleSimplificationProfile(
                minimumDistance: max(1.8, size * 0.07),
                cornerMinimumLeg: max(2.0, size * 0.09),
                cornerCosineThreshold: 0.88,
                rdpTolerance: max(0.9, size * 0.04),
                maximumSamples: 800
            )
        }
    }

    private func isCornerSample(
        previous: StrokeSample,
        current: StrokeSample,
        next: StrokeSample,
        minimumLeg: CGFloat,
        cosineThreshold: CGFloat
    ) -> Bool {
        let a = previous.cgPoint
        let b = current.cgPoint
        let c = next.cgPoint
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let bc = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let abLength = hypot(ab.dx, ab.dy)
        let bcLength = hypot(bc.dx, bc.dy)
        guard abLength >= minimumLeg, bcLength >= minimumLeg else { return false }
        let cosine = (ab.dx * bc.dx + ab.dy * bc.dy) / (abLength * bcLength)
        return cosine < cosineThreshold
    }

    private func ramerDouglasPeucker(samples: [StrokeSample], tolerance: CGFloat) -> [StrokeSample] {
        guard samples.count > 2 else { return samples }

        let points = samples.map(\.cgPoint)
        var keep = Set([0, samples.count - 1])
        var stack = [(start: 0, end: samples.count - 1)]

        while let segment = stack.popLast() {
            guard segment.end > segment.start + 1 else { continue }
            var farthestIndex: Int?
            var farthestDistance: CGFloat = 0

            for index in (segment.start + 1)..<segment.end {
                let sampleDistance = perpendicularDistance(
                    points[index],
                    from: points[segment.start],
                    to: points[segment.end]
                )
                if sampleDistance > farthestDistance {
                    farthestDistance = sampleDistance
                    farthestIndex = index
                }
            }

            guard farthestDistance > tolerance, let split = farthestIndex else { continue }
            keep.insert(split)
            stack.append((segment.start, split))
            stack.append((split, segment.end))
        }

        return keep.sorted().map { samples[$0] }
    }

    private func perpendicularDistance(_ point: CGPoint, from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(point, start) }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(point, projection)
    }

    private func appendSampleIfDistinct(_ sample: StrokeSample, to samples: inout [StrokeSample]) {
        guard samples.last?.cgPoint != sample.cgPoint else { return }
        samples.append(sample)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func cleanStrokeRegion(
        for documentSamples: [StrokeSample],
        firstDocumentPoint: CGPoint? = nil,
        tool: ToolType,
        geometry: TemplateGeometry
    ) -> RegionGeometry? {
        guard tool == .eraser else {
            return (firstDocumentPoint ?? documentSamples.first?.cgPoint).flatMap { geometry.region(at: $0) }
        }
        for sample in documentSamples {
            if let region = geometry.region(at: sample.cgPoint) {
                return region
            }
        }
        if let firstDocumentPoint {
            return geometry.region(at: firstDocumentPoint)
        }
        return nil
    }

    func waitForPendingPigmentCommits() async {
        await lastCommitTask?.value
    }

    private func enqueuePigmentCommit(_ commit: PendingPigmentCommit) {
        let previous = lastCommitTask
        lastCommitTask = Task(priority: .userInitiated) { [weak self] in
            await previous?.value

            let queueWaitMs = Int((CFAbsoluteTimeGetCurrent() - commit.queuedAt) * 1000)
            guard let base = await MainActor.run(body: { () -> UIImage? in
                guard let self,
                      self.project?.id == commit.projectID,
                      self.commitGeneration == commit.generation else {
                    return nil
                }
                return self.pigmentEngine?.image
            }) else {
                await self?.finishCommitWithoutApplying(commit, reason: "stale or missing base")
                return
            }

            let renderStart = CFAbsoluteTimeGetCurrent()
            let result = await Task.detached(priority: .userInitiated) {
                let renderBase = Self.pigmentImageByFlatteningFreehandDrawing(
                    commit.freehandDrawingToFlatten,
                    over: base,
                    canvasSize: commit.canvasSize,
                    bitmapSize: commit.bitmapSize
                )
                let scratch = RegionPigmentEngine(
                    geometry: commit.geometry,
                    bitmapSize: commit.bitmapSize,
                    existingImage: renderBase
                )
                guard let renderedPatch = scratch.renderStroke(
                    tool: commit.action.tool,
                    colorHex: commit.action.colorHex,
                    points: commit.action.renderSamples.map(\.cgPoint),
                    regionID: commit.action.clippedRegionID,
                    size: CGFloat(commit.action.size),
                    opacity: commit.action.opacity,
                    seed: commit.action.seed
                ) else {
                    return nil as (patch: PigmentPatch, image: UIImage, base: UIImage)?
                }
                return (patch: renderedPatch, image: scratch.image, base: renderBase)
            }.value
            let renderMs = Int((CFAbsoluteTimeGetCurrent() - renderStart) * 1000)

            guard let result else {
                await self?.finishCommitWithoutApplying(commit, reason: "render failed", queueWaitMs: queueWaitMs, renderMs: renderMs)
                return
            }

            await MainActor.run {
                    self?.applyPigmentCommit(
                        commit,
                        base: result.base,
                        renderedPatch: result.patch,
                        resultImage: result.image,
                        queueWaitMs: queueWaitMs,
                    renderMs: renderMs
                )
            }
        }
    }

    private func applyPigmentCommit(
        _ commit: PendingPigmentCommit,
        base: UIImage,
        renderedPatch: PigmentPatch,
        resultImage: UIImage,
        queueWaitMs: Int,
        renderMs: Int
    ) {
        let applyStart = CFAbsoluteTimeGetCurrent()
        defer {
            completePendingPigmentCommit()
        }

        guard project?.id == commit.projectID,
              commitGeneration == commit.generation else {
            canvasDiagnostics.record(
                .warning,
                "stroke commit ignored: stale generation strokeID=\(commit.strokeID.uuidString)"
            )
            return
        }

        guard let pigmentEngine else {
            canvasDiagnostics.record(
                .warning,
                "stroke commit ignored: missing pigment engine strokeID=\(commit.strokeID.uuidString)"
            )
            return
        }

        pigmentEngine.restore(resultImage)
        let patch = PigmentPatch(rect: renderedPatch.rect, before: base, after: resultImage)
        paintState.strokeActions.append(commit.action)
        undoStack.append(
            commit.action.tool == .eraser
                ? .erasePatch(StrokePatchAction(action: commit.action, patch: patch))
                : .pigmentStrokePatch(StrokePatchAction(action: commit.action, patch: patch))
        )
        redoStack.removeAll()
        syncUndoRedoState()
        fillLayerImage = resultImage
        if let flattenedDrawing = commit.freehandDrawingToFlatten {
            clearFlattenedFreehandDrawingIfUnchanged(flattenedDrawing)
        }
        CanvasPerformanceProbe.count(.fillLayerPublish)

        #if DEBUG
        AppLog.trace(AppLog.canvas, "endLiveStroke committed: tool=\(commit.action.tool.rawValue), region=\(commit.action.clippedRegionID ?? "free"), samples=\(commit.action.renderSamples.count)")
        #endif
        canvasDiagnostics.record(
            .stroke,
            "stroke committed tool=\(commit.action.tool.rawValue) region=\(commit.action.clippedRegionID ?? "free") samples=\(commit.action.renderSamples.count) patch=\(debugRect(patch.rect)) strokeID=\(commit.strokeID.uuidString)",
            hit: canvasDebugHit(
                canvasPoint: commit.action.samples.last?.cgPoint,
                canvasSize: commit.canvasSize,
                phase: "strokeEnded",
                input: "sample",
                sampleCount: commit.action.samples.count
            )
        )
        let commitMetrics = canvasScaleMetrics(canvasSize: commit.canvasSize, toolSize: CGFloat(commit.action.size))
        let applyMs = Int((CFAbsoluteTimeGetCurrent() - applyStart) * 1000)
        let totalMs = Int((CFAbsoluteTimeGetCurrent() - commit.queuedAt) * 1000)
        canvasDiagnostics.record(
            .compare,
            "stroke compare tool=\(commit.action.tool.rawValue) previewSize=\(debugNumber(commitMetrics.previewStrokeSize)) committedBitmapSize=\(debugNumber(commitMetrics.committedBitmapStrokeSize)) effectiveCommittedSize=\(debugNumber(commitMetrics.committedBitmapStrokeSize * (commit.canvasSize.width / max(commitMetrics.bitmapSize.width, 1)) * viewport.scale)) docToCanvas=\(debugNumber(commitMetrics.documentToCanvasScale)) docToBitmap=\(debugNumber(commitMetrics.documentToBitmapScale)) viewportScale=\(debugNumber(viewport.scale)) opacity=\(debugNumber(CGFloat(commit.action.opacity))) commitRenderMs=\(renderMs) commitQueueWaitMs=\(queueWaitMs) commitApplyMs=\(applyMs) commitTotalMs=\(totalMs) strokeID=\(commit.strokeID.uuidString) tool=\(commit.action.tool.rawValue) mode=\(coloringMode.rawValue)",
            hit: canvasDebugHit(
                canvasPoint: commit.action.samples.last?.cgPoint,
                canvasSize: commit.canvasSize,
                phase: "strokeEnded",
                input: "sample",
                sampleCount: commit.action.samples.count,
                documentToCanvasScale: commitMetrics.documentToCanvasScale,
                documentToBitmapScale: commitMetrics.documentToBitmapScale,
                previewStrokeSize: commitMetrics.previewStrokeSize,
                committedStrokeSize: commitMetrics.committedBitmapStrokeSize,
                bitmapPixelSize: commitMetrics.bitmapSize
            )
        )
        #if DEBUG
        pixelCompareStrokeCounter += 1
        if ProcessInfo.processInfo.environment["GOUACHE_CANVAS_DIAGNOSTICS_PIXEL_COMPARE"] == "1",
           pixelCompareStrokeCounter % 3 == 0 {
            let action = commit.action
            let docViewBox = geometry?.viewBox ?? .zero
            let bitmapSize = pigmentEngine.bitmap.size
            Task.detached(priority: .background) { [action, counter = pixelCompareStrokeCounter, canvasDiagnostics, docViewBox, bitmapSize] in
                let cs = CFAbsoluteTimeGetCurrent()
                await Self.runPixelComparisonOffMain(action: action, docViewBox: docViewBox, bitmapSize: bitmapSize, canvasDiagnostics: canvasDiagnostics)
                let ms = Int((CFAbsoluteTimeGetCurrent() - cs) * 1000)
                await canvasDiagnostics.record(.compare, "timing pixelCompare=\(ms)ms stroke=#\(counter)")
            }
        }
        #endif
        hasUnsavedPigmentChanges = true
        refreshArtworkAfterEdit()
        HapticService.shared.impact(.light)
    }

    private func finishCommitWithoutApplying(
        _ commit: PendingPigmentCommit,
        reason: String,
        queueWaitMs: Int? = nil,
        renderMs: Int? = nil
    ) {
        canvasDiagnostics.record(
            .warning,
            "stroke commit dropped reason=\"\(reason)\" strokeID=\(commit.strokeID.uuidString) commitQueueWaitMs=\(queueWaitMs.map(String.init) ?? "nil") commitRenderMs=\(renderMs.map(String.init) ?? "nil")"
        )
        completePendingPigmentCommit()
    }

    private func completePendingPigmentCommit() {
        pendingPigmentCommitCount = max(0, pendingPigmentCommitCount - 1)
        if saveState == .dirty, !isLiveDrawing, !hasPendingPigmentCommits {
            scheduleAutosave()
        }
    }

    #if DEBUG
    private static nonisolated func runPixelComparisonOffMain(
        action: StrokeAction,
        docViewBox: CGRect,
        bitmapSize: CGSize,
        canvasDiagnostics: CanvasDebugDiagnostics
    ) async {
        let documentSamples = action.renderSamples
        guard documentSamples.count > 1 else { return }
        let seed = action.seed ?? 0
        let tool = action.tool
        let colorHex = action.colorHex
        let opacity = action.opacity
        let size = CGFloat(action.size)
        let targetSize = CGSize(width: 256, height: 256)

        let fmt1 = UIGraphicsImageRendererFormat()
        fmt1.scale = 1
        fmt1.opaque = false
        let dbs = min(bitmapSize.width / docViewBox.width, bitmapSize.height / docViewBox.height)
        let targetScale = targetSize.width / docViewBox.width
        let pointsDoc = documentSamples.map { $0.cgPoint }
        let offsetX = 32.0 - (pointsDoc.map(\.x).min() ?? 0)
        let offsetY = 32.0 - (pointsDoc.map(\.y).min() ?? 0)
        let offsetPoints = pointsDoc.map { CGPoint(x: $0.x + offsetX, y: $0.y + offsetY) }

        let previewStroke = PigmentStroke(
            tool: tool, colorHex: colorHex, opacity: opacity,
            size: Double(size * targetScale),
            points: offsetPoints.map { CGPoint(x: $0.x * targetScale, y: $0.y * targetScale) },
            regionID: nil, seed: seed
        )
        let previewImage = UIGraphicsImageRenderer(size: targetSize, format: fmt1).image { ctx in
            PigmentStrokeRenderer.render(previewStroke, in: ctx.cgContext)
        }
        let bitmapStroke = PigmentStroke(
            tool: tool, colorHex: colorHex, opacity: opacity,
            size: Double(size * dbs),
            points: offsetPoints.map { CGPoint(x: $0.x * dbs, y: $0.y * dbs) },
            regionID: nil, seed: seed + 1
        )
        let rawSz = CGSize(width: targetSize.width + 64, height: targetSize.height + 64)
        let raw = UIGraphicsImageRenderer(size: rawSz, format: fmt1).image { ctx in
            PigmentStrokeRenderer.render(bitmapStroke, in: ctx.cgContext)
        }
        let scaled = UIGraphicsImageRenderer(size: targetSize, format: fmt1).image { ctx in
            raw.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let cgA = previewImage.cgImage, let cgB = scaled.cgImage else { return }
        let w = Int(targetSize.width), h = Int(targetSize.height), bpp = 4, rb = w * bpp
        var dataA = [UInt8](repeating: 0, count: h * rb)
        var dataB = [UInt8](repeating: 0, count: h * rb)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ca = CGContext(data: &dataA, width: w, height: h, bitsPerComponent: 8, bytesPerRow: rb, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cb = CGContext(data: &dataB, width: w, height: h, bitsPerComponent: 8, bytesPerRow: rb, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ca.draw(cgA, in: CGRect(x: 0, y: 0, width: w, height: h))
        cb.draw(cgB, in: CGRect(x: 0, y: 0, width: w, height: h))
        var totalAD = 0.0, maxAD = 0.0, totalLD = 0.0, maxLD = 0.0, nz = 0
        for i in stride(from: 0, to: h * rb, by: bpp) {
            let pa = Double(dataA[i+3]) / 255.0, ba = Double(dataB[i+3]) / 255.0
            if pa < 0.001 && ba < 0.001 { continue }; nz += 1
            let ad = abs(pa - ba); totalAD += ad; if ad > maxAD { maxAD = ad }
            let pl = 0.299*Double(dataA[i])/255.0 + 0.587*Double(dataA[i+1])/255.0 + 0.114*Double(dataA[i+2])/255.0
            let bl = 0.299*Double(dataB[i])/255.0 + 0.587*Double(dataB[i+1])/255.0 + 0.114*Double(dataB[i+2])/255.0
            let ld = abs(pl - bl); totalLD += ld; if ld > maxLD { maxLD = ld }
        }
        let avgAD = nz > 0 ? totalAD / Double(nz) : 0
        let avgLD = nz > 0 ? totalLD / Double(nz) : 0
        let msg = "pixel: avgAlphaΔ=\(String(format: "%.2f", avgAD)) maxAlphaΔ=\(String(format: "%.2f", maxAD)) avgLumΔ=\(String(format: "%.2f", avgLD)) maxLumΔ=\(String(format: "%.2f", maxLD)) nonzeroPx=\(nz) targetSz=\(String(format: "%.1f", size * targetScale)) bitmapSz=\(String(format: "%.1f", size * dbs)) samples=\(documentSamples.count)"
        await canvasDiagnostics.record(.compare, msg)
    }
    #endif

    func cancelLiveStroke() {
        guard let activeStroke = activePigmentStroke else { return }
        pigmentEngine?.restore(activeStroke.beforeImage)
        fillLayerImage = activeStroke.beforeImage
        activePigmentStroke = nil
        isLiveDrawing = false
        canvasDiagnostics.record(.stroke, "stroke cancelled region=\(activeStroke.regionID ?? "free")")
    }

    func recordCanvasInput(_ input: CanvasDebugInput) {
        guard canvasDiagnostics.isEnabled else { return }
        if let throttleKey = input.throttleKey, input.minimumInterval > 0 {
            let now = Date().timeIntervalSince1970
            if let previous = lastRecordedCanvasInputAtByKey[throttleKey],
               now - previous < input.minimumInterval {
                return
            }
            lastRecordedCanvasInputAtByKey[throttleKey] = now
        }
        canvasDiagnostics.record(
            .input,
            input.message,
            hit: canvasDebugHit(input),
            throttleKey: nil,
            minimumInterval: 0
        )
    }

    private func canvasDebugHit(_ input: CanvasDebugInput) -> CanvasDebugHit? {
        canvasDebugHit(
            canvasPoint: input.canvasPoint,
            canvasSize: input.canvasSize,
            viewportPoint: input.viewportPoint,
            viewportSize: input.viewportSize,
            viewport: input.viewport,
            phase: input.phase.rawValue,
            input: input.input.rawValue,
            sampleCount: input.sampleCount,
            touchTimestamp: input.touchTimestamp,
            sequenceNumber: input.sequenceNumber,
            coalescedCount: input.coalescedCount,
            predictedCount: input.predictedCount,
            force: input.force,
            altitude: input.altitude,
            azimuth: input.azimuth,
            delta: input.delta,
            distance: input.distance,
            velocity: input.velocity,
            isPredicted: input.isPredicted
        )
    }

    private func canvasDebugHit(
        canvasPoint: CGPoint?,
        canvasSize: CGSize,
        viewportPoint: CGPoint? = nil,
        viewportSize: CGSize? = nil,
        viewport: CanvasViewport? = nil,
        phase: String,
        input: String,
        sampleCount: Int? = nil,
        touchTimestamp: TimeInterval? = nil,
        sequenceNumber: Int? = nil,
        coalescedCount: Int? = nil,
        predictedCount: Int? = nil,
        force: Double? = nil,
        altitude: Double? = nil,
        azimuth: Double? = nil,
        delta: CGSize? = nil,
        distance: CGFloat? = nil,
        velocity: CGFloat? = nil,
        isPredicted: Bool = false,
        documentToCanvasScale: CGFloat? = nil,
        documentToBitmapScale: CGFloat? = nil,
        previewStrokeSize: CGFloat? = nil,
        committedStrokeSize: CGFloat? = nil,
        bitmapPixelSize: CGSize? = nil
    ) -> CanvasDebugHit? {
        guard canvasDiagnostics.isEnabled else { return nil }

        let viewport = viewport ?? self.viewport
        let viewportSize = viewportSize ?? canvasSize
        let documentPoint: CGPoint?
        let region: RegionGeometry?
        if let geometry, let canvasPoint {
            let transform = TemplateRenderer.documentToViewTransform(
                viewBox: geometry.viewBox,
                viewSize: canvasSize
            ).inverted()
            let transformedPoint = canvasPoint.applying(transform)
            documentPoint = transformedPoint
            region = geometry.region(at: transformedPoint)
        } else {
            documentPoint = nil
            region = nil
        }

        return CanvasDebugHit(
            input: input,
            phase: phase,
            viewportPoint: viewportPoint,
            canvasPoint: canvasPoint,
            documentPoint: documentPoint,
            regionID: region?.id,
            regionBounds: region?.bounds,
            tool: selectedTool,
            mode: coloringMode,
            colorHex: selectedTool == .eraser ? "#000000" : selectedColorHex,
            sampleCount: sampleCount,
            touchTimestamp: touchTimestamp,
            sequenceNumber: sequenceNumber,
            coalescedCount: coalescedCount,
            predictedCount: predictedCount,
            force: force,
            altitude: altitude,
            azimuth: azimuth,
            delta: delta,
            distance: distance,
            velocity: velocity,
            isPredicted: isPredicted,
            canvasSize: canvasSize,
            viewportSize: viewportSize,
            viewportScale: viewport.scale,
            viewportOffset: viewport.offset,
            documentToCanvasScale: documentToCanvasScale,
            documentToBitmapScale: documentToBitmapScale,
            previewStrokeSize: previewStrokeSize,
            committedStrokeSize: committedStrokeSize,
            bitmapPixelSize: bitmapPixelSize
        )
    }

    private func documentSamples(
        from canvasSamples: [StrokeSample],
        canvasSize: CGSize,
        geometry: TemplateGeometry
    ) -> [StrokeSample] {
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        ).inverted()
        return canvasSamples.map { sample in
            StrokeSample(
                point: sample.cgPoint.applying(transform),
                timestamp: sample.timestamp,
                force: sample.force,
                altitude: sample.altitude,
                azimuth: sample.azimuth,
                isPredicted: sample.isPredicted
            )
        }
    }

    private var documentToCanvasScale: CGFloat {
        guard let geometry else { return 1 }
        return min(canvasDocumentSize.width > 0 ? canvasDocumentSize.width / geometry.viewBox.width : 1,
                    canvasDocumentSize.height > 0 ? canvasDocumentSize.height / geometry.viewBox.height : 1)
    }

    private var documentToBitmapScale: CGFloat {
        guard let pigmentEngine else { return 1 }
        return min(pigmentEngine.bitmap.size.width / max(geometry?.viewBox.width ?? 1, 1),
                    pigmentEngine.bitmap.size.height / max(geometry?.viewBox.height ?? 1, 1))
    }

    private func canvasScaleMetrics(canvasSize: CGSize, toolSize: CGFloat) -> (documentToCanvasScale: CGFloat, documentToBitmapScale: CGFloat, previewStrokeSize: CGFloat, committedBitmapStrokeSize: CGFloat, bitmapSize: CGSize, canvasDocumentSize: CGSize) {
        let dcs: CGFloat
        if let geometry {
            dcs = min(
                canvasSize.width / max(geometry.viewBox.width, 1),
                canvasSize.height / max(geometry.viewBox.height, 1)
            )
        } else {
            dcs = documentToCanvasScale
        }
        let dbs = documentToBitmapScale
        let previewSize = toolSize * dcs * viewport.scale
        let bitmapSize = pigmentEngine?.bitmap.size ?? (geometry?.viewBox.size ?? .zero)
        let committedSize = toolSize * dbs
        return (dcs, dbs, previewSize, committedSize, bitmapSize, canvasDocumentSize)
    }

    private func strokeSeed(
        tool: ToolType,
        colorHex: String,
        samples: [StrokeSample],
        size: CGFloat,
        opacity: Double
    ) -> UInt64 {
        var hasher = CanvasStrokeHasher()
        hasher.combine(tool.rawValue)
        hasher.combine(colorHex)
        hasher.combine(Double(size))
        hasher.combine(opacity)
        if let firstSample = samples.first {
            hasher.combine(firstSample.point.x)
            hasher.combine(firstSample.point.y)
            hasher.combine(firstSample.timestamp ?? 0)
            if let force = firstSample.force {
                hasher.combine(force)
            }
        }
        return hasher.value
    }

    func syncFreehandDrawingFromCanvas(_ drawing: PKDrawing) {
        CanvasPerformanceProbe.count(.pencilKitDelegateSync)
        #if DEBUG
        AppLog.trace(AppLog.canvas, "syncFreehandDrawingFromCanvas: strokes=\(drawing.strokes.count)")
        #endif
        freehandDrawing = drawing
        markCanvasStateDirty()
    }

    private func clearFlattenedFreehandDrawingIfUnchanged(_ flattenedDrawing: PKDrawing) {
        guard hasVisibleFreehandDrawing(flattenedDrawing) else { return }
        guard freehandDrawing.dataRepresentation() == flattenedDrawing.dataRepresentation() else {
            canvasDiagnostics.record(
                .stroke,
                "freehand flatten preserved newer drawing strokes=\(freehandDrawing.strokes.count)"
            )
            return
        }
        freehandDrawing = PKDrawing()
        freehandExternalRevision += 1
        markCanvasStateDirty()
        canvasDiagnostics.record(
            .stroke,
            "freehand flattened into pigment layer strokes=\(flattenedDrawing.strokes.count)"
        )
    }

    private func hasVisibleFreehandDrawing(_ drawing: PKDrawing) -> Bool {
        !drawing.bounds.isNull && !drawing.bounds.isEmpty && !drawing.strokes.isEmpty
    }

    private static nonisolated func pigmentImageByFlatteningFreehandDrawing(
        _ drawing: PKDrawing?,
        over baseImage: UIImage,
        canvasSize: CGSize,
        bitmapSize: CGSize
    ) -> UIImage {
        guard let drawing,
              !drawing.bounds.isNull,
              !drawing.bounds.isEmpty,
              !drawing.strokes.isEmpty,
              canvasSize.width > 0,
              canvasSize.height > 0,
              bitmapSize.width > 0,
              bitmapSize.height > 0 else {
            return baseImage
        }

        let scale = min(bitmapSize.width / canvasSize.width, bitmapSize.height / canvasSize.height)
        let freehandImage = drawing.image(
            from: CGRect(origin: .zero, size: canvasSize),
            scale: max(1, scale)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard

        return UIGraphicsImageRenderer(size: bitmapSize, format: format).image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: bitmapSize))
            freehandImage.draw(in: CGRect(origin: .zero, size: bitmapSize))
        }
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
        let size = premiumPigmentBitmapSize(for: geometry.viewBox.size)
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
            pigmentEngine = RegionPigmentEngine(geometry: geometry, bitmapSize: size, existingImage: storedImage)
            fillLayerImage = pigmentEngine?.image
        } else {
            let renderedFillLayer = TemplateRenderer.renderFillLayer(geometry: geometry, fills: paintState.regionFills, size: size)
            let legacyLayer = renderStrokeActions(on: renderedFillLayer, geometry: geometry)
            pigmentEngine = RegionPigmentEngine(geometry: geometry, bitmapSize: size, existingImage: legacyLayer)
            fillLayerImage = legacyLayer
        }
    }

    private func renderLineArtImage(
        geometry: TemplateGeometry,
        lineArtURL: URL?,
        strokeWidthPixels: CGFloat
    ) async -> UIImage {
        let size = premiumLineArtSize(for: geometry.viewBox.size)
        if let lineArtURL {
            let image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: lineArtURL.path)
            }.value
            if let image, max(image.size.width, image.size.height) >= max(size.width, size.height) {
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

    private func premiumLineArtSize(for documentSize: CGSize) -> CGSize {
        premiumPixelSize(for: documentSize, targetLongestSide: renderTargetLongestSide)
    }

    private func premiumPigmentBitmapSize(for documentSize: CGSize) -> CGSize {
        premiumPixelSize(for: documentSize, targetLongestSide: renderTargetLongestSide)
    }

    private func premiumPixelSize(for documentSize: CGSize, targetLongestSide: CGFloat) -> CGSize {
        let longestSide = max(documentSize.width, documentSize.height)
        guard longestSide > 0 else { return documentSize }
        let scale = max(1, targetLongestSide / longestSide)
        return CGSize(width: documentSize.width * scale, height: documentSize.height * scale)
    }

    private static var defaultRenderTargetLongestSide: CGFloat {
        #if DEBUG
        if let override = debugRenderTargetLongestSideOverride {
            return override
        }
        #endif
        return 4096
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

    private func refreshArtworkAfterEdit() {
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
        guard !isLiveDrawing, !hasPendingPigmentCommits else { return }
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
            cgContext.saveGState()
            cgContext.concatenate(
                TemplateRenderer.documentToViewTransform(
                    viewBox: geometry.viewBox,
                    viewSize: baseImage.size
                )
            )
            for action in paintState.strokeActions {
                draw(action: action, geometry: geometry, in: cgContext)
            }
            cgContext.restoreGState()
        }
    }

    private func draw(action: StrokeAction, geometry: TemplateGeometry, in context: CGContext) {
        BrushRenderers.draw(action: action, geometry: geometry, in: context)
    }

    private func debugPoint(_ point: CGPoint) -> String {
        "(\(debugNumber(point.x)), \(debugNumber(point.y)))"
    }

    private func debugSize(_ size: CGSize) -> String {
        "(\(debugNumber(size.width)), \(debugNumber(size.height)))"
    }

    private func debugRect(_ rect: CGRect) -> String {
        "origin=\(debugPoint(rect.origin)) size=\(debugSize(rect.size))"
    }

    private func debugNumber(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
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

private struct CanvasStrokeHasher {
    private(set) var value: UInt64 = 0xcbf29ce484222325

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            combine(byte)
        }
        combine(UInt8(0xff))
    }

    mutating func combine(_ double: Double) {
        combine(String(format: "%.6f", double))
    }

    private mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value &*= 0x100000001b3
    }
}

private extension UIImage {
    func rgbaPixel(at point: CGPoint) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard point.x >= 0,
              point.y >= 0,
              point.x < size.width,
              point.y < size.height,
              let cgImage else {
            return nil
        }

        let x = min(max(Int(point.x), 0), cgImage.width - 1)
        let y = min(max(Int(point.y), 0), cgImage.height - 1)
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: -x, y: y - cgImage.height + 1, width: cgImage.width, height: cgImage.height))
        return (pixel[0], pixel[1], pixel[2], pixel[3])
    }
}

private enum CanvasEditAction {
    case fillPatch(FillPatchAction)
    case pigmentStrokePatch(StrokePatchAction)
    case erasePatch(StrokePatchAction)
    case clear(previousFills: [String: String], previousStrokes: [StrokeAction], previousImage: UIImage, clearedImage: UIImage)
}

enum CanvasPerformanceProbe {
    enum Counter: String {
        case cleanPreviewRender = "CleanPreviewRender"
        case cleanLiveStrokeUpdate = "CleanLiveStrokeUpdate"
        case fillLayerPublish = "FillLayerPublish"
        case pencilKitDelegateSync = "PencilKitDelegateSync"
        case pencilKitSerialization = "PencilKitSerialization"
        case pngEncoding = "PNGEncoding"
        case thumbnailComposition = "ThumbnailComposition"
    }

    #if DEBUG
    private static let log = OSLog(subsystem: "com.prateekranka.colorflow", category: "CanvasHotPath")

    static func count(_ counter: Counter) {
        os_signpost(.event, log: log, name: "Counter", "%{public}s", counter.rawValue)
    }

    static func measure<T>(_ counter: Counter, _ work: () -> T) -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Measure", signpostID: id, "%{public}s", counter.rawValue)
        let result = work()
        os_signpost(.end, log: log, name: "Measure", signpostID: id, "%{public}s", counter.rawValue)
        return result
    }
    #else
    static func count(_ counter: Counter) {}
    static func measure<T>(_ counter: Counter, _ work: () -> T) -> T { work() }
    #endif
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
