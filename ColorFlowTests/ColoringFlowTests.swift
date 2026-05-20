import PencilKit
import UIKit
import XCTest
@testable import ColorFlow

@MainActor
final class ColoringFlowTests: XCTestCase {
    private var storage: StorageService!
    private var projectsToDelete: [Project] = []

    private let dummyGeometry = TemplateGeometry(
        viewBox: CGRect(x: 0, y: 0, width: 200, height: 200),
        regions: [],
        decorativePaths: []
    )

    override func setUp() {
        super.setUp()
        storage = StorageService()
        for project in storage.loadAllProjects() {
            storage.delete(project: project)
        }
        projectsToDelete = []
    }

    override func tearDown() {
        for project in projectsToDelete {
            storage.delete(project: project)
        }
        projectsToDelete = []
        storage = nil
        super.tearDown()
    }

    func test_storage_openOrCreateProject_reusesLatestProjectForTemplate() throws {
        let template = try uniqueTemplate()

        let first = storage.openOrCreateProject(for: template)
        projectsToDelete.append(first)
        let second = storage.openOrCreateProject(for: template)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.templateId, template.id)
        XCTAssertNotNil(storage.loadProject(id: first.id))
    }

    func test_sableRepository_continuePagesResumeMatchingSavedProject() async throws {
        let template = try uniqueTemplate()
        var project = Project(template: template)
        project.updateCompletion(filledRegionCount: 3, totalRegionCount: 4)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let repository = SableHomeRepository(storageService: storage, templates: [template])
        let pages = await repository.fetchContinuePages()
        let libraryPages = await repository.fetchLibraryPages()

        let page = try XCTUnwrap(pages.first { $0.projectId == project.id })
        XCTAssertEqual(page.templateId, template.id)
        XCTAssertEqual(page.title, template.name)
        XCTAssertEqual(page.progress, 0.75)
        XCTAssertEqual(page.thumbnailPath, project.thumbnailPath)
        XCTAssertEqual(page.fillLayerPath, project.fillLayerPath)
        XCTAssertTrue(libraryPages.contains { $0.projectId == project.id })

        let resolved = await repository.resolveProject(projectId: page.projectId, templateId: page.templateId)
        XCTAssertEqual(resolved?.project.id, project.id)
        XCTAssertEqual(resolved?.template.id, template.id)
    }

    func test_sableRepository_continuePagesSortByLatestModifiedProject() async throws {
        let olderTemplate = try uniqueTemplate(named: "Older Saved Page")
        let middleTemplate = try uniqueTemplate(named: "Middle Saved Page")
        let newestTemplate = try uniqueTemplate(named: "Newest Saved Page")

        var olderProject = Project(template: olderTemplate)
        olderProject.updateCompletion(filledRegionCount: 1, totalRegionCount: 4)
        storage.save(project: &olderProject, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(olderProject)

        usleep(20_000)
        var middleProject = Project(template: middleTemplate)
        middleProject.updateCompletion(filledRegionCount: 2, totalRegionCount: 4)
        storage.save(project: &middleProject, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(middleProject)

        usleep(20_000)
        var newestProject = Project(template: newestTemplate)
        newestProject.updateCompletion(filledRegionCount: 3, totalRegionCount: 4)
        storage.save(project: &newestProject, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(newestProject)

        let repository = SableHomeRepository(
            storageService: storage,
            templates: [olderTemplate, middleTemplate, newestTemplate]
        )

        let pages = await repository.fetchContinuePages()

        XCTAssertEqual(
            pages.prefix(3).map(\.projectId),
            [newestProject.id, middleProject.id, olderProject.id]
        )
        XCTAssertEqual(pages.prefix(3).map(\.title), ["Newest Saved Page", "Middle Saved Page", "Older Saved Page"])
    }

    func test_sableRepository_freshUserHasNoFakeContinuePlaceholders() async throws {
        let repository = SableHomeRepository(storageService: storage, templates: [try uniqueTemplate()])

        let pages = await repository.fetchContinuePages()

        XCTAssertTrue(pages.isEmpty)
    }

    func test_coloringSession_fillPersistsPaintStateAndProjectProgress() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let viewModel = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await viewModel.load()

        await viewModel.fill(atDocumentPoint: try representativeFillPoint())

        XCTAssertEqual(viewModel.filledRegionCount, 1)
        XCTAssertNotNil(viewModel.fillLayerImage)
        XCTAssertGreaterThan(viewModel.progress, 0)
        XCTAssertEqual(viewModel.saveState, .dirty)

        XCTAssertEqual(storage.loadPaintState(for: project).regionFills.count, 0)
        viewModel.save()
        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        XCTAssertGreaterThan(savedProject.completionPercentage, 0)
        XCTAssertEqual(storage.loadPaintState(for: savedProject).regionFills.count, 1)
        XCTAssertEqual(viewModel.saveState, .saved)
    }

    func test_coloringSession_reopeningProjectRestoresSavedFills() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let firstSession = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await firstSession.load()

        await firstSession.fill(atDocumentPoint: try representativeFillPoint())
        firstSession.save()

        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        let repository = SableHomeRepository(storageService: storage, templates: [template])
        let reopenedSession = ColoringSessionViewModel(
            projectId: savedProject.id,
            templateId: template.id,
            fallbackTitle: template.name,
            repository: repository,
            storageService: storage
        )

        await reopenedSession.load()

        XCTAssertEqual(reopenedSession.filledRegionCount, 1)
        XCTAssertEqual(reopenedSession.progress, savedProject.completionPercentage)
        XCTAssertNotNil(reopenedSession.fillLayerImage)
    }

    func test_coloringSession_undoRedoRestoresTapFillsAndDirtyState() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let viewModel = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await viewModel.load()

        let point = try representativeFillPoint()

        let didFill = await viewModel.fill(atDocumentPoint: point)
        XCTAssertTrue(didFill)
        let filledProgress = viewModel.progress

        XCTAssertEqual(viewModel.filledRegionCount, 1)
        XCTAssertGreaterThan(filledProgress, 0)
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .dirty)

        await viewModel.undoLastFill()

        XCTAssertEqual(viewModel.filledRegionCount, 0)
        XCTAssertEqual(viewModel.progress, 0)
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertTrue(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .saved)

        await viewModel.redoFill()

        XCTAssertEqual(viewModel.filledRegionCount, 1)
        XCTAssertEqual(viewModel.progress, filledProgress, accuracy: 0.0001)
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .dirty)
    }

    func test_coloringSession_clearArtworkResetsProgressAfterConfirmationPathAndSavesBlankState() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let viewModel = ColoringSessionViewModel(
            project: project,
            template: template,
            storageService: storage
        )
        await viewModel.load()

        let didFill = await viewModel.fill(atDocumentPoint: try representativeFillPoint())
        XCTAssertTrue(didFill)
        viewModel.save()
        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        XCTAssertEqual(storage.loadPaintState(for: savedProject).regionFills.count, 1)

        await viewModel.clearArtwork()

        XCTAssertEqual(viewModel.filledRegionCount, 0)
        XCTAssertEqual(viewModel.progress, 0)
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
        XCTAssertEqual(viewModel.saveState, .dirty)
        XCTAssertEqual(storage.loadPaintState(for: savedProject).regionFills.count, 1)

        viewModel.save()
        let resetProject = try XCTUnwrap(storage.loadProject(id: project.id))
        XCTAssertEqual(resetProject.completionPercentage, 0)
        XCTAssertEqual(storage.loadPaintState(for: resetProject).regionFills.count, 0)
        XCTAssertEqual(viewModel.saveState, .saved)
    }

    func test_coloringSession_essentialPaletteKeepsFastSwatchesReachable() throws {
        let template = try CanvasTestFixture.makeTemplate()
        let viewModel = ColoringSessionViewModel(
            project: Project(template: template),
            template: template,
            storageService: storage
        )

        XCTAssertEqual(viewModel.selectedPalette.name, "Essentials")
        XCTAssertTrue(viewModel.selectedSwatches.contains { $0.hex == SableTheme.progressPinkHex })
        XCTAssertTrue(viewModel.palettes.contains { $0.name == "Pastels" })
        XCTAssertEqual(ColoringSessionViewModel.SaveState.saving.label, "Saving...")
    }

    func test_allBundledTemplatesLoadInCanvasAndAcceptRepresentativeFill() async throws {
        let templates = Template.loadAll()
        XCTAssertFalse(templates.isEmpty)

        for template in templates {
            let viewModel = ColoringSessionViewModel(
                project: Project(template: template),
                template: template,
                storageService: storage
            )

            await viewModel.load()

            guard case .ready = viewModel.state else {
                XCTFail("\(template.name) did not load in Canvas: \(viewModel.state)")
                continue
            }

            guard let svgURL = template.svgURL,
                  case .success(let geometry) = SVGParser.parse(url: svgURL),
                  let point = CanvasTestFixture.representativeFillPoint(in: geometry) else {
                XCTFail("\(template.name) has no representative fillable region.")
                continue
            }

            let didFill = await viewModel.fill(atDocumentPoint: point)
            XCTAssertTrue(didFill, "\(template.name) should accept a tap fill at its representative fill point.")
            XCTAssertEqual(viewModel.filledRegionCount, 1, "\(template.name) should report one filled region.")
            XCTAssertEqual(viewModel.saveState, .dirty)
        }
    }

    // MARK: - Brush Renderer Tests

    func test_strokeAction_decodesLegacyPayloadWithoutSamples() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "tool": "Crayon",
          "colorHex": "#FF0000",
          "points": [
            { "x": 10, "y": 20 },
            { "x": 30, "y": 40 }
          ],
          "size": 12,
          "opacity": 0.75
        }
        """

        let action = try JSONDecoder().decode(StrokeAction.self, from: Data(json.utf8))

        XCTAssertEqual(action.points.count, 2)
        XCTAssertEqual(action.samples.map(\.point), action.points)
        XCTAssertNil(action.samples.first?.force)
    }

    func test_strokeAction_omitsSamplesWhenOnlyLegacyPointsArePresent() throws {
        let action = makeStroke(tool: .marker)

        let data = try JSONEncoder().encode(action)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["samples"])
        XCTAssertNotNil(object["points"])
    }

    func test_brushRenderers_allToolsProduceDifferentOutput() {
        let tools: [ToolType] = [.crayon, .coloredPencil, .watercolor, .marker, .sprayPaint, .eraser]
        var images: [(ToolType, Data)] = []

        for tool in tools {
            let stroke = makeStroke(tool: tool)
            let image = renderStroke(stroke)
            guard let pngData = image.pngData() else {
                XCTFail("Failed to get PNG data for \(tool.rawValue)")
                return
            }
            images.append((tool, pngData))
        }

        var distinctCount = 0
        for i in 0..<images.count {
            for j in (i + 1)..<images.count {
                if images[i].1 != images[j].1 {
                    distinctCount += 1
                }
            }
        }
        XCTAssertGreaterThanOrEqual(distinctCount, 2, "At least 2 brush tools should produce different pixel output")
    }

    func test_brushRenderers_texturedBrushReplayIsDeterministic() {
        let stroke = makeStroke(
            tool: .sprayPaint,
            colorHex: "#2BBCB3",
            size: 24,
            opacity: 0.7
        )

        XCTAssertEqual(renderStroke(stroke).pngData(), renderStroke(stroke).pngData())
    }

    func test_brushRenderers_liveStrokeMatchesCommittedWatercolorPath() {
        let stroke = makeStroke(tool: .watercolor, colorHex: "#4169E1", size: 18, opacity: 0.6)
        let committed = renderStroke(stroke)
        let live = renderLiveStroke(
            points: stroke.points.map(\.cgPoint),
            tool: stroke.tool,
            colorHex: stroke.colorHex,
            size: CGFloat(stroke.size),
            opacity: CGFloat(stroke.opacity)
        )

        XCTAssertEqual(committed.pngData(), live.pngData())
    }

    func test_crayonRendering_hasTextureVariation() {
        let stroke = makeStroke(tool: .crayon, size: 12)
        let image = renderStroke(stroke)

        var centerAlphas: [CGFloat] = []
        var edgeAlphas: [CGFloat] = []

        for i in 0..<16 {
            let cx = 10 + Double(i) * 5
            if let centerPixel = readPixel(in: image, at: CGPoint(x: cx, y: 100)),
               let edgePixel = readPixel(in: image, at: CGPoint(x: cx, y: 105.5)) {
                centerAlphas.append(CGFloat(centerPixel.a) / 255.0)
                edgeAlphas.append(CGFloat(edgePixel.a) / 255.0)
            }
        }

        XCTAssertFalse(centerAlphas.isEmpty, "Should have sampled center pixels")
        let differs = zip(centerAlphas, edgeAlphas).contains { abs($0 - $1) > 0.01 }
        XCTAssertTrue(differs, "Edge pixels should differ from center pixels due to crayon jitter")
    }

    func test_sprayPaintRendering_producesNonContinuousOutput() {
        let stroke = makeStroke(tool: .sprayPaint, size: 20)
        let image = renderStroke(stroke, size: CGSize(width: 200, height: 200))

        var hasColored = false
        var hasTransparent = false

        for y in 70..<130 {
            for x in 0..<190 {
                guard let pixel = readPixel(in: image, at: CGPoint(x: x, y: y)) else { continue }
                if pixel.a > 0 {
                    hasColored = true
                } else {
                    hasTransparent = true
                }
                if hasColored && hasTransparent { break }
            }
            if hasColored && hasTransparent { break }
        }

        XCTAssertTrue(hasColored, "Spray paint should produce colored pixels")
        XCTAssertTrue(hasTransparent, "Spray paint should produce transparent gaps (non-continuous)")
    }

    func test_watercolorRendering_hasFadingEdges() {
        let stroke = makeStroke(tool: .watercolor, size: 24, opacity: 0.8)
        let image = renderStroke(stroke)

        var centerMaxAlpha: CGFloat = 0
        var edgeMaxAlpha: CGFloat = 0

        for i in 0..<16 {
            let cx = 10 + Double(i) * 5
            if let centerPixel = readPixel(in: image, at: CGPoint(x: cx, y: 100)) {
                centerMaxAlpha = max(centerMaxAlpha, CGFloat(centerPixel.a) / 255.0)
            }
            if let edgePixel = readPixel(in: image, at: CGPoint(x: cx, y: 115)) {
                edgeMaxAlpha = max(edgeMaxAlpha, CGFloat(edgePixel.a) / 255.0)
            }
        }

        XCTAssertGreaterThan(centerMaxAlpha, 0, "Watercolor center should have visible pixels")
        XCTAssertGreaterThan(centerMaxAlpha, edgeMaxAlpha, "Watercolor center opacity should exceed edge opacity (fading edges)")
    }

    func test_stayInLines_clipsStrokeToRegion() {
        let regionRect = CGRect(x: 50, y: 50, width: 100, height: 100)
        let regionPath = CGMutablePath()
        regionPath.addRect(regionRect)
        let region = RegionGeometry(
            id: "r1",
            path: regionPath,
            bounds: regionRect,
            fillRule: .winding,
            zIndex: 0
        )
        let geometry = TemplateGeometry(
            viewBox: CGRect(x: 0, y: 0, width: 200, height: 200),
            regions: [region],
            decorativePaths: []
        )

        let points: [CodablePoint] = [
            CodablePoint(x: 20, y: 20),
            CodablePoint(x: 60, y: 60),
            CodablePoint(x: 100, y: 100),
            CodablePoint(x: 150, y: 150),
            CodablePoint(x: 180, y: 180)
        ]
        let stroke = StrokeAction(
            tool: .crayon,
            colorHex: "#FF0000",
            points: points,
            clippedRegionID: nil,
            size: 14,
            opacity: 1.0
        )

        let image = renderStroke(stroke, geometry: geometry)

        for y in 0..<200 {
            for x in 0..<200 {
                let point = CGPoint(x: x, y: y)
                let inRegion = regionRect.contains(point)
                guard let pixel = readPixel(in: image, at: point) else { continue }
                if !inRegion {
                    XCTAssertEqual(pixel.a, 0, "Pixel at (\(x), \(y)) outside region should be transparent")
                }
            }
        }
    }

    func test_eraser_clearsExistingContent() {
        let colorStroke = makeStroke(tool: .crayon, colorHex: "#FF0000", size: 10, opacity: 1.0)
        let baseImage = renderStroke(colorStroke)

        let eraseStroke = makeStroke(tool: .eraser, colorHex: "#000000", size: 16, opacity: 1.0)
        let resultImage = renderStroke(eraseStroke, onto: baseImage)

        let samplePoint = CGPoint(x: 100, y: 100)
        guard let basePixel = readPixel(in: baseImage, at: samplePoint),
              let resultPixel = readPixel(in: resultImage, at: samplePoint) else {
            XCTFail("Failed to read pixels")
            return
        }

        XCTAssertGreaterThan(basePixel.a, 0, "Base image should have colored pixels before erasing")
        XCTAssertEqual(resultPixel.a, 0, "Eraser should clear pixels, producing transparent result at erased area")
    }

    func test_marker_usesMultiplyBlend() {
        let baseColor = makeColoredImage(color: UIColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1))
        let markerStroke = makeStroke(tool: .marker, colorHex: "#4169E1", size: 16, opacity: 1.0)
        let resultImage = renderStroke(markerStroke, onto: baseColor)

        let samplePoint = CGPoint(x: 100, y: 100)
        guard let basePixel = readPixel(in: baseColor, at: samplePoint),
              let resultPixel = readPixel(in: resultImage, at: samplePoint) else {
            XCTFail("Failed to read pixels")
            return
        }

        let baseLuminance = CGFloat(basePixel.r) + CGFloat(basePixel.g) + CGFloat(basePixel.b)
        let resultLuminance = CGFloat(resultPixel.r) + CGFloat(resultPixel.g) + CGFloat(resultPixel.b)
        XCTAssertLessThan(resultLuminance, baseLuminance, "Marker multiply blend should darken the background")
    }

    func test_strokePreviewActionMatchesCommittedActionVisualOutput() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.watercolor)
        vm.selectColor(hex: "#4169E1")
        vm.updateSelectedToolSize(24)
        vm.updateSelectedToolOpacity(0.42)
        vm.selectColoringMode(.free)

        let canvasSize = CGSize(width: 800, height: 800)
        let canvasPoints = previewCanvasStrokePoints(in: geometry, canvasSize: canvasSize)
        let previewAction = makePreviewAction(
            vm: vm,
            geometry: geometry,
            canvasPoints: canvasPoints,
            canvasSize: canvasSize
        )

        let didCommit = await vm.drawStroke(canvasPoints: canvasPoints, canvasSize: canvasSize)
        XCTAssertTrue(didCommit)
        let committedAction = try XCTUnwrap(vm.paintState.strokeActions.last)

        XCTAssertEqual(committedAction.tool, previewAction.tool)
        XCTAssertEqual(committedAction.colorHex, previewAction.colorHex)
        XCTAssertEqual(committedAction.points, previewAction.points)
        XCTAssertEqual(committedAction.clippedRegionID, previewAction.clippedRegionID)
        XCTAssertEqual(committedAction.size, previewAction.size, accuracy: 0.001)
        XCTAssertEqual(committedAction.opacity, previewAction.opacity, accuracy: 0.001)

        let previewImage = renderStroke(previewAction, geometry: geometry, size: geometry.viewBox.size)
        let committedImage = renderStroke(committedAction, geometry: geometry, size: geometry.viewBox.size)
        XCTAssertEqual(
            pixelDigest(previewImage),
            pixelDigest(committedImage),
            "The committed stroke must reproduce the same pixels as the live preview action."
        )
    }

    func test_incrementalStrokePreviewConvergesToCommittedPixels() async throws {
        let template = try CanvasTestFixture.makeTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.crayon)
        vm.selectColor(hex: SableTheme.progressPinkHex)
        vm.selectColoringMode(.free)

        let canvasSize = CGSize(width: 800, height: 800)
        let canvasPoints = previewCanvasStrokePoints(in: geometry, canvasSize: canvasSize)
        let committed = await vm.drawStroke(canvasPoints: canvasPoints, canvasSize: canvasSize)
        XCTAssertTrue(committed)
        let committedAction = try XCTUnwrap(vm.paintState.strokeActions.last)
        let committedDigest = pixelDigest(renderStroke(committedAction, geometry: geometry, size: geometry.viewBox.size))

        var previousVisiblePixels = 0
        for prefixCount in 2...committedAction.points.count {
            var previewAction = committedAction
            previewAction.points = Array(committedAction.points.prefix(prefixCount))
            previewAction.samples = Array(committedAction.samples.prefix(prefixCount))
            let previewDigest = pixelDigest(renderStroke(previewAction, geometry: geometry, size: geometry.viewBox.size))

            let toleratedEndpointAdjustment = max(8, Int(Double(previousVisiblePixels) * 0.02))
            XCTAssertGreaterThanOrEqual(
                previewDigest.visiblePixelCount + toleratedEndpointAdjustment,
                previousVisiblePixels,
                "Preview coverage should remain visually stable while a crayon stroke is extended."
            )
            previousVisiblePixels = previewDigest.visiblePixelCount

            if prefixCount == committedAction.points.count {
                XCTAssertEqual(previewDigest, committedDigest)
            } else {
                XCTAssertNotEqual(previewDigest, committedDigest)
            }
        }
    }

    func test_livePigmentBitmapDoesNotChangeWhenStrokeCommits() async throws {
        let template = try uniqueTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.watercolor)
        vm.selectColor(hex: "#4169E1")
        vm.updateSelectedToolSize(18)
        vm.updateSelectedToolOpacity(0.42)
        vm.selectColoringMode(.clean)

        let canvasSize = CGSize(width: 800, height: 800)
        let documentPoint = try XCTUnwrap(CanvasTestFixture.representativeFillPoint(in: geometry))
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let canvasPoints = (0..<6).map { index in
            CGPoint(
                x: documentPoint.x + CGFloat(index) * 1.5,
                y: documentPoint.y
            ).applying(transform)
        }
        let samples = canvasPoints.enumerated().map { index, point in
            StrokeSample(point: point, timestamp: Double(index) / 60.0)
        }
        let beforePixels = try XCTUnwrap(vm.fillLayerImage?.pngData())

        XCTAssertTrue(vm.beginLiveStroke(samples: [samples[0]], canvasSize: canvasSize))
        XCTAssertTrue(vm.updateLiveStroke(samples: samples, canvasSize: canvasSize))
        XCTAssertEqual(vm.fillLayerImage?.pngData(), beforePixels)

        XCTAssertTrue(vm.endLiveStroke(samples: samples, canvasSize: canvasSize))
        await vm.waitForPendingPigmentCommits()
        XCTAssertNotEqual(vm.fillLayerImage?.pngData(), beforePixels)
    }

    func test_asyncRapidTenStrokeSequencePreservesActionsAndBitmap() async throws {
        let template = try uniqueTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.marker)
        vm.selectColor(hex: "#4169E1")
        vm.selectColoringMode(.free)

        let canvasSize = CGSize(width: 800, height: 800)
        let initialDigest = pixelDigest(try XCTUnwrap(vm.fillLayerImage))
        for index in 0..<10 {
            let points = canvasStrokePoints(
                in: geometry,
                canvasSize: canvasSize,
                yOffset: CGFloat(index) * 3,
                xOffset: CGFloat(index) * 2
            )
            XCTAssertTrue(commitStrokeWithoutWaiting(vm: vm, canvasPoints: points, canvasSize: canvasSize))
        }

        XCTAssertTrue(vm.hasPendingPigmentCommits)
        await vm.waitForPendingPigmentCommits()

        XCTAssertEqual(vm.paintState.strokeActions.count, 10)
        XCTAssertTrue(vm.canUndo)
        XCTAssertNotEqual(pixelDigest(try XCTUnwrap(vm.fillLayerImage)), initialDigest)
    }

    func test_saveAfterAsyncStrokePersistsCommittedPigmentLayer() async throws {
        let template = try uniqueTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.watercolor)
        vm.selectColor(hex: "#00AAFF")
        vm.selectColoringMode(.free)

        let canvasSize = CGSize(width: 800, height: 800)
        XCTAssertTrue(commitStrokeWithoutWaiting(
            vm: vm,
            canvasPoints: canvasStrokePoints(in: geometry, canvasSize: canvasSize),
            canvasSize: canvasSize
        ))

        await vm.saveNowAfterPendingPigmentCommits()
        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        projectsToDelete.append(savedProject)
        let savedDigest = pixelDigest(try XCTUnwrap(vm.fillLayerImage))

        let reopened = ColoringSessionViewModel(project: savedProject, template: template, storageService: storage)
        await reopened.loadIfNeeded()

        XCTAssertEqual(pixelDigest(try XCTUnwrap(reopened.fillLayerImage)), savedDigest)
        XCTAssertEqual(reopened.paintState.strokeActions.count, 1)
    }

    func test_clearDuringPendingCommitDoesNotResurrectStaleBitmap() async throws {
        let template = try uniqueTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.crayon)
        vm.selectColor(hex: SableTheme.progressPinkHex)
        vm.selectColoringMode(.free)

        let canvasSize = CGSize(width: 800, height: 800)
        XCTAssertTrue(commitStrokeWithoutWaiting(
            vm: vm,
            canvasPoints: canvasStrokePoints(in: geometry, canvasSize: canvasSize),
            canvasSize: canvasSize
        ))

        await vm.clearArtwork()

        XCTAssertFalse(vm.hasPendingPigmentCommits)
        XCTAssertEqual(vm.paintState.strokeActions.count, 0)
        XCTAssertEqual(vm.filledRegionCount, 0)
        XCTAssertEqual(pixelDigest(try XCTUnwrap(vm.fillLayerImage)).visiblePixelCount, 0)
    }

    func test_nextStrokeCanBeginWhilePreviousCommitIsPending() async throws {
        let template = try uniqueTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.watercolor)
        vm.updateSelectedToolSize(42)
        vm.updateSelectedToolOpacity(0.8)
        vm.selectColor(hex: "#4169E1")
        vm.selectColoringMode(.free)

        let canvasSize = CGSize(width: 800, height: 800)
        let firstStroke = heavyCanvasStrokePoints(in: geometry, canvasSize: canvasSize, yOffset: 0)
        XCTAssertTrue(commitStrokeWithoutWaiting(vm: vm, canvasPoints: firstStroke, canvasSize: canvasSize))

        let nextStroke = heavyCanvasStrokePoints(in: geometry, canvasSize: canvasSize, yOffset: 24)
        let nextBeginTime = ContinuousClock.now
        XCTAssertTrue(vm.beginLiveStroke(samples: [StrokeSample(point: nextStroke[0])], canvasSize: canvasSize))
        let beginLatency = nextBeginTime.duration(to: .now)
        vm.cancelLiveStroke()

        await vm.waitForPendingPigmentCommits()
        XCTAssertLessThan(beginLatency, .milliseconds(16))
        XCTAssertEqual(vm.paintState.strokeActions.count, 1)
    }

    func test_rapidThreeStrokeRegression_cleanAndFreeModes() async throws {
        try await assertRapidThreeStrokeSequence(mode: .clean)
        try await assertRapidThreeStrokeSequence(mode: .free)
    }

    func test_asyncStrokeCommitIsDeterministicForPigmentToolsAndFillBucket() async throws {
        try await assertToolCommit(.crayon)
        try await assertToolCommit(.marker)
        try await assertToolCommit(.watercolor)
        try await assertToolCommit(.eraser)

        let template = try uniqueTemplate()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)
        await vm.loadIfNeeded()
        vm.selectTool(.fillBucket)
        vm.selectColor(hex: "#00AAFF")

        let didFill = await vm.fill(atDocumentPoint: try representativeFillPoint())
        XCTAssertTrue(didFill)
        XCTAssertFalse(vm.hasPendingPigmentCommits)
        XCTAssertEqual(vm.paintState.strokeActions.count, 0)
        XCTAssertEqual(vm.filledRegionCount, 1)
    }

    func test_exportMatchesCanvasSnapshotRendererOutput() async throws {
        let template = try uniqueTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.fillBucket)
        vm.selectColor(hex: "#00AAFF")
        await vm.fill(atDocumentPoint: try representativeFillPoint())
        vm.selectTool(.eraser)

        let canvasSize = CGSize(width: 800, height: 800)
        let documentPoint = try representativeFillPoint()
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let canvasSamples = [
            StrokeSample(point: documentPoint.applying(transform), timestamp: 0),
            StrokeSample(point: CGPoint(x: documentPoint.x + 12, y: documentPoint.y).applying(transform), timestamp: 1.0 / 60.0)
        ]
        _ = await vm.drawStroke(samples: canvasSamples, canvasSize: canvasSize)

        let exported = try XCTUnwrap(vm.exportImage())
        let expected = CanvasSnapshotRenderer().render(
            lineArtImage: vm.lineArtImage,
            pigmentLayer: vm.fillLayerImage,
            drawing: vm.freehandDrawing,
            size: geometry.viewBox.size
        )

        XCTAssertEqual(pixelDigest(exported), pixelDigest(expected))
    }

    func test_saveAndReloadPreservesCanonicalPigmentBitmap() async throws {
        let template = try uniqueTemplate()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.fillBucket)
        vm.selectColor(hex: "#00AAFF")
        await vm.fill(atDocumentPoint: try representativeFillPoint())
        vm.save()
        let savedProject = try XCTUnwrap(storage.loadProject(id: project.id))
        projectsToDelete.append(savedProject)
        let savedDigest = pixelDigest(try XCTUnwrap(vm.fillLayerImage))

        let reopened = ColoringSessionViewModel(project: savedProject, template: template, storageService: storage)
        await reopened.loadIfNeeded()

        XCTAssertEqual(pixelDigest(try XCTUnwrap(reopened.fillLayerImage)), savedDigest)
    }

    func test_strokePreviewFrameRenderingPerformance() throws {
        let geometry = try CanvasTestFixture.makeGeometry()
        let canvasSize = CGSize(width: 800, height: 800)
        let canvasPoints = previewCanvasStrokePoints(in: geometry, canvasSize: canvasSize)
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        ).inverted()
        let documentPoints = canvasPoints.map { $0.applying(transform) }
        let actions = (2...documentPoints.count).map { prefixCount in
            StrokeAction(
                tool: .crayon,
                colorHex: SableTheme.progressPinkHex,
                points: documentPoints.prefix(prefixCount).map { CodablePoint(x: $0.x, y: $0.y) },
                clippedRegionID: nil,
                size: 18,
                opacity: 0.78
            )
        }

        measure(metrics: [XCTClockMetric()]) {
            for action in actions {
                _ = renderStroke(action, geometry: geometry, size: geometry.viewBox.size)
            }
        }
    }

    func test_liveStrokeClip_isProvidedForCleanModeAndOmittedForFreeMode() async throws {
        let template = try uniqueTemplate()
        let geometry = try CanvasTestFixture.makeGeometry()
        let region = try XCTUnwrap(geometry.regions.first)
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()

        let canvasSize = CGSize(width: 800, height: 800)
        let documentToCanvas = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let sample = StrokeSample(point: CanvasTestFixture.interiorPoint(of: region).applying(documentToCanvas))

        vm.selectColoringMode(.clean)
        let cleanClip = try XCTUnwrap(vm.liveStrokeClip(samples: [sample], canvasSize: canvasSize))
        XCTAssertEqual(cleanClip.fillRule, region.fillRule)
        XCTAssertFalse(cleanClip.path.boundingBoxOfPath.isEmpty)

        vm.selectColoringMode(.free)
        XCTAssertNil(vm.liveStrokeClip(samples: [sample], canvasSize: canvasSize))
    }

    func test_liveStrokeRendererClipsPreviewToActiveRegion() throws {
        let clipPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 200), transform: nil)
        let image = renderLiveStroke(
            points: [
                CGPoint(x: 24, y: 100),
                CGPoint(x: 176, y: 100)
            ],
            tool: .crayon,
            colorHex: "#FF0000",
            size: 28,
            opacity: 1,
            clipPath: clipPath
        )

        let insidePixel = try XCTUnwrap(readPixel(in: image, at: CGPoint(x: 50, y: 100)))
        let outsidePixel = try XCTUnwrap(readPixel(in: image, at: CGPoint(x: 150, y: 100)))
        XCTAssertGreaterThan(insidePixel.a, 0)
        XCTAssertEqual(outsidePixel.a, 0)
    }

    // MARK: - Async Commit Test Helpers

    private func commitStrokeWithoutWaiting(
        vm: ColoringSessionViewModel,
        canvasPoints: [CGPoint],
        canvasSize: CGSize
    ) -> Bool {
        let samples = canvasPoints.enumerated().map { index, point in
            StrokeSample(point: point, timestamp: Double(index) / 120.0)
        }
        guard vm.beginLiveStroke(samples: [samples[0]], canvasSize: canvasSize) else {
            return false
        }
        _ = vm.updateLiveStroke(samples: samples, canvasSize: canvasSize)
        return vm.endLiveStroke(samples: samples, canvasSize: canvasSize)
    }

    private func assertRapidThreeStrokeSequence(mode: CanvasColoringMode) async throws {
        let template = try uniqueTemplate(named: "Rapid \(mode.rawValue) \(UUID().uuidString.prefix(6))")
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectTool(.crayon)
        vm.selectColor(hex: SableTheme.progressPinkHex)
        vm.selectColoringMode(mode)

        let canvasSize = CGSize(width: 800, height: 800)
        let initialDigest = pixelDigest(try XCTUnwrap(vm.fillLayerImage))
        for index in 0..<3 {
            let points = canvasStrokePoints(
                in: geometry,
                canvasSize: canvasSize,
                yOffset: mode == .clean ? 0 : CGFloat(index) * 5,
                xOffset: mode == .clean ? CGFloat(index) * 0.8 : CGFloat(index) * 4
            )
            XCTAssertTrue(commitStrokeWithoutWaiting(vm: vm, canvasPoints: points, canvasSize: canvasSize))
        }

        await vm.waitForPendingPigmentCommits()

        XCTAssertEqual(vm.paintState.strokeActions.count, 3)
        XCTAssertTrue(vm.canUndo)
        XCTAssertNotEqual(pixelDigest(try XCTUnwrap(vm.fillLayerImage)), initialDigest)
        XCTAssertEqual(Set(vm.paintState.strokeActions.map(\.id)).count, 3)
    }

    private func assertToolCommit(_ tool: ToolType) async throws {
        let template = try uniqueTemplate(named: "Tool \(tool.rawValue) \(UUID().uuidString.prefix(6))")
        let geometry = try CanvasTestFixture.makeGeometry()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        await vm.loadIfNeeded()
        vm.selectColoringMode(.free)
        let canvasSize = CGSize(width: 800, height: 800)

        if tool == .eraser {
            vm.selectTool(.marker)
            vm.selectColor(hex: "#00AAFF")
            let didDrawBase = await vm.drawStroke(
                canvasPoints: canvasStrokePoints(in: geometry, canvasSize: canvasSize),
                canvasSize: canvasSize
            )
            XCTAssertTrue(didDrawBase)
            let beforeEraseDigest = pixelDigest(try XCTUnwrap(vm.fillLayerImage))

            vm.selectTool(.eraser)
            let didErase = await vm.drawStroke(
                canvasPoints: canvasStrokePoints(in: geometry, canvasSize: canvasSize),
                canvasSize: canvasSize
            )
            XCTAssertTrue(didErase)

            XCTAssertEqual(vm.paintState.strokeActions.last?.tool, .eraser)
            XCTAssertNotEqual(pixelDigest(try XCTUnwrap(vm.fillLayerImage)), beforeEraseDigest)
            return
        }

        vm.selectTool(tool)
        vm.selectColor(hex: "#4169E1")
        let initialDigest = pixelDigest(try XCTUnwrap(vm.fillLayerImage))
        let didDraw = await vm.drawStroke(
            canvasPoints: canvasStrokePoints(in: geometry, canvasSize: canvasSize),
            canvasSize: canvasSize
        )
        XCTAssertTrue(didDraw)

        XCTAssertEqual(vm.paintState.strokeActions.last?.tool, tool)
        XCTAssertNotEqual(pixelDigest(try XCTUnwrap(vm.fillLayerImage)), initialDigest)
    }

    // MARK: - Brush Test Helpers

    private func makeStroke(
        tool: ToolType,
        colorHex: String = "#FF0000",
        size: Double = 10,
        opacity: Double = 0.8
    ) -> StrokeAction {
        let points = (0..<20).map { i in
            CodablePoint(x: 10 + Double(i) * 5, y: 100)
        }
        return StrokeAction(
            tool: tool,
            colorHex: colorHex,
            points: points,
            clippedRegionID: nil,
            size: size,
            opacity: opacity
        )
    }

    private func renderStroke(
        _ action: StrokeAction,
        onto baseImage: UIImage? = nil,
        geometry: TemplateGeometry? = nil,
        size: CGSize = CGSize(width: 200, height: 200)
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let geo = geometry ?? dummyGeometry
        return renderer.image { ctx in
            if let base = baseImage {
                base.draw(in: CGRect(origin: .zero, size: size))
            }
            BrushRenderers.draw(action: action, geometry: geo, in: ctx.cgContext)
        }
    }

    private func renderLiveStroke(
        points: [CGPoint],
        tool: ToolType,
        colorHex: String,
        size: CGFloat,
        opacity: CGFloat,
        baseImage: UIImage? = nil,
        canvasSize: CGSize = CGSize(width: 200, height: 200),
        clipPath: CGPath? = nil,
        clipFillRule: CGPathFillRule = .winding
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            if let baseImage {
                baseImage.draw(in: CGRect(origin: .zero, size: canvasSize))
            }
            BrushRenderers.drawLiveStroke(
                points: points,
                tool: tool,
                colorHex: colorHex,
                size: size,
                opacity: opacity,
                clipPath: clipPath,
                clipFillRule: clipFillRule,
                in: ctx.cgContext
            )
        }
    }

    private func makeColoredImage(color: UIColor, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func readPixel(in image: UIImage, at point: CGPoint) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard let cgImage = image.cgImage else { return nil }
        let w = cgImage.width
        let h = cgImage.height
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < w, y >= 0, y < h else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = w * 4
        var rawData = [UInt8](repeating: 0, count: bytesPerRow * h)

        guard let context = CGContext(
            data: &rawData,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        let offset = y * bytesPerRow + x * 4
        return (r: rawData[offset], g: rawData[offset + 1], b: rawData[offset + 2], a: rawData[offset + 3])
    }

    private func pixelDigest(_ image: UIImage) -> PixelDigest {
        guard let cgImage = image.cgImage else {
            return PixelDigest(width: 0, height: 0, visiblePixelCount: 0, alphaChecksum: 0, colorChecksum: 0)
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var rawData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return PixelDigest(width: width, height: height, visiblePixelCount: 0, alphaChecksum: 0, colorChecksum: 0)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var visiblePixelCount = 0
        var alphaChecksum: UInt64 = 0
        var colorChecksum: UInt64 = 0

        for index in stride(from: 0, to: rawData.count, by: 4) {
            let r = UInt64(rawData[index])
            let g = UInt64(rawData[index + 1])
            let b = UInt64(rawData[index + 2])
            let a = UInt64(rawData[index + 3])
            if a > 0 {
                visiblePixelCount += 1
            }
            alphaChecksum = alphaChecksum &* 31 &+ a
            colorChecksum = colorChecksum &* 31 &+ r &* 3 &+ g &* 5 &+ b &* 7 &+ a &* 11
        }

        return PixelDigest(
            width: width,
            height: height,
            visiblePixelCount: visiblePixelCount,
            alphaChecksum: alphaChecksum,
            colorChecksum: colorChecksum
        )
    }

    private func previewCanvasStrokePoints(in geometry: TemplateGeometry, canvasSize: CGSize) -> [CGPoint] {
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let y = geometry.viewBox.midY
        let startX = geometry.viewBox.minX + geometry.viewBox.width * 0.18
        let step = geometry.viewBox.width * 0.055
        return (0..<12).map { index in
            CGPoint(
                x: startX + CGFloat(index) * step,
                y: y + sin(CGFloat(index) * 0.7) * geometry.viewBox.height * 0.08
            ).applying(transform)
        }
    }

    private func canvasStrokePoints(
        in geometry: TemplateGeometry,
        canvasSize: CGSize,
        yOffset: CGFloat = 0,
        xOffset: CGFloat = 0
    ) -> [CGPoint] {
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let anchor = CanvasTestFixture.representativeFillPoint(in: geometry)
            ?? CGPoint(x: geometry.viewBox.midX, y: geometry.viewBox.midY)
        let y = anchor.y + yOffset
        let startX = anchor.x - geometry.viewBox.width * 0.035
        let step = geometry.viewBox.width * 0.008
        return (0..<12).map { index in
            CGPoint(
                x: startX + xOffset + CGFloat(index) * step,
                y: y + sin(CGFloat(index) * 0.7) * geometry.viewBox.height * 0.08
            ).applying(transform)
        }
    }

    private func heavyCanvasStrokePoints(
        in geometry: TemplateGeometry,
        canvasSize: CGSize,
        yOffset: CGFloat
    ) -> [CGPoint] {
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )
        let y = geometry.viewBox.midY + yOffset
        let startX = geometry.viewBox.minX + geometry.viewBox.width * 0.12
        let step = geometry.viewBox.width * 0.018
        return (0..<48).map { index in
            CGPoint(
                x: startX + CGFloat(index) * step,
                y: y + sin(CGFloat(index) * 0.28) * geometry.viewBox.height * 0.10
            ).applying(transform)
        }
    }

    private func makePreviewAction(
        vm: ColoringSessionViewModel,
        geometry: TemplateGeometry,
        canvasPoints: [CGPoint],
        canvasSize: CGSize
    ) -> StrokeAction {
        let transform = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        ).inverted()
        let documentPoints = canvasPoints.map { $0.applying(transform) }

        return StrokeAction(
            tool: vm.selectedTool,
            colorHex: vm.selectedColorHex,
            points: documentPoints.map { CodablePoint(x: $0.x, y: $0.y) },
            clippedRegionID: vm.coloringMode == .clean ? documentPoints.first.flatMap { geometry.region(at: $0)?.id } : nil,
            size: vm.selectedToolSettings.size,
            opacity: vm.selectedToolSettings.opacity
        )
    }

    private struct PixelDigest: Equatable {
        let width: Int
        let height: Int
        let visiblePixelCount: Int
        let alphaChecksum: UInt64
        let colorChecksum: UInt64
    }

    private func representativeFillPoint() throws -> CGPoint {
        let geometry = try CanvasTestFixture.makeGeometry()
        return try XCTUnwrap(CanvasTestFixture.representativeFillPoint(in: geometry))
    }

    private func uniqueTemplate() throws -> Template {
        try uniqueTemplate(named: "Sunflower \(UUID().uuidString.prefix(8))")
    }

    private func uniqueTemplate(named name: String) throws -> Template {
        let base = try CanvasTestFixture.makeTemplate()
        return Template(
            id: UUID(),
            name: name,
            category: base.category,
            difficulty: base.difficulty,
            svgFilename: base.svgFilename,
            thumbnailFilename: base.thumbnailFilename,
            userTemplateDirectoryPath: base.userTemplateDirectoryPath
        )
    }

    // MARK: - Finger Painting Tests

    func test_fingerPaintSettings_defaultToFalse() {
        let settings = GestureSettings()
        XCTAssertFalse(settings.fingerPaints)
    }

    func test_fingerPaintSettings_roundtripsThroughJSON() throws {
        var original = GestureSettings()
        original.fingerPaints = true
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(GestureSettings.self, from: data)
        XCTAssertTrue(restored.fingerPaints)
    }

    func test_fingerStroke_createsStrokeAction() async throws {
        let template = try uniqueTemplate()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        let loadExpectation = expectation(description: "load")
        Task {
            await vm.loadIfNeeded()
            loadExpectation.fulfill()
        }
        await fulfillment(of: [loadExpectation], timeout: 5)

        vm.coloringMode = .free
        let canvasSize = CGSize(width: 800, height: 800)
        let canvasPoints: [CGPoint] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 300, y: 300)
        ]

        let result = await vm.drawStroke(canvasPoints: canvasPoints, canvasSize: canvasSize)

        XCTAssertTrue(result)
        XCTAssertEqual(vm.paintState.strokeActions.count, 1)
        XCTAssertEqual(vm.saveState, .dirty)
    }

    func test_fingerStroke_stayInLines_clipsWhenClean() async throws {
        let template = try uniqueTemplate()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        let loadExpectation = expectation(description: "load")
        Task {
            await vm.loadIfNeeded()
            loadExpectation.fulfill()
        }
        await fulfillment(of: [loadExpectation], timeout: 5)

        let geometry = try CanvasTestFixture.makeGeometry()
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let canvasSize = CGSize(width: 800, height: 800)
        let docToView = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )

        vm.coloringMode = .clean
        let canvasPoints: [CGPoint] = [
            interior.applying(docToView),
            CanvasTestFixture.pointOutsideAllRegions.applying(docToView)
        ]

        let result = await vm.drawStroke(canvasPoints: canvasPoints, canvasSize: canvasSize)

        XCTAssertTrue(result)
        let stroke = try XCTUnwrap(vm.paintState.strokeActions.first)
        XCTAssertNotNil(stroke.clippedRegionID)
    }

    func test_fingerStroke_freeMode_doesNotClip() async throws {
        let template = try uniqueTemplate()
        let project = Project(template: template)
        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)

        let loadExpectation = expectation(description: "load")
        Task {
            await vm.loadIfNeeded()
            loadExpectation.fulfill()
        }
        await fulfillment(of: [loadExpectation], timeout: 5)

        let geometry = try CanvasTestFixture.makeGeometry()
        let region = try XCTUnwrap(geometry.regions.first)
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let canvasSize = CGSize(width: 800, height: 800)
        let docToView = TemplateRenderer.documentToViewTransform(
            viewBox: geometry.viewBox,
            viewSize: canvasSize
        )

        vm.coloringMode = .free
        let canvasPoints: [CGPoint] = [
            interior.applying(docToView),
            CanvasTestFixture.pointOutsideAllRegions.applying(docToView)
        ]

        let result = await vm.drawStroke(canvasPoints: canvasPoints, canvasSize: canvasSize)

        XCTAssertTrue(result)
        let stroke = try XCTUnwrap(vm.paintState.strokeActions.first)
        XCTAssertNil(stroke.clippedRegionID)
    }

    func test_syncFreehandDrawingFromCanvas_marksDirtyWithoutBumpingExternalRevision() async throws {
        let template = try uniqueTemplate()
        var project = Project(template: template)
        storage.save(project: &project, drawing: PKDrawing(), fillLayer: nil, templateImage: nil)
        projectsToDelete.append(project)

        let vm = ColoringSessionViewModel(project: project, template: template, storageService: storage)
        await vm.loadIfNeeded()

        let revisionBefore = vm.freehandExternalRevision
        let drawing = PKDrawing()

        vm.syncFreehandDrawingFromCanvas(drawing)

        XCTAssertEqual(vm.freehandExternalRevision, revisionBefore, "External revision should not change on canvas-origin sync")
        XCTAssertEqual(vm.saveState, .dirty, "Canvas sync should mark the session dirty")
    }
}
