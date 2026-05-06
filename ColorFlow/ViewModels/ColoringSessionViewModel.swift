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

    var state: LoadState = .idle
    var project: Project?
    var template: Template?
    var lineArtImage: UIImage?
    var fillLayerImage: UIImage?
    var selectedColorHex = SableTheme.progressPinkHex
    var canvasDocumentSize = CGSize(width: 800, height: 800)
    var isSaving = false

    @ObservationIgnored private let repository: any ColoringFlowRepositoryProtocol
    @ObservationIgnored private let storageService: StorageService
    @ObservationIgnored private let initialProject: Project?
    @ObservationIgnored private let initialTemplate: Template?
    @ObservationIgnored private let projectId: UUID?
    @ObservationIgnored private let templateId: UUID?
    @ObservationIgnored private var geometry: TemplateGeometry?
    @ObservationIgnored private var paintState = ProjectPaintState()
    @ObservationIgnored private var hasLoaded = false

    let fallbackTitle: String

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

    var paletteHexes: [String] {
        [
            SableTheme.progressPinkHex,
            SableTheme.crimsonHex,
            MoodCategory.calm.accentHex,
            MoodCategory.playful.accentHex,
            MoodCategory.wild.accentHex,
            MoodCategory.dreamy.accentHex,
            MoodCategory.noir.accentHex,
            "#111111"
        ]
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
            await renderImages(geometry: parsedGeometry)
            hasLoaded = true
            state = .ready
        }
    }

    func fill(atCanvasPoint point: CGPoint, canvasSize: CGSize) async {
        guard let geometry else { return }
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let documentPoint = point.applying(transform.inverted())
        await fill(atDocumentPoint: documentPoint)
    }

    func fill(atDocumentPoint point: CGPoint) async {
        guard let geometry,
              let region = geometry.region(at: point),
              var mutableProject = project else { return }

        let previousHex = paintState.regionFills[region.id]
        guard previousHex != selectedColorHex else { return }

        paintState.regionFills[region.id] = selectedColorHex
        mutableProject.updateCompletion(
            filledRegionCount: paintState.regionFills.count,
            totalRegionCount: geometry.regions.count
        )
        project = mutableProject

        let fills = paintState.regionFills
        let size = geometry.viewBox.size
        fillLayerImage = await Task.detached(priority: .userInitiated) {
            TemplateRenderer.renderFillLayer(
                geometry: geometry,
                fills: fills,
                size: size
            )
        }.value

        save()
        HapticService.shared.impact(.light)
    }

    func save() {
        guard var mutableProject = project else { return }
        isSaving = true
        storageService.savePaintState(paintState, for: mutableProject)
        storageService.save(
            project: &mutableProject,
            drawing: PKDrawing(),
            fillLayer: fillLayerImage,
            templateImage: lineArtImage
        )
        project = mutableProject
        ProjectThumbnailCache.shared.invalidate(id: mutableProject.id)
        isSaving = false
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
}
