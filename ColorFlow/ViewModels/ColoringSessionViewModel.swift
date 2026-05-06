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
    var canvasDocumentSize = CGSize(width: 800, height: 800)
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
    @ObservationIgnored private var undoStack: [FillAction] = []
    @ObservationIgnored private var redoStack: [FillAction] = []

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
        !paintState.regionFills.isEmpty
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
            lastSavedRegionFills = paintState.regionFills
            clearUndoHistory()
            saveState = .saved
            await renderImages(geometry: parsedGeometry)
            hasLoaded = true
            state = .ready
        }
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
        undoStack.append(action)
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
        applyFill(regionID: action.regionID, hex: action.previousHex)
        await refreshArtworkAfterEdit()
    }

    func redoFill() async {
        guard let action = redoStack.popLast() else { return }
        undoStack.append(action)
        syncUndoRedoState()
        applyFill(regionID: action.regionID, hex: action.newHex)
        await refreshArtworkAfterEdit()
    }

    func clearArtwork() async {
        guard !paintState.regionFills.isEmpty else { return }
        paintState.regionFills.removeAll()
        clearUndoHistory()
        await refreshArtworkAfterEdit()
        HapticService.shared.impact(.medium)
    }

    func save() {
        guard var mutableProject = project else { return }
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
        saveState = .saved
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

        async let lineArtTask = Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderLineArt(geometry: geometry, size: size)
        }.value

        async let fillLayerTask = Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderFillLayer(geometry: geometry, fills: fills, size: size)
        }.value

        let (lineArt, renderedFillLayer) = await (lineArtTask, fillLayerTask)
        lineArtImage = lineArt
        fillLayerImage = fills.isEmpty
            ? project.flatMap { storageService.loadFillLayer(for: $0) } ?? renderedFillLayer
            : renderedFillLayer
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
        fillLayerImage = await Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderFillLayer(
                geometry: geometry,
                fills: fills,
                size: size
            )
        }.value
    }

    private func updateSaveStateForCurrentPaint() {
        guard saveState != .saving else { return }
        saveState = paintState.regionFills == lastSavedRegionFills ? .saved : .dirty
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
