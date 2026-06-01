import SwiftUI
import UIKit
import QuartzCore
import PencilKit

@MainActor
struct ColoringCanvasView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(RenderTuningStore.self) private var renderTuning
    @State private var viewModel: ColoringSessionViewModel
    @State private var showClearArtworkConfirmation = false
    @State private var fillFeedbackID: UUID?
    @State private var isUIHidden = false
    @State private var fingerPaints = false
    @State private var showSettingsSheet = false
    @State private var showColorPicker = false
    @State private var showColorTray = false
    @State private var isEyedropperActive = false
    @State private var saveFeedbackID: UUID?
    @State private var undoRedoFeedbackID: UUID?
    @State private var zoomFeedbackID: UUID?
    @State private var selectedDockToolID = CanvasToolDockItem.defaultID
    @State private var precisionSlidersEnabled = true
    @State private var eyedropperShortcutEnabled = true
    @State private var colorHistoryEnabled = true
    @State private var leftHandedMode = false
    @State private var toolPreviewEnabled = true
    @State private var brushSoundsEnabled = false
    @State private var colorBlindMode = false
    @State private var sharePayload: CanvasSharePayload?
    @State private var freehandFlushRequestID = 0
    #if DEBUG && SHOW_RENDER_METRICS
    @State private var showRenderTuning = false
    #endif

    init(
        projectId: UUID?,
        templateId: UUID?,
        fallbackTitle: String,
        repository: any ColoringFlowRepositoryProtocol = SableHomeRepository(),
        storageService: StorageService = StorageService()
    ) {
        _viewModel = State(
            initialValue: ColoringSessionViewModel(
                projectId: projectId,
                templateId: templateId,
                fallbackTitle: fallbackTitle,
                repository: repository,
                storageService: storageService
            )
        )
    }

    init(viewModel: ColoringSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            CanvasPaperBackground()
                .ignoresSafeArea()

            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .tint(SableTheme.progressPink)
                    .scaleEffect(1.25)
            case .ready:
                readyBody
            case .failed(let message):
                errorBody(message: message)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Clear artwork?", isPresented: $showClearArtworkConfirmation) {
            Button("Clear Artwork", role: .destructive) {
                Task {
                    await viewModel.clearArtwork()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every filled region from \(viewModel.title). Save afterward to keep the reset artwork.")
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onDisappear {
            flushFreehandThenSave()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                flushFreehandThenSave()
            }
        }
    }

    private var readyBody: some View {
        ZStack {
            GeometryReader { proxy in
                let availableSize = proxy.size
                let canvasSize = fittedCanvasSize(in: availableSize)

                ZStack {
                    canvasArtwork(canvasSize: canvasSize)
                        .position(x: availableSize.width / 2, y: availableSize.height / 2)
                        .scaleEffect(viewModel.viewport.scale)
                        .offset(viewModel.viewport.offset)
                        .allowsHitTesting(viewModel.coloringMode == .free && viewModel.selectedTool != .fillBucket)

                    if viewModel.coloringMode == .clean || viewModel.selectedTool == .fillBucket || isEyedropperActive {
                        CanvasInteractionOverlay(
                            selectedTool: viewModel.selectedTool,
                            colorHex: viewModel.selectedTool == .eraser ? "#000000" : viewModel.selectedColorHex,
                            toolSettings: viewModel.selectedToolSettings,
                            fingerPaints: fingerPaints,
                            isEyedropperActive: isEyedropperActive,
                            liveStrokeSeed: viewModel.liveStrokeSeed,
                            fillLayerImage: viewModel.fillLayerImage,
                            lineArtImage: viewModel.lineArtImage,
                            canvasSize: canvasSize,
                            documentSize: viewModel.canvasDocumentSize,
                            viewportSize: availableSize,
                            viewport: viewModel.viewport,
                            onViewportChanged: { viewport in
                                viewModel.updateViewport(viewport)
                            },
                            onViewportCommitted: {
                                viewModel.commitViewportChange()
                            },
                            onUndo: {
                                guard viewModel.canUndo else { return }
                                undoRedoFeedbackID = UUID()
                                Task { await viewModel.undoLastFill() }
                            },
                            onRedo: {
                                guard viewModel.canRedo else { return }
                                undoRedoFeedbackID = UUID()
                                Task { await viewModel.redoFill() }
                            },
                            onToggleFocus: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isUIHidden.toggle()
                                }
                            },
                            onFit: resetViewport,
                            onFill: { point in
                                handleFill(atCanvasPoint: point, canvasSize: canvasSize)
                            },
                            onEyedropper: { point in
                                handleEyedropper(atCanvasPoint: point, canvasSize: canvasSize)
                            },
                            onStrokeBegan: { samples in
                                handleStrokeBegan(samples: samples, canvasSize: canvasSize)
                            },
                            onStrokeChanged: { samples in
                                handleStrokeChanged(samples: samples, canvasSize: canvasSize)
                            },
                            onStrokeEnded: { samples in
                                handleStrokeEnded(samples: samples, canvasSize: canvasSize)
                            },
                            onStrokeCancelled: {
                                viewModel.cancelLiveStroke()
                            },
                            onDebugInput: { input in
                                viewModel.recordCanvasInput(input)
                            },
                            liveStrokeClip: { samples in
                                viewModel.liveStrokeClip(samples: samples, canvasSize: canvasSize)
                            }
                        )
                        .frame(width: availableSize.width, height: availableSize.height)
                    }

                    #if DEBUG
                    if viewModel.canvasDiagnostics.isEnabled {
                        CanvasDebugOverlayView(
                            diagnostics: viewModel.canvasDiagnostics,
                            tool: viewModel.selectedTool,
                            mode: viewModel.coloringMode,
                            colorHex: viewModel.selectedTool == .eraser ? "#000000" : viewModel.selectedColorHex,
                            viewport: viewModel.viewport,
                            canvasSize: canvasSize,
                            viewportSize: availableSize
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 74)
                        .padding(.trailing, 22)
                    }
                    #endif
                }
                .clipped()
                .contentShape(Rectangle())
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel(viewModel.title)
                .accessibilityIdentifier(A11y.Canvas.surface)
            }

            if let zoomFeedbackID {
                CanvasZoomHint(scale: viewModel.viewport.scale)
                    .id(zoomFeedbackID)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -120)
                    .allowsHitTesting(false)
            }

            if !isUIHidden {
                CanvasChromeLayer(
                    viewModel: viewModel,
                    selectedDockToolID: $selectedDockToolID,
                    showColorTray: $showColorTray,
                    showColorPicker: $showColorPicker,
                    isDimmed: zoomFeedbackID != nil,
                    onBack: {
                        flushFreehandThenSave()
                        dismiss()
                    },
                    onUndo: {
                        guard viewModel.canUndo else { return }
                        undoRedoFeedbackID = UUID()
                        Task { await viewModel.undoLastFill() }
                    },
                    onRedo: {
                        guard viewModel.canRedo else { return }
                        undoRedoFeedbackID = UUID()
                        Task { await viewModel.redoFill() }
                    },
                    onLayers: {
                        showSettingsSheet = true
                    },
                    onSettings: {
                        showSettingsSheet = true
                    },
                    onShare: {
                        presentShareSheet()
                    },
                    onSave: {
                        guard viewModel.canSave else { return }
                        Task {
                            await viewModel.saveNowAfterPendingPigmentCommits()
                            saveFeedbackID = UUID()
                        }
                    },
                    onResetView: resetViewport,
                    onFocus: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isUIHidden = true
                        }
                    },
                    onClear: {
                        showClearArtworkConfirmation = true
                    },
                    onEyedropper: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showColorTray = false
                            isEyedropperActive = true
                        }
                    }
                )
            } else {
                VStack {
                    HStack {
                        Spacer()
                        Button("Show controls", systemImage: "eye") {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isUIHidden = false
                            }
                        }
                        .labelStyle(.iconOnly)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                        .frame(width: 44, height: 44)
                        .background(SableTheme.canvasChrome(for: colorScheme), in: Circle())
                        .overlay {
                            Circle().stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.8)
                        }
                        .accessibilityIdentifier("canvas.showControls")
                    }
                    Spacer()
                }
                .padding(22)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettingsSheet) {
            CanvasSettingsSheet(
                viewModel: viewModel,
                precisionSlidersEnabled: $precisionSlidersEnabled,
                eyedropperShortcutEnabled: $eyedropperShortcutEnabled,
                leftHandedMode: $leftHandedMode,
                colorBlindMode: $colorBlindMode,
                onRestart: { showClearArtworkConfirmation = true },
                onDelete: { showClearArtworkConfirmation = true }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $sharePayload) { payload in
            CanvasShareSheet(image: payload.image)
        }
        .sensoryFeedback(.success, trigger: saveFeedbackID)
        .sensoryFeedback(.selection, trigger: undoRedoFeedbackID)
        .task(id: renderTuning.canvasStrokeWidth) {
            await viewModel.updateCanvasStrokeWidth(renderTuning.canvasStrokeWidth)
        }
        .onChange(of: viewModel.viewport.scale) { oldValue, newValue in
            guard abs(newValue - oldValue) > 0.015 else { return }
            showZoomFeedback()
        }
        .onChange(of: viewModel.selectedTool) { _, tool in
            if CanvasToolDockItem.item(id: selectedDockToolID)?.tool != tool {
                selectedDockToolID = CanvasToolDockItem.primaryID(for: tool)
            }
        }
    }

    #if DEBUG && SHOW_RENDER_METRICS
    private var renderTuningButton: some View {
        Button {
            showRenderTuning.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .black))

                Text("Render")
                    .font(.system(size: 14, weight: .black))
            }
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SableTheme.cardBlack, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .popover(isPresented: $showRenderTuning, arrowEdge: .top) {
            CanvasRenderTuningPopover(tuning: renderTuning)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Render")
        .accessibilityIdentifier("canvas.render.tuning.button")
    }
    #endif

    private func canvasArtwork(canvasSize: CGSize) -> some View {
        ZStack {
            NotebookCanvasRepresentable(
                fillLayerImage: viewModel.fillLayerImage,
                lineArtImage: viewModel.lineArtImage,
                freehandDrawing: viewModel.coloringMode == .free ? PKDrawing() : viewModel.freehandDrawing,
                freehandDrawingRevision: viewModel.coloringMode == .free ? -1 : viewModel.freehandExternalRevision,
                showsLineArt: viewModel.coloringMode == .clean,
                viewportScale: viewModel.viewport.scale
            )

            if viewModel.coloringMode == .free, viewModel.selectedTool != .fillBucket {
                FreehandCanvasRepresentable(
                    drawing: viewModel.freehandDrawing,
                    drawingExternalRevision: viewModel.freehandExternalRevision,
                    flushRequestID: freehandFlushRequestID,
                    selectedTool: viewModel.selectedTool,
                    colorHex: viewModel.selectedColorHex,
                    settings: viewModel.selectedToolSettings,
                    fingerPaints: true,
                    onDrawingChanged: { viewModel.syncFreehandDrawingFromCanvas($0) },
                    onPigmentEraserBegan: { samples in
                        handleStrokeBegan(samples: samples, canvasSize: canvasSize)
                    },
                    onPigmentEraserChanged: { samples in
                        handleStrokeChanged(samples: samples, canvasSize: canvasSize)
                    },
                    onPigmentEraserEnded: { samples in
                        handleStrokeEnded(samples: samples, canvasSize: canvasSize)
                    },
                    onPigmentEraserCancelled: {
                        viewModel.cancelLiveStroke()
                    },
                    onDebugEvent: { message, throttleKey, minimumInterval in
                        viewModel.canvasDiagnostics.record(
                            .stroke,
                            message,
                            throttleKey: throttleKey,
                            minimumInterval: minimumInterval
                        )
                    }
                )
            }

            if viewModel.coloringMode == .free, let lineArtImage = viewModel.lineArtImage {
                Image(uiImage: lineArtImage)
                    .resizable()
                    .scaledToFit()
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }

            if fillFeedbackID != nil {
                fillFeedback
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.8)
        }
        .shadow(color: CanvasVisualSystem.shadow(for: colorScheme).opacity(colorScheme == .dark ? 0.9 : 0.62), radius: 24, x: 0, y: 12)
    }

    private var fillFeedback: some View {
        VStack {
            HStack {
                Spacer()
                Label("Filled", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SableTheme.cardBlack.opacity(0.9), in: Capsule())
                    .overlay {
                        Capsule().stroke(Color(hex: viewModel.selectedColorHex), lineWidth: 2)
                    }
                    .padding(14)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Filled")
                    .accessibilityIdentifier(A11y.Canvas.fillFeedback)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func showFillFeedback() {
        let token = UUID()
        fillFeedbackID = token
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if fillFeedbackID == token {
                    withAnimation(.easeOut(duration: 0.2)) {
                        fillFeedbackID = nil
                    }
                }
            }
        }
    }

    private func errorBody(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(SableTheme.crimson)

            Text("Canvas unavailable")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(SableTheme.ink)

            Text(message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SableTheme.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(40)
    }

    private func fittedCanvasSize(in availableSize: CGSize) -> CGSize {
        let isLandscape = availableSize.width > availableSize.height
        let horizontalInset: CGFloat = isLandscape ? 118 : 78
        let verticalReserve: CGFloat = isLandscape ? 232 : 312
        let documentSize = viewModel.canvasDocumentSize
        let maxSize = CGSize(
            width: max(1, availableSize.width - horizontalInset * 2),
            height: max(1, availableSize.height - verticalReserve)
        )
        let scale = min(
            maxSize.width / max(documentSize.width, 1),
            maxSize.height / max(documentSize.height, 1)
        )
        return CGSize(
            width: max(1, documentSize.width * scale),
            height: max(1, documentSize.height * scale)
        )
    }

    private func handleFill(atCanvasPoint point: CGPoint, canvasSize: CGSize) {
        guard viewModel.selectedTool == .fillBucket else { return }
        Task {
            let didFill = await viewModel.fill(
                atCanvasPoint: point,
                canvasSize: canvasSize
            )
            if didFill {
                withAnimation(.easeOut(duration: 0.15)) {
                    showFillFeedback()
                }
            }
        }
    }

    private func handleEyedropper(atCanvasPoint point: CGPoint, canvasSize: CGSize) {
        let didSample = viewModel.sampleColor(atCanvasPoint: point, canvasSize: canvasSize)
        withAnimation(.easeOut(duration: 0.14)) {
            isEyedropperActive = false
        }
        if didSample {
            HapticService.shared.impact(.light)
        }
    }

    private func handleStrokeBegan(samples: [StrokeSample], canvasSize: CGSize) -> Bool {
        guard viewModel.selectedTool != .fillBucket else { return false }
        return viewModel.beginLiveStroke(samples: samples, canvasSize: canvasSize)
    }

    private func handleStrokeChanged(samples: [StrokeSample], canvasSize: CGSize) -> Bool {
        guard viewModel.selectedTool != .fillBucket else { return false }
        return viewModel.updateLiveStroke(samples: samples, canvasSize: canvasSize)
    }

    private func handleStrokeEnded(samples: [StrokeSample], canvasSize: CGSize) -> Bool {
        guard viewModel.selectedTool != .fillBucket else { return false }
        return viewModel.endLiveStroke(samples: samples, canvasSize: canvasSize)
    }

    private func resetViewport() {
        var viewport = viewModel.viewport
        viewport.reset()
        viewModel.updateViewport(viewport)
        viewModel.commitViewportChange()
    }

    private func showZoomFeedback() {
        let token = UUID()
        withAnimation(.easeOut(duration: 0.16)) {
            zoomFeedbackID = token
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if zoomFeedbackID == token {
                    withAnimation(.easeOut(duration: 0.2)) {
                        zoomFeedbackID = nil
                    }
                }
            }
        }
    }

    private func flushFreehandThenSave() {
        freehandFlushRequestID += 1
        Task { @MainActor in
            await Task.yield()
            await viewModel.saveNowAfterPendingPigmentCommits()
        }
    }

    private func presentShareSheet() {
        Task { @MainActor in
            guard let image = await viewModel.exportImageAfterPendingPigmentCommits() else { return }
            sharePayload = CanvasSharePayload(image: image)
        }
    }
}

private struct CanvasSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct CanvasShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        ExportService().shareActivityController(image: image)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
private struct CanvasDebugOverlayView: View {
    let diagnostics: CanvasDebugDiagnostics
    let tool: ToolType
    let mode: CanvasColoringMode
    let colorHex: String
    let viewport: CanvasViewport
    let canvasSize: CGSize
    let viewportSize: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 10, height: 10)
                Text("Canvas Diagnostics")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                Spacer(minLength: 0)
            }

            Text("tool \(tool.rawValue) | mode \(mode.rawValue) | scale \(format(viewport.scale))")
            Text("canvas \(format(canvasSize)) | viewport \(format(viewportSize))")
            Text("offset \(format(viewport.offset))")

            if let hit = diagnostics.latestEvent?.hit {
                Divider().overlay(.white.opacity(0.22))
                Text("region \(hit.regionSummary)")
                    .foregroundStyle(hit.regionID == nil ? Color.yellow : Color.green)
                Text("doc \(format(hit.documentPoint)) | canvas \(format(hit.canvasPoint))")
                if let force = hit.force {
                    Text("force \(format(force)) | altitude \(format(hit.altitude)) | azimuth \(format(hit.azimuth))")
                }
                if let dcs = hit.documentToCanvasScale {
                    Text("doc→canvas \(format(dcs)) | doc→bitmap \(format(hit.documentToBitmapScale))")
                }
                if let ps = hit.previewStrokeSize, let cs = hit.committedStrokeSize {
                    Text("preview sz \(format(ps)) | committed sz \(format(cs))")
                }
                if let bps = hit.bitmapPixelSize {
                    Text("bitmap \(format(bps))")
                }
            }

            Divider().overlay(.white.opacity(0.22))

            ForEach(diagnostics.events.prefix(5)) { event in
                Text("\(event.shortTimestamp) \(event.kind.rawValue) \(event.message)")
                    .lineLimit(2)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(12)
        .frame(width: 380, alignment: .leading)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func format(_ point: CGPoint?) -> String {
        guard let point else { return "nil" }
        return "(\(format(point.x)),\(format(point.y)))"
    }

    private func format(_ size: CGSize) -> String {
        "(\(format(size.width)),\(format(size.height)))"
    }

    private func format(_ size: CGSize?) -> String {
        guard let size else { return "nil" }
        return format(size)
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "nil" }
        return String(format: "%.2f", value)
    }

    private func format(_ value: CGFloat?) -> String {
        guard let value else { return "nil" }
        return String(format: "%.1f", Double(value))
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
#endif

private struct NotebookCanvasRepresentable: UIViewRepresentable {
    let fillLayerImage: UIImage?
    let lineArtImage: UIImage?
    let freehandDrawing: PKDrawing
    let freehandDrawingRevision: Int
    let showsLineArt: Bool
    let viewportScale: CGFloat

    func makeUIView(context: Context) -> NotebookCanvasUIView {
        let view = NotebookCanvasUIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.contentMode = .redraw
        return view
    }

    func updateUIView(_ uiView: NotebookCanvasUIView, context: Context) {
        uiView.configure(
            fillLayerImage: fillLayerImage,
            lineArtImage: lineArtImage,
            freehandDrawing: freehandDrawing,
            freehandDrawingRevision: freehandDrawingRevision,
            showsLineArt: showsLineArt,
            viewportScale: viewportScale
        )
    }
}

enum CanvasArtworkRasterization {
    static let maximumContentScale: CGFloat = 6

    static func preferredBackingScale(
        viewportScale: CGFloat,
        screenScale: CGFloat,
        boundsSize: CGSize,
        sourcePixelSize: CGSize?
    ) -> CGFloat {
        let normalizedScreenScale = max(1, screenScale)
        let normalizedViewportScale = max(1, viewportScale)
        let desiredScale = normalizedScreenScale * normalizedViewportScale
        let sourceLimit: CGFloat
        if let sourcePixelSize,
           boundsSize.width > 0,
           boundsSize.height > 0,
           sourcePixelSize.width > 0,
           sourcePixelSize.height > 0 {
            sourceLimit = min(
                sourcePixelSize.width / boundsSize.width,
                sourcePixelSize.height / boundsSize.height
            )
        } else {
            sourceLimit = desiredScale
        }
        return min(desiredScale, max(normalizedScreenScale, sourceLimit), maximumContentScale)
    }
}

private final class NotebookCanvasUIView: UIView {
    private var fillLayerImage: UIImage?
    private var lineArtImage: UIImage?
    private var freehandDrawing = PKDrawing()
    private var freehandDrawingRevision = Int.min
    private var showsLineArt = true
    private var viewportScale: CGFloat = 1

    func configure(
        fillLayerImage: UIImage?,
        lineArtImage: UIImage?,
        freehandDrawing: PKDrawing,
        freehandDrawingRevision: Int,
        showsLineArt: Bool,
        viewportScale: CGFloat
    ) {
        let imageChanged = self.fillLayerImage !== fillLayerImage
            || self.lineArtImage !== lineArtImage
            || self.freehandDrawingRevision != freehandDrawingRevision
            || self.showsLineArt != showsLineArt
            || abs(self.viewportScale - viewportScale) > 0.01

        self.fillLayerImage = fillLayerImage
        self.lineArtImage = lineArtImage
        self.freehandDrawing = freehandDrawing
        self.freehandDrawingRevision = freehandDrawingRevision
        self.showsLineArt = showsLineArt
        self.viewportScale = viewportScale

        let backingScaleChanged = updateBackingScaleIfNeeded()
        if imageChanged || backingScaleChanged {
            setNeedsDisplay()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if updateBackingScaleIfNeeded() {
            setNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if updateBackingScaleIfNeeded() {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let canvasBounds = bounds
        context.interpolationQuality = .high

        UIColor(hex: "#FFFDF8").setFill()
        context.fill(canvasBounds)

        let artRect = imageRect(for: fillLayerImage ?? lineArtImage, in: canvasBounds)
        fillLayerImage?.draw(in: artRect)

        if !freehandDrawing.bounds.isNull && !freehandDrawing.bounds.isEmpty {
            freehandDrawing.image(from: CGRect(origin: .zero, size: artRect.size), scale: 1).draw(in: artRect)
        }

        if showsLineArt, let lineArtImage {
            context.saveGState()
            context.setBlendMode(.multiply)
            lineArtImage.draw(in: imageRect(for: lineArtImage, in: canvasBounds))
            context.restoreGState()
        }
    }

    private func imageRect(for image: UIImage?, in bounds: CGRect) -> CGRect {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    @discardableResult
    private func updateBackingScaleIfNeeded() -> Bool {
        let sourceImage = fillLayerImage ?? lineArtImage
        let nextScale = CanvasArtworkRasterization.preferredBackingScale(
            viewportScale: viewportScale,
            screenScale: window?.screen.scale ?? UIScreen.main.scale,
            boundsSize: bounds.size,
            sourcePixelSize: sourceImage?.pixelSize
        )
        guard abs(contentScaleFactor - nextScale) > 0.05 else { return false }
        contentScaleFactor = nextScale
        layer.contentsScale = nextScale
        return true
    }
}

private extension UIImage {
    var pixelSize: CGSize {
        if let cgImage {
            return CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        }
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

private struct FreehandCanvasRepresentable: UIViewRepresentable {
    var drawing: PKDrawing
    var drawingExternalRevision: Int
    var flushRequestID: Int
    var selectedTool: ToolType
    var colorHex: String
    var settings: ToolSettings
    var fingerPaints: Bool
    var onDrawingChanged: (PKDrawing) -> Void
    var onPigmentEraserBegan: ([StrokeSample]) -> Bool
    var onPigmentEraserChanged: ([StrokeSample]) -> Bool
    var onPigmentEraserEnded: ([StrokeSample]) -> Bool
    var onPigmentEraserCancelled: () -> Void
    var onDebugEvent: (String, String?, TimeInterval) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = FreehandPKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = fingerPaints ? .anyInput : .pencilOnly
        canvas.delegate = context.coordinator
        canvas.eraserTouchDelegate = context.coordinator
        canvas.drawing = drawing
        context.coordinator.appliedExternalRevision = drawingExternalRevision
        canvas.tool = makeTool()
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.bounces = false
        context.coordinator.recordFreehandEvent(
            "freehand canvas mounted policy=\(fingerPaints ? "anyInput" : "pencilOnly") \(Self.drawingSummary(drawing))"
        )
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.appliedExternalRevision != drawingExternalRevision {
            context.coordinator.isApplyingExternalDrawing = true
            uiView.drawing = drawing
            context.coordinator.isApplyingExternalDrawing = false
            context.coordinator.appliedExternalRevision = drawingExternalRevision
        }
        if context.coordinator.handledFlushRequestID != flushRequestID {
            context.coordinator.handledFlushRequestID = flushRequestID
            context.coordinator.flushDrawing(from: uiView)
        }
        uiView.drawingPolicy = fingerPaints ? .anyInput : .pencilOnly
        uiView.tool = makeTool()
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.flushDrawing(from: uiView)
    }

    private func makeTool() -> PKTool {
        if selectedTool == .eraser {
            return PKEraserTool(.fixedWidthBitmap, width: max(4, min(settings.size, 96)))
        }

        let color = UIColor(hex: colorHex).withAlphaComponent(CGFloat(settings.opacity))
        let width = max(1, settings.size)
        let inkType: PKInkingTool.InkType
        switch selectedTool {
        case .marker, .watercolor:
            inkType = .marker
        case .crayon:
            inkType = .pencil
        case .eraser, .fillBucket:
            inkType = .pen
        }
        return PKInkingTool(inkType, color: color, width: width)
    }

    private static func drawingSummary(_ drawing: PKDrawing) -> String {
        "strokes=\(drawing.strokes.count) bounds=\(format(drawing.bounds))"
    }

    private static func format(_ rect: CGRect) -> String {
        guard !rect.isNull, !rect.isInfinite else { return "none" }
        return "origin=(\(format(rect.origin.x)), \(format(rect.origin.y))) size=(\(format(rect.size.width)), \(format(rect.size.height)))"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, FreehandEraserTouchDelegate {
        var parent: FreehandCanvasRepresentable
        var appliedExternalRevision = 0
        var handledFlushRequestID = 0
        var isApplyingExternalDrawing = false
        private var idleSyncTask: Task<Void, Never>?
        private var hasPendingCanvasDrawingChange = false
        private var pigmentEraserSamples: [StrokeSample] = []
        private var isPigmentEraserActive = false

        init(parent: FreehandCanvasRepresentable) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            CanvasPerformanceProbe.count(.pencilKitDelegateSync)
            hasPendingCanvasDrawingChange = true
            recordFreehandEvent(
                "freehand drawing changed \(FreehandCanvasRepresentable.drawingSummary(canvasView.drawing)) tool=\(parent.selectedTool.rawValue) color=\(parent.colorHex)",
                throttleKey: "freehand.changed",
                minimumInterval: 0.25
            )
            idleSyncTask?.cancel()
            idleSyncTask = Task { [weak self, weak canvasView] in
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard !Task.isCancelled, let self, let canvasView else { return }
                await MainActor.run {
                    self.flushDrawing(from: canvasView)
                }
            }
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            recordFreehandEvent(
                "freehand tool ended \(FreehandCanvasRepresentable.drawingSummary(canvasView.drawing)) tool=\(parent.selectedTool.rawValue) color=\(parent.colorHex)"
            )
            flushDrawing(from: canvasView)
        }

        func flushDrawing(from canvasView: PKCanvasView) {
            idleSyncTask?.cancel()
            guard hasPendingCanvasDrawingChange else { return }
            recordFreehandEvent(
                "freehand flushed \(FreehandCanvasRepresentable.drawingSummary(canvasView.drawing))"
            )
            hasPendingCanvasDrawingChange = false
            parent.onDrawingChanged(canvasView.drawing)
        }

        func handleEraserTouchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView) {
            guard parent.selectedTool == .eraser else { return }
            let samples = strokeSamples(from: touches, with: event, in: canvasView)
            guard let firstSample = samples.first else { return }
            pigmentEraserSamples = [firstSample]
            isPigmentEraserActive = parent.onPigmentEraserBegan(pigmentEraserSamples)
            if isPigmentEraserActive, samples.count > 1 {
                appendPigmentEraserSamples(Array(samples.dropFirst()))
                _ = parent.onPigmentEraserChanged(pigmentEraserSamples)
            }
        }

        func handleEraserTouchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView) {
            guard parent.selectedTool == .eraser, isPigmentEraserActive else { return }
            appendPigmentEraserSamples(strokeSamples(from: touches, with: event, in: canvasView))
            _ = parent.onPigmentEraserChanged(pigmentEraserSamples)
        }

        func handleEraserTouchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView) {
            guard parent.selectedTool == .eraser, isPigmentEraserActive else {
                resetPigmentEraser()
                return
            }
            appendPigmentEraserSamples(strokeSamples(from: touches, with: event, in: canvasView))
            if pigmentEraserSamples.count > 1 {
                _ = parent.onPigmentEraserEnded(pigmentEraserSamples)
            } else {
                parent.onPigmentEraserCancelled()
            }
            resetPigmentEraser()
        }

        func handleEraserTouchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView) {
            guard isPigmentEraserActive else {
                resetPigmentEraser()
                return
            }
            parent.onPigmentEraserCancelled()
            resetPigmentEraser()
        }

        private func appendPigmentEraserSamples(_ samples: [StrokeSample]) {
            for sample in samples {
                guard pigmentEraserSamples.last != sample else { continue }
                pigmentEraserSamples.append(sample)
            }
        }

        private func resetPigmentEraser() {
            pigmentEraserSamples = []
            isPigmentEraserActive = false
        }

        private func strokeSamples(from touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView) -> [StrokeSample] {
            let allSamples = touches.flatMap { touch -> [StrokeSample] in
                let touchesForSample = event?.coalescedTouches(for: touch) ?? [touch]
                return touchesForSample.compactMap { strokeSample(for: $0, in: canvasView) }
            }
            return allSamples.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
        }

        private func strokeSample(for touch: UITouch, in canvasView: UIView) -> StrokeSample? {
            let point = touch.location(in: canvasView)
            guard canvasView.bounds.insetBy(dx: -24, dy: -24).contains(point) else { return nil }
            let normalizedForce: Double?
            if touch.maximumPossibleForce > 0 {
                normalizedForce = Double(touch.force / touch.maximumPossibleForce)
            } else {
                normalizedForce = nil
            }
            return StrokeSample(
                point: point,
                timestamp: touch.timestamp,
                force: normalizedForce,
                altitude: touch.type == .pencil ? Double(touch.altitudeAngle) : nil,
                azimuth: touch.type == .pencil ? Double(touch.azimuthAngle(in: canvasView)) : nil
            )
        }

        func recordFreehandEvent(
            _ message: String,
            throttleKey: String? = nil,
            minimumInterval: TimeInterval = 0
        ) {
            parent.onDebugEvent(message, throttleKey, minimumInterval)
        }
    }
}

private protocol FreehandEraserTouchDelegate: AnyObject {
    func handleEraserTouchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView)
    func handleEraserTouchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView)
    func handleEraserTouchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView)
    func handleEraserTouchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?, in canvasView: UIView)
}

private final class FreehandPKCanvasView: PKCanvasView {
    weak var eraserTouchDelegate: FreehandEraserTouchDelegate?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        eraserTouchDelegate?.handleEraserTouchesBegan(touches, with: event, in: self)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        eraserTouchDelegate?.handleEraserTouchesMoved(touches, with: event, in: self)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        eraserTouchDelegate?.handleEraserTouchesEnded(touches, with: event, in: self)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        eraserTouchDelegate?.handleEraserTouchesCancelled(touches, with: event, in: self)
        super.touchesCancelled(touches, with: event)
    }
}

private struct CanvasInteractionOverlay: UIViewRepresentable {
    var selectedTool: ToolType
    var colorHex: String
    var toolSettings: ToolSettings
    var fingerPaints: Bool
    var isEyedropperActive: Bool
    var liveStrokeSeed: UInt64?
    var fillLayerImage: UIImage?
    var lineArtImage: UIImage?
    var canvasSize: CGSize
    var documentSize: CGSize
    var viewportSize: CGSize
    var viewport: CanvasViewport
    var onViewportChanged: (CanvasViewport) -> Void
    var onViewportCommitted: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onToggleFocus: () -> Void
    var onFit: () -> Void
    var onFill: (CGPoint) -> Void
    var onEyedropper: (CGPoint) -> Void
    var onStrokeBegan: ([StrokeSample]) -> Bool
    var onStrokeChanged: ([StrokeSample]) -> Bool
    var onStrokeEnded: ([StrokeSample]) -> Bool
    var onStrokeCancelled: () -> Void
    var onDebugInput: (CanvasDebugInput) -> Void
    var liveStrokeClip: ([StrokeSample]) -> StrokeRenderClip?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CanvasInteractionUIView {
        let view = CanvasInteractionUIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isMultipleTouchEnabled = true
        view.isAccessibilityElement = false
        view.coordinator = context.coordinator
        view.updatePreviewConfiguration(previewConfiguration)
        view.updateCommittedPigmentImage(fillLayerImage)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator
        view.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)

        let undoTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleUndoTap(_:)))
        undoTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        undoTap.numberOfTouchesRequired = 2
        undoTap.delegate = context.coordinator
        view.addGestureRecognizer(undoTap)
        tap.require(toFail: undoTap)

        let redoTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRedoTap(_:)))
        redoTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        redoTap.numberOfTouchesRequired = 3
        redoTap.delegate = context.coordinator
        view.addGestureRecognizer(redoTap)
        tap.require(toFail: redoTap)

        let focusTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleFocusTap(_:)))
        focusTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        focusTap.numberOfTouchesRequired = 4
        focusTap.delegate = context.coordinator
        view.addGestureRecognizer(focusTap)
        tap.require(toFail: focusTap)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: CanvasInteractionUIView, context: Context) {
        context.coordinator.parent = self
        uiView.coordinator = context.coordinator
        uiView.updatePreviewConfiguration(previewConfiguration)
        uiView.updateCommittedPigmentImage(fillLayerImage)
    }

    private var previewConfiguration: LiveStrokePreviewConfiguration {
        LiveStrokePreviewConfiguration(
            tool: selectedTool,
            colorHex: colorHex,
            size: toolSettings.size,
            opacity: selectedTool == .eraser ? 1 : CGFloat(toolSettings.opacity),
            seed: liveStrokeSeed ?? 0,
            lineArtImage: lineArtImage,
            viewport: viewport,
            canvasSize: canvasSize,
            documentSize: documentSize,
            pigmentBitmapSize: fillLayerImage?.size ?? documentSize,
            viewportSize: viewportSize
        )
    }

    enum InteractionMode {
        case idle
        case drawing
        case viewportPan
        case pinchZoom
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CanvasInteractionOverlay
        private var panStartOffset = CGSize.zero
        private var pinchStartScale = CanvasViewport.minimumScale
        private var pinchStartOffset = CGSize.zero
        private var strokeSamples: [StrokeSample] = []
        private weak var previewView: CanvasInteractionUIView?
        private var lockedMode: InteractionMode = .idle
        private var workingViewport: CanvasViewport?
        private var pencilSequenceNumber = 0
        private var lastPencilSample: (point: CGPoint, timestamp: TimeInterval)?
        private var currentStrokeClip: StrokeRenderClip?

        init(parent: CanvasInteractionOverlay) {
            self.parent = parent
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            let viewportPoint = recognizer.location(in: recognizer.view)
            let canvasPoint = canvasPoint(for: viewportPoint)
            emitInput(
                phase: .tap,
                input: .direct,
                viewportPoint: viewportPoint,
                canvasPoint: canvasPoint,
                detail: parent.isEyedropperActive ? "eyedropper tap" : (parent.selectedTool == .fillBucket ? "fill tap" : "tap ignored for tool=\(parent.selectedTool.rawValue)")
            )
            if parent.isEyedropperActive,
               let canvasPoint {
                parent.onEyedropper(canvasPoint)
                return
            }
            guard parent.selectedTool == .fillBucket,
                  let canvasPoint else {
                return
            }
            parent.onFill(canvasPoint)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onFit()
        }

        @objc func handleUndoTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onUndo()
        }

        @objc func handleRedoTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onRedo()
        }

        @objc func handleFocusTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onToggleFocus()
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                let viewportPoint = recognizer.location(in: recognizer.view)
                if parent.selectedTool == .fillBucket && recognizer.numberOfTouches < 2 {
                    lockedMode = .idle
                    if let canvasPoint = canvasPoint(for: viewportPoint) {
                        parent.onFill(canvasPoint)
                    }
                    #if DEBUG
                    AppLog.trace(AppLog.canvas, "pan began: touches=\(recognizer.numberOfTouches), mode=fill")
                    #endif
                } else if recognizer.numberOfTouches >= 2 {
                    lockedMode = .viewportPan
                    panStartOffset = activeViewport.offset
                    #if DEBUG
                    AppLog.trace(AppLog.canvas, "pan began: touches=\(recognizer.numberOfTouches), mode=viewportPan")
                    #endif
                } else if parent.selectedTool != .fillBucket, parent.fingerPaints {
                    lockedMode = .drawing
                    #if DEBUG
                    AppLog.trace(AppLog.canvas, "pan began: touches=\(recognizer.numberOfTouches), mode=drawing, tool=\(parent.selectedTool.rawValue)")
                    #endif
                    handleFingerStrokeBegan(recognizer)
                } else {
                    lockedMode = .viewportPan
                    panStartOffset = activeViewport.offset
                }
                emitInput(
                    phase: .panBegan,
                    input: .gesture,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint(for: viewportPoint),
                    sampleCount: recognizer.numberOfTouches,
                    detail: "mode=\(lockedMode)"
                )
            case .changed:
                switch lockedMode {
                case .viewportPan:
                    handleViewportPanChanged(recognizer)
                case .drawing:
                    handleFingerStrokeMoved(recognizer)
                default:
                    break
                }
            case .ended:
                #if DEBUG
                AppLog.trace(AppLog.canvas, "pan ended: mode=\(lockedMode)")
                #endif
                let viewportPoint = recognizer.location(in: recognizer.view)
                emitInput(
                    phase: lockedMode == .drawing ? .fingerEnded : .panEnded,
                    input: .gesture,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint(for: viewportPoint),
                    sampleCount: recognizer.numberOfTouches,
                    detail: "mode=\(lockedMode)"
                )
                switch lockedMode {
                case .viewportPan:
                    handleViewportPanEnded(recognizer)
                case .drawing:
                    endStroke(at: recognizer.location(in: recognizer.view))
                default:
                    break
                }
                resetInteractionMode()
            case .cancelled, .failed:
                #if DEBUG
                AppLog.trace(AppLog.canvas, "pan cancelled/failed: mode=\(lockedMode)")
                #endif
                let viewportPoint = recognizer.location(in: recognizer.view)
                emitInput(
                    phase: .panEnded,
                    input: .gesture,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint(for: viewportPoint),
                    sampleCount: recognizer.numberOfTouches,
                    detail: "cancelled mode=\(lockedMode)"
                )
                switch lockedMode {
                case .viewportPan:
                    parent.onViewportCommitted()
                case .drawing:
                    cancelStroke()
                default:
                    break
                }
                resetInteractionMode()
            default:
                break
            }
        }

        private func handleFingerStrokeBegan(_ recognizer: UIPanGestureRecognizer) {
            let viewportPoint = recognizer.location(in: recognizer.view)
            emitInput(
                phase: .fingerBegan,
                input: .direct,
                viewportPoint: viewportPoint,
                canvasPoint: canvasPoint(for: viewportPoint),
                sampleCount: recognizer.numberOfTouches,
                detail: "finger stroke began"
            )
            beginStroke(at: recognizer.location(in: recognizer.view), in: recognizer.view)
        }

        private func handleFingerStrokeMoved(_ recognizer: UIPanGestureRecognizer) {
            let viewportPoint = recognizer.location(in: recognizer.view)
            emitInput(
                phase: .fingerMoved,
                input: .direct,
                viewportPoint: viewportPoint,
                canvasPoint: canvasPoint(for: viewportPoint),
                sampleCount: strokeSamples.count,
                detail: "finger stroke moved"
            )
            appendStrokePoint(viewportPoint, in: recognizer.view)
        }

        private func handleViewportPanChanged(_ recognizer: UIPanGestureRecognizer) {
            var nextViewport = activeViewport
            let translation = recognizer.translation(in: recognizer.view)
            nextViewport.updateOffset(
                from: panStartOffset,
                translation: CGSize(width: translation.x, height: translation.y),
                canvasSize: parent.canvasSize,
                viewportSize: parent.viewportSize
            )
            workingViewport = nextViewport
            parent.onViewportChanged(nextViewport)
            let viewportPoint = recognizer.location(in: recognizer.view)
            emitInput(
                phase: .fingerMoved,
                input: .gesture,
                viewportPoint: viewportPoint,
                canvasPoint: canvasPoint(for: viewportPoint),
                sampleCount: recognizer.numberOfTouches,
                detail: "viewport pan changed translation=(\(Int(translation.x)),\(Int(translation.y)))"
            )
        }

        private func handleViewportPanEnded(_ recognizer: UIPanGestureRecognizer) {
            var nextViewport = activeViewport
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)
            nextViewport.settleOffset(
                from: panStartOffset,
                translation: CGSize(width: translation.x, height: translation.y),
                velocity: CGSize(width: velocity.x, height: velocity.y),
                canvasSize: parent.canvasSize,
                viewportSize: parent.viewportSize
            )
            workingViewport = nextViewport
            animateViewportChange(nextViewport)
            parent.onViewportCommitted()
            workingViewport = nil
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                lockedMode = .pinchZoom
                cancelStroke()
                pinchStartScale = activeViewport.scale
                pinchStartOffset = activeViewport.offset
                #if DEBUG
                AppLog.trace(AppLog.canvas, "pinch began: scale=\(activeViewport.scale), mode=pinchZoom")
                #endif
                let viewportPoint = recognizer.location(in: recognizer.view)
                emitInput(
                    phase: .pinchBegan,
                    input: .gesture,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint(for: viewportPoint),
                    sampleCount: recognizer.numberOfTouches,
                    detail: "scale=\(recognizer.scale)"
                )
            case .changed:
                var nextViewport = activeViewport
                nextViewport.updateScale(
                    from: pinchStartScale,
                    baseOffset: pinchStartOffset,
                    magnification: recognizer.scale,
                    anchor: recognizer.location(in: recognizer.view),
                    canvasSize: parent.canvasSize,
                    viewportSize: parent.viewportSize
                )
                workingViewport = nextViewport
                parent.onViewportChanged(nextViewport)
                let viewportPoint = recognizer.location(in: recognizer.view)
                emitInput(
                    phase: .pinchChanged,
                    input: .gesture,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint(for: viewportPoint),
                    sampleCount: recognizer.numberOfTouches,
                    detail: "scale=\(recognizer.scale)"
                )
            case .ended:
                #if DEBUG
                AppLog.trace(AppLog.canvas, "pinch ended: scale=\(workingViewport?.scale ?? activeViewport.scale)")
                #endif
                let viewportPoint = recognizer.location(in: recognizer.view)
                emitInput(
                    phase: .pinchEnded,
                    input: .gesture,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint(for: viewportPoint),
                    sampleCount: recognizer.numberOfTouches,
                    detail: "scale=\(recognizer.scale)"
                )
                var nextViewport = activeViewport
                nextViewport.settleScale(
                    from: pinchStartScale,
                    baseOffset: pinchStartOffset,
                    magnification: recognizer.scale,
                    velocity: recognizer.velocity,
                    anchor: recognizer.location(in: recognizer.view),
                    canvasSize: parent.canvasSize,
                    viewportSize: parent.viewportSize
                )
                workingViewport = nextViewport
                animateViewportChange(nextViewport)
                parent.onViewportCommitted()
                workingViewport = nil
                resetInteractionMode()
            case .cancelled, .failed:
                #if DEBUG
                AppLog.trace(AppLog.canvas, "pinch cancelled/failed")
                #endif
                let viewportPoint = recognizer.location(in: recognizer.view)
                emitInput(
                    phase: .pinchEnded,
                    input: .gesture,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint(for: viewportPoint),
                    sampleCount: recognizer.numberOfTouches,
                    detail: "cancelled scale=\(recognizer.scale)"
                )
                parent.onViewportCommitted()
                workingViewport = nil
                resetInteractionMode()
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            let isPinch = gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
            let isPan = gestureRecognizer is UIPanGestureRecognizer || otherGestureRecognizer is UIPanGestureRecognizer
            if isPinch && isPan && lockedMode == .pinchZoom {
                return true
            }
            return false
        }

        private var activeViewport: CanvasViewport {
            workingViewport ?? parent.viewport
        }

        private func animateViewportChange(_ viewport: CanvasViewport) {
            var transaction = Transaction(animation: .interactiveSpring(response: 0.34, dampingFraction: 0.86))
            transaction.tracksVelocity = true
            withTransaction(transaction) {
                parent.onViewportChanged(viewport)
            }
        }

        private func resetInteractionMode() {
            lockedMode = .idle
            workingViewport = nil
        }

        func beginStroke(at point: CGPoint, in view: UIView?) {
            guard parent.selectedTool != .fillBucket,
                  let canvasPoint = canvasPoint(for: point) else { return }
            strokeSamples = [StrokeSample(point: canvasPoint, timestamp: CACurrentMediaTime())]
            currentStrokeClip = parent.liveStrokeClip(strokeSamples)
            guard parent.onStrokeBegan(strokeSamples) else {
                strokeSamples = []
                currentStrokeClip = nil
                return
            }
            startPreview(in: view)
        }

        func appendStrokePoint(_ point: CGPoint, in view: UIView?) {
            guard parent.selectedTool != .fillBucket,
                  let canvasPoint = canvasPoint(for: point) else { return }
            if strokeSamples.isEmpty {
                guard parent.selectedTool == .eraser else { return }
                strokeSamples = [StrokeSample(point: canvasPoint, timestamp: CACurrentMediaTime())]
                currentStrokeClip = parent.liveStrokeClip(strokeSamples)
                guard parent.onStrokeBegan(strokeSamples) else {
                    strokeSamples = []
                    currentStrokeClip = nil
                    return
                }
                startPreview(in: view)
                return
            }
            strokeSamples.append(StrokeSample(point: canvasPoint, timestamp: CACurrentMediaTime()))
            _ = parent.onStrokeChanged(strokeSamples)
            appendPreview()
        }

        func endStroke(at point: CGPoint?) {
            if let point {
                appendStrokePoint(point, in: previewView)
            }

            let completedSamples = strokeSamples
            if completedSamples.count > 1 {
                _ = parent.onStrokeEnded(completedSamples)
            }
            previewView?.finishPreview()
            strokeSamples = []
            currentStrokeClip = nil
        }

        func cancelStroke() {
            strokeSamples = []
            currentStrokeClip = nil
            previewView?.cancelPreview()
            parent.onStrokeCancelled()
        }

        func beginPencilStroke(with touch: UITouch, in view: UIView) {
            pencilSequenceNumber = 0
            lastPencilSample = nil
            emitTouchInput(phase: .pencilBegan, touch: touch, in: view, sampleCount: 1, coalescedCount: 1, predictedCount: 0, detail: "pencil began")
            if parent.selectedTool == .fillBucket {
                if let canvasPoint = canvasPoint(for: touch.location(in: view)) {
                    parent.onFill(canvasPoint)
                }
                return
            }
            guard parent.selectedTool != .fillBucket,
                  let sample = strokeSample(for: touch, in: view) else { return }
            strokeSamples = [sample]
            currentStrokeClip = parent.liveStrokeClip(strokeSamples)
            guard parent.onStrokeBegan(strokeSamples) else {
                strokeSamples = []
                currentStrokeClip = nil
                return
            }
            startPreview(in: view)
        }

        func appendPencilStroke(with touch: UITouch, in view: UIView, coalescedCount: Int? = nil, predictedCount: Int? = nil) {
            appendPencilStrokes(with: [touch], in: view, coalescedCount: coalescedCount, predictedCount: predictedCount)
        }

        func appendPencilStrokes(with touches: [UITouch], in view: UIView, coalescedCount: Int? = nil, predictedCount: Int? = nil) {
            guard parent.selectedTool != .fillBucket else { return }

            var appendedSample = false
            for touch in touches where touch.type == .pencil {
                emitTouchInput(
                    phase: .pencilMoved,
                    touch: touch,
                    in: view,
                    sampleCount: strokeSamples.count + 1,
                    coalescedCount: coalescedCount,
                    predictedCount: predictedCount,
                    detail: "pencil moved"
                )
                guard let sample = strokeSample(for: touch, in: view) else { continue }
                if strokeSamples.isEmpty {
                    guard parent.selectedTool == .eraser else { continue }
                    strokeSamples = [sample]
                    currentStrokeClip = parent.liveStrokeClip(strokeSamples)
                    guard parent.onStrokeBegan(strokeSamples) else {
                        strokeSamples = []
                        currentStrokeClip = nil
                        continue
                    }
                    startPreview(in: view)
                    continue
                }
                strokeSamples.append(sample)
                appendedSample = true
            }

            if appendedSample {
                _ = parent.onStrokeChanged(strokeSamples)
                appendPreview()
            }
        }

        func endPencilStroke(with touch: UITouch, in view: UIView) {
            emitTouchInput(phase: .pencilEnded, touch: touch, in: view, sampleCount: strokeSamples.count, coalescedCount: 1, predictedCount: 0, detail: "pencil ended")
            appendPencilStroke(with: touch, in: view, coalescedCount: 1, predictedCount: 0)
            let completedSamples = strokeSamples
            if completedSamples.count > 1 {
                _ = parent.onStrokeEnded(completedSamples)
            }
            previewView?.finishPreview()
            strokeSamples = []
            currentStrokeClip = nil
        }

        func emitCancelledPencilStroke(with touch: UITouch, in view: UIView) {
            emitTouchInput(
                phase: .pencilCancelled,
                touch: touch,
                in: view,
                sampleCount: strokeSamples.count,
                coalescedCount: 1,
                predictedCount: 0,
                detail: "pencil cancelled"
            )
        }

        private func startPreview(in view: UIView?) {
            previewView = view as? CanvasInteractionUIView
            previewView?.beginPreview(samples: strokeSamples, clip: currentStrokeClip)
        }

        private func appendPreview() {
            previewView?.appendPreview(samples: strokeSamples, clip: currentStrokeClip)
        }

        private func canvasPoint(for viewportPoint: CGPoint) -> CGPoint? {
            let canvasPoint = parent.viewport.canvasPoint(
                forViewportPoint: viewportPoint,
                canvasSize: parent.canvasSize,
                viewportSize: parent.viewportSize
            )
            guard parent.viewport.containsCanvasPoint(canvasPoint, canvasSize: parent.canvasSize) else {
                return nil
            }
            return canvasPoint
        }

        private func emitTouchInput(
            phase: CanvasDebugInput.Phase,
            touch: UITouch,
            in view: UIView,
            sampleCount: Int?,
            coalescedCount: Int?,
            predictedCount: Int?,
            detail: String
        ) {
            let viewportPoint = touch.location(in: view)
            pencilSequenceNumber += 1
            let previous = lastPencilSample
            let timestamp = touch.timestamp
            let delta: CGSize?
            let distance: CGFloat?
            let velocity: CGFloat?
            if let previous {
                let dx = viewportPoint.x - previous.point.x
                let dy = viewportPoint.y - previous.point.y
                let movement = hypot(dx, dy)
                let dt = max(timestamp - previous.timestamp, 0)
                delta = CGSize(width: dx, height: dy)
                distance = movement
                velocity = dt > 0 ? movement / CGFloat(dt) : nil
            } else {
                delta = nil
                distance = nil
                velocity = nil
            }
            lastPencilSample = (viewportPoint, timestamp)
            let normalizedForce: Double?
            if touch.maximumPossibleForce > 0 {
                normalizedForce = Double(touch.force / touch.maximumPossibleForce)
            } else {
                normalizedForce = nil
            }
            let canvasPoint = canvasPoint(for: viewportPoint)
            let hitRegionID: String?
            if let canvasPoint,
               currentStrokeClip?.path.contains(canvasPoint, using: currentStrokeClip?.fillRule ?? .winding, transform: .identity) == true {
                hitRegionID = "fillable"
            } else {
                hitRegionID = nil
            }
            #if DEBUG
            (view as? CanvasInteractionUIView)?.appendPencilTraceSample(
                viewportPoint: viewportPoint,
                pressure: normalizedForce,
                velocity: velocity,
                hitRegionID: hitRegionID,
                isRejected: canvasPoint == nil
            )
            #endif
            emitInput(
                phase: phase,
                input: .pencil,
                viewportPoint: viewportPoint,
                canvasPoint: canvasPoint,
                sampleCount: sampleCount,
                touchTimestamp: timestamp,
                sequenceNumber: pencilSequenceNumber,
                coalescedCount: coalescedCount,
                predictedCount: predictedCount,
                force: normalizedForce,
                altitude: Double(touch.altitudeAngle),
                azimuth: Double(touch.azimuthAngle(in: view)),
                delta: delta,
                distance: distance,
                velocity: velocity,
                isPredicted: false,
                detail: detail
            )
        }

        private func emitInput(
            phase: CanvasDebugInput.Phase,
            input: CanvasDebugInput.Input,
            viewportPoint: CGPoint?,
            canvasPoint: CGPoint?,
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
            detail: String? = nil
        ) {
            parent.onDebugInput(
                CanvasDebugInput(
                    phase: phase,
                    input: input,
                    viewportPoint: viewportPoint,
                    canvasPoint: canvasPoint,
                    canvasSize: parent.canvasSize,
                    viewportSize: parent.viewportSize,
                    viewport: activeViewport,
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
                    detail: detail
                )
            )
        }

        private func strokeSample(for touch: UITouch, in view: UIView) -> StrokeSample? {
            guard let canvasPoint = canvasPoint(for: touch.location(in: view)) else { return nil }
            let normalizedForce: Double?
            if touch.maximumPossibleForce > 0 {
                normalizedForce = Double(touch.force / touch.maximumPossibleForce)
            } else {
                normalizedForce = nil
            }
            return StrokeSample(
                point: canvasPoint,
                timestamp: touch.timestamp,
                force: normalizedForce,
                altitude: Double(touch.altitudeAngle),
                azimuth: Double(touch.azimuthAngle(in: view))
            )
        }
    }
}

private struct LiveStrokePreviewConfiguration {
    let tool: ToolType
    let colorHex: String
    let size: CGFloat
    let opacity: CGFloat
    let seed: UInt64
    let lineArtImage: UIImage?
    let viewport: CanvasViewport
    let canvasSize: CGSize
    let documentSize: CGSize
    let pigmentBitmapSize: CGSize
    let viewportSize: CGSize

    var viewportStrokeSize: CGFloat {
        size * documentToCanvasScale * viewport.scale
    }

    func previewRasterScale(for renderSize: CGSize) -> CGFloat {
        let documentToViewportScale = documentToCanvasScale * viewport.scale
        guard documentToViewportScale > 0 else { return 1 }
        let preferredScale = min(max(documentToBitmapScale / documentToViewportScale, 1), 3)
        let renderArea = max(renderSize.width * renderSize.height, 1)
        let maximumPreviewPixels: CGFloat = 2_250_000
        let budgetedScale = sqrt(maximumPreviewPixels / renderArea)
        return min(preferredScale, max(1, budgetedScale))
    }

    var minimumSampleDistance: CGFloat {
        switch tool {
        case .crayon:
            return max(1.8, viewportStrokeSize * 0.08)
        case .watercolor:
            return max(2.4, viewportStrokeSize * 0.10)
        case .marker:
            return max(2.0, viewportStrokeSize * 0.075)
        case .eraser:
            return max(2.3, viewportStrokeSize * 0.08)
        case .fillBucket:
            return max(1.8, viewportStrokeSize * 0.07)
        }
    }

    func viewportSample(from sample: StrokeSample) -> StrokeSample {
        StrokeSample(
            point: viewport.viewportPoint(
                forCanvasPoint: sample.cgPoint,
                canvasSize: canvasSize,
                viewportSize: viewportSize
            ),
            timestamp: sample.timestamp,
            force: sample.force,
            altitude: sample.altitude,
            azimuth: sample.azimuth,
            isPredicted: sample.isPredicted
        )
    }

    func viewportClip(from clip: StrokeRenderClip?) -> StrokeRenderClip? {
        guard let clip else { return nil }
        var transform = CGAffineTransform.identity
            .translatedBy(x: viewportSize.width / 2 + viewport.offset.width, y: viewportSize.height / 2 + viewport.offset.height)
            .scaledBy(x: viewport.scale, y: viewport.scale)
            .translatedBy(x: -canvasSize.width / 2, y: -canvasSize.height / 2)
        guard let path = clip.path.copy(using: &transform) else { return nil }
        return StrokeRenderClip(path: path, fillRule: clip.fillRule)
    }

    private var documentToCanvasScale: CGFloat {
        guard documentSize.width > 0, documentSize.height > 0 else {
            return 1
        }
        return min(canvasSize.width / documentSize.width, canvasSize.height / documentSize.height)
    }

    private var documentToBitmapScale: CGFloat {
        guard documentSize.width > 0, documentSize.height > 0 else {
            return 1
        }
        return min(pigmentBitmapSize.width / documentSize.width, pigmentBitmapSize.height / documentSize.height)
    }
}

private final class CanvasInteractionUIView: UIView {
    weak var coordinator: CanvasInteractionOverlay.Coordinator?
    private var previewConfiguration: LiveStrokePreviewConfiguration?
    private var previewImage: UIImage?
    private var pendingPreviewSamples: [StrokeSample] = []
    private var cachedViewportSamples: [StrokeSample] = []
    private var convertedPreviewSampleCount = 0
    private var lastPreviewSampleIsForcedEndpoint = false
    private var activePreviewClip: StrokeRenderClip?
    private var activeViewportClip: StrokeRenderClip?
    private var activePreviewBounds = CGRect.null
    private var needsPreviewRender = false
    private var previewDisplayLink: CADisplayLink?
    private var isWaitingForCommittedPigmentImage = false
    private var clearPreviewTask: Task<Void, Never>?
    private weak var committedPigmentImage: UIImage?
    private var retainedPreviews: [RetainedPreview] = []
    private let maxRetainedPreviews = 8
    #if DEBUG
    private var pencilTraceConfiguration = PencilTraceConfiguration.current
    private var pencilTraceSamples: [PencilTraceSample] = []
    private let maxPencilTraceSamples = 240
    #endif

    func updatePreviewConfiguration(_ configuration: LiveStrokePreviewConfiguration) {
        previewConfiguration = configuration
        if let activePreviewClip {
            activeViewportClip = configuration.viewportClip(from: activePreviewClip)
        }
        #if DEBUG
        pencilTraceConfiguration = PencilTraceConfiguration.current
        #endif
    }

    func updateCommittedPigmentImage(_ image: UIImage?) {
        guard committedPigmentImage !== image else { return }
        committedPigmentImage = image
        if isWaitingForCommittedPigmentImage {
            clearRetainedPreviews()
        }
    }

    func beginPreview(samples: [StrokeSample], clip: StrokeRenderClip?) {
        clearCurrentPreviewState()
        appendPreview(samples: samples, clip: clip)
    }

    func appendPreview(samples: [StrokeSample], clip: StrokeRenderClip?) {
        guard let previewConfiguration, samples.count > 1 else { return }
        if activePreviewClip == nil {
            activePreviewClip = clip
            activeViewportClip = previewConfiguration.viewportClip(from: clip)
        }
        pendingPreviewSamples = samples
        needsPreviewRender = true
        schedulePreviewRender()
    }

    @objc private func renderPendingPreviewFrame() {
        guard needsPreviewRender else {
            previewDisplayLink?.isPaused = true
            return
        }
        needsPreviewRender = false
        renderPreview(samples: pendingPreviewSamples)
        if !needsPreviewRender {
            previewDisplayLink?.isPaused = true
        }
    }

    private func renderPreview(samples: [StrokeSample]) {
        guard let previewConfiguration, samples.count > 1 else { return }
        updateCachedViewportSamples(from: samples, configuration: previewConfiguration)
        guard cachedViewportSamples.count > 1 else { return }

        let previousBounds = activePreviewBounds
        activePreviewBounds = previewBounds(
            for: cachedViewportSamples,
            strokeSize: previewConfiguration.viewportStrokeSize
        ).integral

        guard activePreviewBounds.width > 1, activePreviewBounds.height > 1 else { return }

        let format = UIGraphicsImageRendererFormat()
        format.scale = previewConfiguration.previewRasterScale(for: activePreviewBounds.size)
        format.opaque = false
        format.preferredRange = .standard
        previewImage = CanvasPerformanceProbe.measure(.cleanPreviewRender) {
            UIGraphicsImageRenderer(size: activePreviewBounds.size, format: format).image { context in
                context.cgContext.translateBy(x: -activePreviewBounds.minX, y: -activePreviewBounds.minY)
                let mask = activeViewportClip.map { RegionMask(regionID: "preview", path: $0.path, fillRule: $0.fillRule, image: UIImage()) }
                if previewConfiguration.tool == .eraser {
                    drawEraserPreview(
                        samples: cachedViewportSamples,
                        strokeSize: previewConfiguration.viewportStrokeSize,
                        mask: mask,
                        in: context.cgContext
                    )
                } else {
                    let stroke = PigmentStroke(
                        tool: previewConfiguration.tool,
                        colorHex: previewConfiguration.colorHex,
                        opacity: Double(previewConfiguration.opacity),
                        size: Double(previewConfiguration.viewportStrokeSize),
                        points: cachedViewportSamples.map(\.cgPoint),
                        regionID: nil,
                        seed: previewConfiguration.seed
                    )
                    PigmentStrokeRenderer.render(stroke, in: context.cgContext, mask: mask)
                }
            }
        }

        let invalidatedRect = unionPreviewRects(previousBounds, activePreviewBounds).intersection(bounds)
        if invalidatedRect.isNull || invalidatedRect.isEmpty {
            setNeedsDisplay(bounds)
        } else {
            setNeedsDisplay(invalidatedRect.insetBy(dx: -2, dy: -2))
        }
    }

    func finishPreview() {
        if needsPreviewRender {
            renderPendingPreviewFrame()
        }
        retainCurrentPreview()
        clearCurrentPreviewState()
        clearPreviewTask?.cancel()
        clearPreviewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.clearRetainedPreviews()
        }
    }

    func cancelPreview() {
        clearPreviewTask?.cancel()
        clearPreviewTask = nil
        clearCurrentPreviewState(invalidates: true)
    }

    private func updateCachedViewportSamples(
        from samples: [StrokeSample],
        configuration: LiveStrokePreviewConfiguration
    ) {
        if samples.count < convertedPreviewSampleCount {
            cachedViewportSamples = []
            convertedPreviewSampleCount = 0
            lastPreviewSampleIsForcedEndpoint = false
        }
        guard convertedPreviewSampleCount < samples.count else { return }
        for index in convertedPreviewSampleCount..<samples.count {
            let sample = configuration.viewportSample(from: samples[index])
            if index == samples.count - 1 {
                updateLatestPreviewSample(sample, configuration: configuration)
            } else if shouldAppendPreviewSample(sample, configuration: configuration) {
                cachedViewportSamples.append(sample)
                lastPreviewSampleIsForcedEndpoint = false
            }
        }
        convertedPreviewSampleCount = samples.count
    }

    private func updateLatestPreviewSample(
        _ sample: StrokeSample,
        configuration: LiveStrokePreviewConfiguration
    ) {
        guard let previous = cachedViewportSamples.last else {
            cachedViewportSamples.append(sample)
            lastPreviewSampleIsForcedEndpoint = true
            return
        }

        let dx = sample.cgPoint.x - previous.cgPoint.x
        let dy = sample.cgPoint.y - previous.cgPoint.y
        if hypot(dx, dy) >= configuration.minimumSampleDistance {
            cachedViewportSamples.append(sample)
            lastPreviewSampleIsForcedEndpoint = false
        } else if cachedViewportSamples.count == 1 {
            cachedViewportSamples.append(sample)
            lastPreviewSampleIsForcedEndpoint = true
        } else if lastPreviewSampleIsForcedEndpoint, !cachedViewportSamples.isEmpty {
            cachedViewportSamples[cachedViewportSamples.count - 1] = sample
        } else if cachedViewportSamples.count > 1 {
            cachedViewportSamples[cachedViewportSamples.count - 1] = sample
            lastPreviewSampleIsForcedEndpoint = true
        }
    }

    private func shouldAppendPreviewSample(
        _ sample: StrokeSample,
        configuration: LiveStrokePreviewConfiguration
    ) -> Bool {
        guard let previous = cachedViewportSamples.last else { return true }
        let dx = sample.cgPoint.x - previous.cgPoint.x
        let dy = sample.cgPoint.y - previous.cgPoint.y
        return hypot(dx, dy) >= configuration.minimumSampleDistance
    }

    private func unionPreviewRects(_ rects: CGRect...) -> CGRect {
        rects.reduce(CGRect.null) { partial, rect in
            guard !rect.isNull else { return partial }
            return partial.isNull ? rect : partial.union(rect)
        }
    }

    private func schedulePreviewRender() {
        if previewDisplayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(renderPendingPreviewFrame))
            displayLink.add(to: .main, forMode: .common)
            displayLink.isPaused = true
            previewDisplayLink = displayLink
        }
        previewDisplayLink?.isPaused = false
    }

    private func previewBounds(for samples: [StrokeSample], strokeSize: CGFloat) -> CGRect {
        guard let first = samples.first?.cgPoint else { return .null }
        var rect = CGRect(origin: first, size: .zero)
        for sample in samples.dropFirst() {
            rect = rect.union(CGRect(origin: sample.cgPoint, size: .zero))
        }
        let inset = max(strokeSize * 0.75, 12)
        return rect.insetBy(dx: -inset, dy: -inset).intersection(bounds)
    }

    private func drawEraserPreview(
        samples: [StrokeSample],
        strokeSize: CGFloat,
        mask: RegionMask?,
        in context: CGContext
    ) {
        guard samples.count > 1 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        if let mask {
            context.addPath(mask.path)
            context.clip(using: mask.fillRule)
        }

        context.setBlendMode(.normal)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(strokeSize * 1.2)
        context.setStrokeColor(CanvasSnapshotRenderer.paperColor.cgColor)
        context.beginPath()
        context.move(to: samples[0].cgPoint)
        for sample in samples.dropFirst() {
            context.addLine(to: sample.cgPoint)
        }
        context.strokePath()
    }

    private func retainCurrentPreview() {
        guard let previewImage, !activePreviewBounds.isNull else { return }
        retainedPreviews.append(RetainedPreview(image: previewImage, bounds: activePreviewBounds))
        if retainedPreviews.count > maxRetainedPreviews {
            let removeCount = retainedPreviews.count - maxRetainedPreviews
            let removed = retainedPreviews.prefix(removeCount)
            retainedPreviews.removeFirst(removeCount)
            for preview in removed {
                setNeedsDisplay(preview.bounds.insetBy(dx: -2, dy: -2))
            }
        }
        isWaitingForCommittedPigmentImage = true
        setNeedsDisplay(activePreviewBounds.insetBy(dx: -2, dy: -2))
    }

    private func clearCurrentPreviewState(invalidates: Bool = false) {
        previewDisplayLink?.isPaused = true
        let rect = previewImage == nil ? .null : activePreviewBounds
        previewImage = nil
        pendingPreviewSamples = []
        cachedViewportSamples = []
        convertedPreviewSampleCount = 0
        lastPreviewSampleIsForcedEndpoint = false
        activePreviewClip = nil
        activeViewportClip = nil
        activePreviewBounds = .null
        needsPreviewRender = false
        #if DEBUG
        if !pencilTraceConfiguration.persistsAfterStroke {
            pencilTraceSamples.removeAll()
        }
        #endif
        if invalidates, !rect.isNull {
            setNeedsDisplay(rect.insetBy(dx: -2, dy: -2))
        }
    }

    private func clearOldestRetainedPreview() {
        guard !retainedPreviews.isEmpty else {
            isWaitingForCommittedPigmentImage = false
            return
        }
        let preview = retainedPreviews.removeFirst()
        setNeedsDisplay(preview.bounds.insetBy(dx: -2, dy: -2))
        isWaitingForCommittedPigmentImage = !retainedPreviews.isEmpty
        if retainedPreviews.isEmpty {
            clearPreviewTask?.cancel()
            clearPreviewTask = nil
        }
    }

    private func clearRetainedPreviews() {
        let previews = retainedPreviews
        retainedPreviews = []
        isWaitingForCommittedPigmentImage = false
        for preview in previews {
            setNeedsDisplay(preview.bounds.insetBy(dx: -2, dy: -2))
        }
    }

    deinit {
        previewDisplayLink?.invalidate()
        clearPreviewTask?.cancel()
    }

    override func draw(_ rect: CGRect) {
        for preview in retainedPreviews {
            preview.image.draw(in: preview.bounds)
            drawLineArtOverPreview(in: preview.bounds)
        }
        previewImage?.draw(in: activePreviewBounds)
        if previewImage != nil {
            drawLineArtOverPreview(in: activePreviewBounds)
        }
        #if DEBUG
        drawPencilTrace()
        #endif
    }

    private func drawLineArtOverPreview(in previewBounds: CGRect) {
        guard let previewConfiguration,
              let lineArtImage = previewConfiguration.lineArtImage,
              !previewBounds.isNull,
              let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let artRect = viewportImageRect(for: lineArtImage, configuration: previewConfiguration)
        context.saveGState()
        context.clip(to: previewBounds)
        context.setBlendMode(.multiply)
        lineArtImage.draw(in: artRect)
        context.restoreGState()
    }

    private func viewportImageRect(
        for image: UIImage,
        configuration: LiveStrokePreviewConfiguration
    ) -> CGRect {
        let canvasImageRect = imageRect(
            for: image,
            in: CGRect(origin: .zero, size: configuration.canvasSize)
        )
        let minPoint = configuration.viewport.viewportPoint(
            forCanvasPoint: canvasImageRect.origin,
            canvasSize: configuration.canvasSize,
            viewportSize: configuration.viewportSize
        )
        let maxPoint = configuration.viewport.viewportPoint(
            forCanvasPoint: CGPoint(x: canvasImageRect.maxX, y: canvasImageRect.maxY),
            canvasSize: configuration.canvasSize,
            viewportSize: configuration.viewportSize
        )
        return CGRect(
            x: min(minPoint.x, maxPoint.x),
            y: min(minPoint.y, maxPoint.y),
            width: abs(maxPoint.x - minPoint.x),
            height: abs(maxPoint.y - minPoint.y)
        )
    }

    private func imageRect(for image: UIImage, in bounds: CGRect) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else { return bounds }
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private struct RetainedPreview {
        let image: UIImage
        let bounds: CGRect
    }

    #if DEBUG
    func appendPencilTraceSample(
        viewportPoint: CGPoint,
        pressure: Double?,
        velocity: CGFloat?,
        hitRegionID: String?,
        isRejected: Bool
    ) {
        guard pencilTraceConfiguration.isEnabled else { return }
        let sample = PencilTraceSample(
            viewportPoint: viewportPoint,
            pressure: pressure,
            velocity: velocity,
            color: isRejected ? .systemRed : (hitRegionID == nil ? .systemYellow : .systemGreen)
        )
        pencilTraceSamples.append(sample)
        if pencilTraceSamples.count > maxPencilTraceSamples {
            pencilTraceSamples.removeFirst(pencilTraceSamples.count - maxPencilTraceSamples)
        }
        setNeedsDisplay()
    }

    private func drawPencilTrace() {
        guard pencilTraceConfiguration.isEnabled,
              !pencilTraceSamples.isEmpty,
              let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()
        context.setLineWidth(2)
        context.setLineCap(.round)
        context.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.78).cgColor)
        let path = CGMutablePath()
        path.move(to: pencilTraceSamples[0].viewportPoint)
        for sample in pencilTraceSamples.dropFirst() {
            path.addLine(to: sample.viewportPoint)
        }
        context.addPath(path)
        context.strokePath()

        if pencilTraceConfiguration.showsDots {
            for sample in pencilTraceSamples {
                context.setFillColor(sample.color.withAlphaComponent(0.85).cgColor)
                let radius = CGFloat(2.5 + min((sample.pressure ?? 0) * 4, 4))
                context.fillEllipse(in: CGRect(
                    x: sample.viewportPoint.x - radius,
                    y: sample.viewportPoint.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }
        context.restoreGState()

        guard let latest = pencilTraceSamples.last else { return }
        var labels: [String] = []
        if pencilTraceConfiguration.showsPressure, let pressure = latest.pressure {
            labels.append("p \(String(format: "%.2f", pressure))")
        }
        if pencilTraceConfiguration.showsVelocity, let velocity = latest.velocity {
            labels.append("v \(Int(velocity))")
        }
        guard !labels.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.black.withAlphaComponent(0.55)
        ]
        labels.joined(separator: "  ").draw(
            at: CGPoint(x: latest.viewportPoint.x + 10, y: latest.viewportPoint.y + 10),
            withAttributes: attributes
        )
    }

    private struct PencilTraceConfiguration {
        var isEnabled: Bool
        var showsDots: Bool
        var showsVelocity: Bool
        var showsPressure: Bool
        var persistsAfterStroke: Bool

        static var current: PencilTraceConfiguration {
            PencilTraceConfiguration(
                isEnabled: CanvasDiagnosticsSettings.pencilTraceOverlayEnabled,
                showsDots: CanvasDiagnosticsSettings.pencilSampleDotsEnabled,
                showsVelocity: CanvasDiagnosticsSettings.pencilVelocityEnabled,
                showsPressure: CanvasDiagnosticsSettings.pencilPressureEnabled,
                persistsAfterStroke: CanvasDiagnosticsSettings.persistPencilTrace
            )
        }
    }

    private struct PencilTraceSample {
        let viewportPoint: CGPoint
        let pressure: Double?
        let velocity: CGFloat?
        let color: UIColor
    }
    #endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        coordinator?.beginPencilStroke(with: touch, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
        let predictedCount = event?.predictedTouches(for: touch)?.filter { $0.type == .pencil }.count ?? 0
        coordinator?.appendPencilStrokes(
            with: coalescedTouches.filter { $0.type == .pencil },
            in: self,
            coalescedCount: coalescedTouches.count,
            predictedCount: predictedCount
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        coordinator?.endPencilStroke(with: touch, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.contains(where: { $0.type == .pencil }) else { return }
        if let touch = touches.first(where: { $0.type == .pencil }) {
            coordinator?.emitCancelledPencilStroke(with: touch, in: self)
        }
        coordinator?.cancelStroke()
    }
}

#if DEBUG && SHOW_RENDER_METRICS
private struct CanvasRenderTuningPopover: View {
    let tuning: RenderTuningStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Render Weight")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(SableTheme.ink)

            CanvasRenderTuningSlider(
                title: "Thumbnails",
                value: Binding(
                    get: { tuning.thumbnailStrokeWidth },
                    set: { tuning.thumbnailStrokeWidth = $0 }
                ),
                range: RenderTuningStore.thumbnailStrokeWidthRange
            )

            CanvasRenderTuningSlider(
                title: "Canvas",
                value: Binding(
                    get: { tuning.canvasStrokeWidth },
                    set: { tuning.canvasStrokeWidth = $0 }
                ),
                range: RenderTuningStore.canvasStrokeWidthRange
            )

            Button("Reset") {
                tuning.reset()
            }
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(SableTheme.progressPink)
        }
        .padding(18)
        .frame(width: 300)
        .background(SableTheme.cream)
    }
}

private struct CanvasRenderTuningSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(SableTheme.ink)

                Spacer()

                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(SableTheme.progressPink)
            }

            Slider(value: $value, in: range, step: 0.05)
                .tint(SableTheme.progressPink)
        }
    }
}
#endif

struct ToolIconView: View {
    let tool: ToolType
    let color: Color
    let size: CGFloat
    var pigment: Color? = nil

    var body: some View {
        if tool == .crayon {
            CrayonToolVectorIcon(
                pigment: pigment ?? color,
                linework: color,
                isSelected: true
            )
            .frame(width: size * 1.28, height: size * 1.48)
            .accessibilityHidden(true)
        } else {
            Image(systemName: tool.systemImageName)
                .font(.system(size: size * 0.9, weight: .black))
                .foregroundStyle(color)
                .accessibilityHidden(true)
        }
    }
}

private enum CanvasVisualSystem {
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#101211") : Color(hex: "#F3EBDD")
    }

    static func paper(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#171815") : Color(hex: "#FFF8EA")
    }

    static func paperSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#20211D") : Color(hex: "#F7EEDF")
    }

    static func ink(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#EEE1CF") : Color(hex: "#292620")
    }

    static func mutedInk(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#B8AC9B") : Color(hex: "#746B60")
    }

    static func hairline(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.105)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.52) : Color.black.opacity(0.15)
    }

    static let pigmentCoral = Color(hex: "#C95F62")
    static let pigmentClay = Color(hex: "#B5825B")
    static let pigmentOchre = Color(hex: "#E3AC58")
    static let pigmentMoss = Color(hex: "#8D9270")
    static let pigmentLeaf = Color(hex: "#59624C")
    static let pigmentMauve = Color(hex: "#A67387")
    static let pigmentSlate = Color(hex: "#82A0A6")
}

private struct CanvasPaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(CanvasVisualSystem.background(for: colorScheme))
            )

            let fiberColor = colorScheme == .dark ? Color(hex: "#E5D8C4") : Color(hex: "#7D6957")
            for index in 0..<130 {
                let x = CGFloat(hash(index, salt: 11)) * size.width
                let y = CGFloat(hash(index, salt: 29)) * size.height
                let length = CGFloat(10 + hash(index, salt: 47) * 46)
                let angle = CGFloat(hash(index, salt: 71) * .pi)
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length * 0.24))
                context.stroke(
                    path,
                    with: .color(fiberColor.opacity(colorScheme == .dark ? 0.035 : 0.048)),
                    lineWidth: 0.45
                )
            }

            for index in 0..<76 {
                let x = CGFloat(hash(index, salt: 101)) * size.width
                let y = CGFloat(hash(index, salt: 137)) * size.height
                let side = CGFloat(0.7 + hash(index, salt: 173) * 1.4)
                let rect = CGRect(x: x, y: y, width: side, height: side)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(fiberColor.opacity(colorScheme == .dark ? 0.032 : 0.055))
                )
            }
        }
    }

    private func hash(_ value: Int, salt: Int) -> Double {
        let raw = sin(Double(value * 37 + salt * 19)) * 43758.5453
        return raw - floor(raw)
    }
}

private struct CanvasChromeLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ColoringSessionViewModel
    @Binding var selectedDockToolID: String
    @Binding var showColorTray: Bool
    @Binding var showColorPicker: Bool
    let isDimmed: Bool
    let onBack: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onLayers: () -> Void
    let onSettings: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onResetView: () -> Void
    let onFocus: () -> Void
    let onClear: () -> Void
    let onEyedropper: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = CanvasChromeMetrics(size: proxy.size)

            ZStack {
                VStack(spacing: 0) {
                    CanvasTopBar(
                        title: viewModel.title,
                        progress: viewModel.progress,
                        canUndo: viewModel.canUndo,
                        canRedo: viewModel.canRedo,
                        canSave: viewModel.canSave,
                        hasArtwork: viewModel.hasArtwork,
                        saveLabel: viewModel.saveState.label,
                        onBack: onBack,
                        onUndo: onUndo,
                        onRedo: onRedo,
                        onLayers: onLayers,
                        onSettings: onSettings,
                        onShare: onShare,
                        onSave: onSave,
                        onResetView: onResetView,
                        onFocus: onFocus,
                        onClear: onClear
                    )
                    .frame(maxWidth: metrics.topBarWidth)
                    .padding(.top, metrics.topPadding)
                    .padding(.horizontal, metrics.horizontalPadding)

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        CleanFreeControl(
                            selection: Binding(
                                get: { viewModel.coloringMode },
                                set: { viewModel.selectColoringMode($0) }
                            )
                        )
                        .frame(maxWidth: metrics.dockWidth, alignment: .leading)
                        .padding(.leading, 10)

                        CanvasToolDock(
                            selectedDockToolID: $selectedDockToolID,
                            selectedColorHex: viewModel.selectedColorHex,
                            isColorTrayOpen: showColorTray,
                            onToolSelected: { item in
                                selectedDockToolID = item.id
                                viewModel.selectTool(item.tool)
                            },
                            onPigmentTapped: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                    showColorTray.toggle()
                                }
                            }
                        )
                        .frame(width: metrics.dockWidth, height: metrics.dockHeight)
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.bottom, metrics.bottomPadding)
                }

                CanvasAdjustmentSlider(
                    size: Binding(
                        get: { viewModel.selectedToolSettings.size },
                        set: { viewModel.updateSelectedToolSize($0) }
                    ),
                    opacity: Binding(
                        get: { CGFloat(viewModel.selectedToolSettings.opacity) },
                        set: { viewModel.updateSelectedToolOpacity(Double($0)) }
                    ),
                    supportsSize: viewModel.selectedTool.supportsSizeControl,
                    supportsOpacity: viewModel.selectedTool.supportsOpacityControl
                )
                .frame(width: 62, height: 248)
                .position(x: proxy.size.width - metrics.sliderTrailing, y: proxy.size.height * metrics.sliderYFactor)

                if showColorTray {
                    ColorTray(
                        paletteTitle: "Botanical Set",
                        selectedColorHex: viewModel.selectedColorHex,
                        recentColorHexes: viewModel.recentColorHexes,
                        suggestedSwatches: viewModel.selectedSwatches,
                        onSelectColor: { hex in
                            viewModel.selectColor(hex: hex)
                        },
                        onEyedropper: onEyedropper,
                        onMoreColors: {
                            showColorPicker = true
                        },
                        onClose: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showColorTray = false
                            }
                        }
                    )
                    .frame(width: metrics.trayWidth, height: metrics.trayHeight)
                    .position(
                        x: proxy.size.width - metrics.trayTrailing - metrics.trayWidth / 2,
                        y: proxy.size.height - metrics.bottomPadding - metrics.dockHeight - metrics.trayHeight / 2 - metrics.trayVerticalGap
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                }

                Color.clear
                    .frame(width: 1, height: 1)
                    .position(
                        x: proxy.size.width - metrics.trayTrailing,
                        y: proxy.size.height - metrics.bottomPadding - metrics.dockHeight - 12
                    )
                    .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                        BottomColorWheelView(viewModel: viewModel)
                            .presentationCompactAdaptation(.popover)
                    }
            }
            .opacity(isDimmed ? 0.58 : 1)
            .animation(.easeOut(duration: 0.18), value: isDimmed)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct CanvasChromeMetrics {
    let size: CGSize

    var isLandscape: Bool {
        size.width > size.height
    }

    var horizontalPadding: CGFloat {
        isLandscape ? 32 : 28
    }

    var topPadding: CGFloat {
        isLandscape ? 12 : 18
    }

    var bottomPadding: CGFloat {
        isLandscape ? 18 : 24
    }

    var topBarWidth: CGFloat {
        min(size.width - horizontalPadding * 2, isLandscape ? 820 : 760)
    }

    var dockWidth: CGFloat {
        min(size.width - horizontalPadding * 2, isLandscape ? 580 : 610)
    }

    var dockHeight: CGFloat {
        isLandscape ? 82 : 92
    }

    var sliderTrailing: CGFloat {
        isLandscape ? 60 : 50
    }

    var sliderYFactor: CGFloat {
        isLandscape ? 0.48 : 0.50
    }

    var trayWidth: CGFloat {
        min(size.width - horizontalPadding * 2, isLandscape ? 460 : 500)
    }

    var trayHeight: CGFloat {
        isLandscape ? 248 : 286
    }

    var trayTrailing: CGFloat {
        max(horizontalPadding, (size.width - dockWidth) / 2)
    }

    var trayVerticalGap: CGFloat {
        isLandscape ? 20 : 52
    }
}

private struct CanvasTopBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let progress: Double
    let canUndo: Bool
    let canRedo: Bool
    let canSave: Bool
    let hasArtwork: Bool
    let saveLabel: String
    let onBack: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onLayers: () -> Void
    let onSettings: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onResetView: () -> Void
    let onFocus: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CanvasIconButton(systemName: "chevron.left", label: "Back", action: onBack)
                .accessibilityIdentifier("canvas.back")

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CanvasVisualSystem.ink(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 7) {
                    Text("\(Int((progress * 100).rounded()))% colored")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme))
                        .monospacedDigit()

                    ProgressLine(progress: progress)
                        .frame(width: 48, height: 3)
                }
            }
            .frame(width: 168, alignment: .leading)

            Spacer(minLength: 0)

            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme).opacity(0.78))
                .frame(width: 54, height: 34)

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                CanvasIconButton(systemName: "arrow.uturn.backward", label: "Undo", isEnabled: canUndo, action: onUndo)
                    .accessibilityIdentifier(A11y.Canvas.undo)
                CanvasIconButton(systemName: "arrow.uturn.forward", label: "Redo", isEnabled: canRedo, action: onRedo)
                    .accessibilityIdentifier(A11y.Canvas.redo)
                CanvasIconButton(systemName: "square.stack.3d.up", label: "Layers", action: onLayers)
                    .accessibilityIdentifier("canvas.layers")

                Menu {
                    Button("Save", systemImage: "square.and.arrow.down", action: onSave)
                        .disabled(!canSave)
                    Button("Share", systemImage: "square.and.arrow.up", action: onShare)
                    Button("Fit Artwork", systemImage: "arrow.up.left.and.down.right.magnifyingglass", action: onResetView)
                    Button("Focus Mode", systemImage: "eye.slash", action: onFocus)
                    Button("Palette & Tools", systemImage: "paintpalette", action: onSettings)
                    Button("Clear Artwork", systemImage: "trash", role: .destructive, action: onClear)
                        .disabled(!hasArtwork)
                    Text(saveLabel)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CanvasVisualSystem.ink(for: colorScheme))
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Canvas options")
                .accessibilityIdentifier("canvas.more")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .background(
            Capsule(style: .continuous)
                .fill(CanvasVisualSystem.paper(for: colorScheme).opacity(colorScheme == .dark ? 0.94 : 0.88))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.8)
        }
        .shadow(color: CanvasVisualSystem.shadow(for: colorScheme), radius: 14, x: 0, y: 6)
    }
}

private struct CanvasIconButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let label: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isEnabled ? CanvasVisualSystem.ink(for: colorScheme) : CanvasVisualSystem.mutedInk(for: colorScheme).opacity(0.34))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(CanvasVisualSystem.paperSecondary(for: colorScheme).opacity(colorScheme == .dark ? 0.62 : 0.52))
                )
                .overlay {
                    Circle()
                        .stroke(CanvasVisualSystem.hairline(for: colorScheme).opacity(0.75), lineWidth: 0.7)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

private struct ProgressLine: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(CanvasVisualSystem.hairline(for: colorScheme).opacity(0.72))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(CanvasVisualSystem.pigmentCoral.opacity(colorScheme == .dark ? 0.84 : 0.68))
                        .frame(width: max(3, proxy.size.width * min(max(progress, 0), 1)))
                }
        }
    }
}

private struct CleanFreeControl: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: CanvasColoringMode

    var body: some View {
        HStack(spacing: 2) {
            segment(.clean)
            segment(.free)
        }
        .padding(3)
        .frame(width: 110, height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(CanvasVisualSystem.paper(for: colorScheme).opacity(colorScheme == .dark ? 0.90 : 0.86))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.7)
        }
        .shadow(color: CanvasVisualSystem.shadow(for: colorScheme).opacity(0.55), radius: 9, x: 0, y: 4)
        .accessibilityIdentifier("canvas.cleanFreeToggle")
    }

    private func segment(_ mode: CanvasColoringMode) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                selection = mode
            }
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 10, weight: selection == mode ? .semibold : .medium))
                .foregroundStyle(selection == mode ? CanvasVisualSystem.ink(for: colorScheme) : CanvasVisualSystem.mutedInk(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(selection == mode ? CanvasVisualSystem.paperSecondary(for: colorScheme).opacity(colorScheme == .dark ? 0.88 : 0.96) : .clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.rawValue)
    }
}

private struct CanvasToolDock: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedDockToolID: String
    let selectedColorHex: String
    let isColorTrayOpen: Bool
    let onToolSelected: (CanvasToolDockItem) -> Void
    let onPigmentTapped: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CanvasToolDockItem.items) { item in
                CanvasToolButton(
                    item: item,
                    isSelected: selectedDockToolID == item.id,
                    selectedColorHex: selectedColorHex,
                    action: { onToolSelected(item) }
                )
            }

            Rectangle()
                .fill(CanvasVisualSystem.hairline(for: colorScheme).opacity(0.64))
                .frame(width: 1, height: 56)
                .padding(.leading, 2)

            PigmentWellButton(
                selectedColorHex: selectedColorHex,
                isOpen: isColorTrayOpen,
                action: onPigmentTapped
            )
            .padding(.leading, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(CanvasVisualSystem.paper(for: colorScheme).opacity(colorScheme == .dark ? 0.94 : 0.91))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.85)
        }
        .shadow(color: CanvasVisualSystem.shadow(for: colorScheme), radius: 20, x: 0, y: 9)
    }
}

private struct CanvasToolDockItem: Identifiable, Equatable {
    enum Glyph {
        case crayon
        case watercolor
        case marker
        case eraser
        case fill
    }

    let id: String
    let title: String
    let tool: ToolType
    let glyph: Glyph

    static let defaultID = "watercolor"

    static let items: [CanvasToolDockItem] = [
        CanvasToolDockItem(id: "crayon", title: "Crayon", tool: .crayon, glyph: .crayon),
        CanvasToolDockItem(id: "watercolor", title: "Watercolor", tool: .watercolor, glyph: .watercolor),
        CanvasToolDockItem(id: "marker", title: "Marker", tool: .marker, glyph: .marker),
        CanvasToolDockItem(id: "eraser", title: "Eraser", tool: .eraser, glyph: .eraser),
        CanvasToolDockItem(id: "fill", title: "Fill", tool: .fillBucket, glyph: .fill)
    ]

    static func item(id: String) -> CanvasToolDockItem? {
        items.first { $0.id == id }
    }

    static func primaryID(for tool: ToolType) -> String {
        switch tool {
        case .crayon:
            return "crayon"
        case .watercolor:
            return "watercolor"
        case .marker:
            return "marker"
        case .eraser:
            return "eraser"
        case .fillBucket:
            return "fill"
        }
    }
}

private struct CanvasToolButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: CanvasToolDockItem
    let isSelected: Bool
    let selectedColorHex: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? CanvasVisualSystem.paperSecondary(for: colorScheme).opacity(colorScheme == .dark ? 0.92 : 0.98) : .clear)
                        .frame(width: 48, height: 48)
                        .shadow(color: isSelected ? CanvasVisualSystem.shadow(for: colorScheme).opacity(0.32) : .clear, radius: 7, x: 0, y: 3)

                    CanvasToolGlyph(
                        glyph: item.glyph,
                        pigment: Color(hex: selectedColorHex),
                        isSelected: isSelected
                    )
                    .frame(width: 34, height: 42)
                }

                Text(item.title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? CanvasVisualSystem.ink(for: colorScheme) : CanvasVisualSystem.mutedInk(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(width: 58)
            }
            .frame(width: 62, height: 72)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier(item.tool.accessibilityIdentifier)
    }
}

private struct CrayonToolVectorIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    let pigment: Color
    let linework: Color?
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let ink = linework ?? (colorScheme == .dark ? Color(hex: "#E9DCC9") : Color(hex: "#28241E"))
            let wrapper = colorScheme == .dark ? Color(hex: "#D9C7AD") : Color(hex: "#EFE0C3")
            let wrapperShade = colorScheme == .dark ? Color(hex: "#8D7B66") : Color(hex: "#B8A384")
            let wax = pigment.opacity(colorScheme == .dark ? 0.82 : 0.88)
            let darkWax = colorScheme == .dark ? Color(hex: "#373832") : Color(hex: "#343029")
            let wrapperFold = colorScheme == .dark ? Color(hex: "#6F675C") : Color(hex: "#8D806D")
            let highlight = Color.white.opacity(colorScheme == .dark ? 0.16 : 0.26)
            let lowlight = Color.black.opacity(colorScheme == .dark ? 0.30 : 0.16)

            ZStack {
                if isSelected {
                    Ellipse()
                        .fill(lowlight.opacity(0.26))
                        .frame(width: w * 0.38, height: h * 0.050)
                        .blur(radius: max(0.5, w * 0.018))
                        .offset(x: w * 0.015, y: h * 0.435)

                    Group {
                        RoundedRectangle(cornerRadius: w * 0.025, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        darkWax.opacity(colorScheme == .dark ? 0.82 : 0.92),
                                        darkWax.opacity(colorScheme == .dark ? 0.54 : 0.68),
                                        darkWax.opacity(colorScheme == .dark ? 0.84 : 0.94)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * 0.285, height: h * 0.18)
                            .offset(y: h * 0.350)
                            .overlay {
                                RoundedRectangle(cornerRadius: w * 0.025, style: .continuous)
                                    .stroke(ink.opacity(colorScheme == .dark ? 0.34 : 0.28), lineWidth: max(0.55, w * 0.015))
                                    .frame(width: w * 0.285, height: h * 0.18)
                                    .offset(y: h * 0.350)
                            }

                        RoundedRectangle(cornerRadius: w * 0.020, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        wrapperShade.opacity(colorScheme == .dark ? 0.58 : 0.46),
                                        wrapper,
                                        wrapper.opacity(0.98),
                                        wrapperShade.opacity(colorScheme == .dark ? 0.46 : 0.34)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * 0.390, height: h * 0.49)
                            .offset(y: h * 0.105)
                            .overlay {
                                RoundedRectangle(cornerRadius: w * 0.020, style: .continuous)
                                    .stroke(ink.opacity(colorScheme == .dark ? 0.42 : 0.32), lineWidth: max(0.56, w * 0.015))
                                    .frame(width: w * 0.390, height: h * 0.49)
                                    .offset(y: h * 0.105)
                            }

                        CrayonPaperLines(lineColor: ink.opacity(colorScheme == .dark ? 0.22 : 0.17))
                            .frame(width: w * 0.31, height: h * 0.36)
                            .offset(y: h * 0.10)

                        RoundedRectangle(cornerRadius: w * 0.012, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        wax.opacity(0.58),
                                        wax,
                                        wax.opacity(0.50)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * 0.410, height: h * 0.045)
                            .offset(y: -h * 0.035)
                            .overlay {
                                RoundedRectangle(cornerRadius: w * 0.012, style: .continuous)
                                    .stroke(ink.opacity(0.22), lineWidth: max(0.40, w * 0.011))
                                    .frame(width: w * 0.410, height: h * 0.045)
                                    .offset(y: -h * 0.035)
                            }

                        RoundedRectangle(cornerRadius: w * 0.018, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        wrapperFold.opacity(0.74),
                                        wrapperFold.opacity(0.34),
                                        wrapperFold.opacity(0.66)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * 0.325, height: h * 0.085)
                            .offset(y: -h * 0.165)

                        CrayonTipShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        wax.opacity(0.54),
                                        wax,
                                        wax.opacity(0.44)
                                    ],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                            .frame(width: w * 0.365, height: h * 0.215)
                            .offset(y: -h * 0.335)
                            .overlay {
                                CrayonTipShape()
                                    .stroke(ink.opacity(colorScheme == .dark ? 0.38 : 0.30), lineWidth: max(0.55, w * 0.014))
                                    .frame(width: w * 0.365, height: h * 0.215)
                                    .offset(y: -h * 0.335)
                            }

                        CrayonWaxRidges(lineColor: highlight.opacity(0.62), shadowColor: ink.opacity(0.16))
                            .frame(width: w * 0.365, height: h * 0.215)
                            .clipShape(CrayonTipShape())
                            .offset(y: -h * 0.335)

                        Capsule()
                            .fill(highlight.opacity(0.50))
                            .frame(width: w * 0.024, height: h * 0.62)
                            .offset(x: -w * 0.095, y: h * 0.055)
                    }
                    .rotationEffect(.degrees(-0.5), anchor: .center)
                } else {
                    CrayonOutlineGlyph(lineColor: ink.opacity(colorScheme == .dark ? 0.58 : 0.48))
                        .frame(width: w, height: h)
                }
            }
            .frame(width: w, height: h)
        }
    }
}

private struct CrayonOutlineGlyph: View {
    let lineColor: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let stroke = max(0.85, w * 0.030)

            ZStack {
                RoundedRectangle(cornerRadius: w * 0.025, style: .continuous)
                    .stroke(lineColor, lineWidth: stroke)
                    .frame(width: w * 0.285, height: h * 0.18)
                    .offset(y: h * 0.350)

                RoundedRectangle(cornerRadius: w * 0.020, style: .continuous)
                    .stroke(lineColor.opacity(0.90), lineWidth: stroke)
                    .frame(width: w * 0.390, height: h * 0.49)
                    .offset(y: h * 0.105)

                RoundedRectangle(cornerRadius: w * 0.012, style: .continuous)
                    .stroke(lineColor.opacity(0.76), lineWidth: stroke * 0.72)
                    .frame(width: w * 0.410, height: h * 0.045)
                    .offset(y: -h * 0.035)

                RoundedRectangle(cornerRadius: w * 0.018, style: .continuous)
                    .stroke(lineColor.opacity(0.78), lineWidth: stroke * 0.82)
                    .frame(width: w * 0.325, height: h * 0.085)
                    .offset(y: -h * 0.165)

                CrayonTipShape()
                    .stroke(lineColor, lineWidth: stroke)
                    .frame(width: w * 0.365, height: h * 0.215)
                    .offset(y: -h * 0.335)

                CrayonWaxRidges(lineColor: lineColor.opacity(0.34), shadowColor: lineColor.opacity(0.24))
                    .frame(width: w * 0.365, height: h * 0.215)
                    .clipShape(CrayonTipShape())
                    .offset(y: -h * 0.335)
            }
            .rotationEffect(.degrees(-0.5), anchor: .center)
        }
    }
}

private struct CrayonTipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let point = CGPoint(x: rect.midX, y: rect.minY)
        let rightBase = CGPoint(x: rect.minX + rect.width * 0.70, y: rect.maxY)
        let leftBase = CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY)

        path.move(to: point)
        path.addLine(to: rightBase)
        path.addLine(to: leftBase)
        path.closeSubpath()
        return path
    }
}

private struct CrayonWaxRidges: View {
    let lineColor: Color
    let shadowColor: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                ForEach(0..<2, id: \.self) { index in
                    Path { path in
                        let t = CGFloat(index)
                        path.move(to: CGPoint(x: w * (0.36 + t * 0.10), y: h * (0.44 + t * 0.16)))
                        path.addLine(
                            to: CGPoint(x: w * (0.58 + t * 0.030), y: h * (0.37 + t * 0.15))
                        )
                    }
                    .stroke(index.isMultiple(of: 2) ? lineColor : shadowColor, lineWidth: max(0.35, w * 0.012))
                }
            }
        }
    }
}

private struct CrayonPaperLines: View {
    let lineColor: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.28, y: h * 0.25))
                    path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.21))
                    path.move(to: CGPoint(x: w * 0.26, y: h * 0.70))
                    path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.66))
                }
                .stroke(lineColor, lineWidth: max(0.35, w * 0.012))

                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(lineColor.opacity(index.isMultiple(of: 2) ? 0.36 : 0.24))
                        .frame(width: max(0.3, w * 0.011), height: h * 0.44)
                        .offset(x: w * (-0.10 + CGFloat(index) * 0.20), y: h * 0.04)
                }
            }
        }
    }
}

private struct CanvasToolGlyph: View {
    @Environment(\.colorScheme) private var colorScheme
    let glyph: CanvasToolDockItem.Glyph
    let pigment: Color
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let ink = colorScheme == .dark ? Color(hex: "#D8CAB8") : Color(hex: "#25231E")
            let metal = colorScheme == .dark ? Color(hex: "#998F80") : Color(hex: "#C8BBA9")
            let paper = CanvasVisualSystem.paperSecondary(for: colorScheme)
            let accent = pigment

            ZStack {
                if isSelected {
                    switch glyph {
                    case .crayon:
                        CrayonToolVectorIcon(
                            pigment: pigment,
                            linework: ink,
                            isSelected: true
                        )
                        .frame(width: w, height: h)

                    case .watercolor:
                        WatercolorBrushToolIcon(
                            selectedColor: pigment,
                            isSelected: true
                        )
                        .frame(width: w, height: h)

                    case .marker:
                        RoundedRectangle(cornerRadius: w * 0.10)
                            .fill(ink)
                            .frame(width: w * 0.28, height: h * 0.72)
                            .offset(y: h * 0.10)
                        Path { path in
                            path.move(to: CGPoint(x: w * 0.41, y: h * 0.05))
                            path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.05))
                            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.23))
                            path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.23))
                            path.closeSubpath()
                        }
                        .fill(metal)
                        Capsule()
                            .fill(accent.opacity(0.78))
                            .frame(width: w * 0.25, height: h * 0.08)
                            .offset(y: h * 0.26)

                    case .eraser:
                        RoundedRectangle(cornerRadius: w * 0.13, style: .continuous)
                            .fill(paper.opacity(colorScheme == .dark ? 0.68 : 0.86))
                            .frame(width: w * 0.38, height: h * 0.58)
                            .rotationEffect(.degrees(4))
                            .overlay {
                                RoundedRectangle(cornerRadius: w * 0.13, style: .continuous)
                                    .stroke(metal.opacity(0.72), lineWidth: 1)
                                    .frame(width: w * 0.38, height: h * 0.58)
                                    .rotationEffect(.degrees(4))
                            }

                    case .fill:
                        RoundedRectangle(cornerRadius: w * 0.08)
                            .fill(ink)
                            .frame(width: w * 0.36, height: h * 0.52)
                            .rotationEffect(.degrees(-7))
                            .offset(y: h * 0.12)
                        Path { path in
                            path.move(to: CGPoint(x: w * 0.64, y: h * 0.22))
                            path.addCurve(to: CGPoint(x: w * 0.76, y: h * 0.45), control1: CGPoint(x: w * 0.72, y: h * 0.31), control2: CGPoint(x: w * 0.78, y: h * 0.37))
                            path.addCurve(to: CGPoint(x: w * 0.63, y: h * 0.55), control1: CGPoint(x: w * 0.76, y: h * 0.52), control2: CGPoint(x: w * 0.70, y: h * 0.58))
                            path.closeSubpath()
                        }
                        .fill(accent.opacity(0.76))
                    }
                } else {
                    CanvasToolOutlineGlyph(
                        glyph: glyph,
                        lineColor: CanvasVisualSystem.mutedInk(for: colorScheme).opacity(colorScheme == .dark ? 0.54 : 0.46)
                    )
                    .frame(width: w, height: h)
                }
            }
            .frame(width: w, height: h)
        }
    }
}

private struct CanvasToolOutlineGlyph: View {
    let glyph: CanvasToolDockItem.Glyph
    let lineColor: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let stroke = max(1, min(w, h) * 0.042)

            ZStack {
                switch glyph {
                case .crayon:
                    CrayonOutlineGlyph(lineColor: lineColor)
                        .frame(width: w, height: h)

                case .watercolor:
                    WatercolorBrushToolIcon(
                        selectedColor: .clear,
                        isSelected: false
                    )
                    .frame(width: w, height: h)

                case .marker:
                    RoundedRectangle(cornerRadius: w * 0.10)
                        .stroke(lineColor, lineWidth: stroke)
                        .frame(width: w * 0.28, height: h * 0.72)
                        .offset(y: h * 0.10)
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.41, y: h * 0.05))
                        path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.05))
                        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.23))
                        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.23))
                        path.closeSubpath()
                    }
                    .stroke(lineColor, lineWidth: stroke)
                    Capsule()
                        .stroke(lineColor.opacity(0.70), lineWidth: stroke * 0.78)
                        .frame(width: w * 0.25, height: h * 0.08)
                        .offset(y: h * 0.26)

                case .eraser:
                    RoundedRectangle(cornerRadius: w * 0.13, style: .continuous)
                        .stroke(lineColor, lineWidth: stroke)
                        .frame(width: w * 0.38, height: h * 0.58)
                        .rotationEffect(.degrees(4))
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.37, y: h * 0.31))
                        path.addLine(to: CGPoint(x: w * 0.63, y: h * 0.31))
                    }
                    .stroke(lineColor.opacity(0.62), lineWidth: stroke * 0.72)
                    .rotationEffect(.degrees(4))

                case .fill:
                    RoundedRectangle(cornerRadius: w * 0.08)
                        .stroke(lineColor, lineWidth: stroke)
                        .frame(width: w * 0.36, height: h * 0.52)
                        .rotationEffect(.degrees(-7))
                        .offset(y: h * 0.12)
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.64, y: h * 0.22))
                        path.addCurve(to: CGPoint(x: w * 0.76, y: h * 0.45), control1: CGPoint(x: w * 0.72, y: h * 0.31), control2: CGPoint(x: w * 0.78, y: h * 0.37))
                        path.addCurve(to: CGPoint(x: w * 0.63, y: h * 0.55), control1: CGPoint(x: w * 0.76, y: h * 0.52), control2: CGPoint(x: w * 0.70, y: h * 0.58))
                        path.closeSubpath()
                    }
                    .stroke(lineColor, lineWidth: stroke)
                }
            }
            .frame(width: w, height: h)
        }
    }
}

private struct PigmentWellButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let selectedColorHex: String
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme))

                ZStack {
                    Circle()
                        .fill(CanvasVisualSystem.paperSecondary(for: colorScheme))
                        .frame(width: 54, height: 54)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.40 : 0.16), radius: 7, x: 0, y: 4)

                    Circle()
                        .stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 1.2)
                        .frame(width: 54, height: 54)

                    Circle()
                        .fill(Color(hex: selectedColorHex))
                        .frame(width: 42, height: 42)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.42), lineWidth: 1.4)
                        }
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.12), radius: 4, x: 0, y: 2)
                }
            }
            .frame(width: 64, height: 74)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open pigment palette")
        .accessibilityIdentifier("canvas.pigmentWell")
    }
}

private struct ColorTray: View {
    @Environment(\.colorScheme) private var colorScheme
    let paletteTitle: String
    let selectedColorHex: String
    let recentColorHexes: [String]
    let suggestedSwatches: [ColorSwatch]
    let onSelectColor: (String) -> Void
    let onEyedropper: () -> Void
    let onMoreColors: () -> Void
    let onClose: () -> Void

    private let fallbackColors = [
        "#C95F62", "#D47C3D", "#E3AC58", "#A4A070", "#59624C",
        "#A67387", "#8C7699", "#82A0A6", "#C7B99F", "#E8DDC7"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Text(paletteTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CanvasVisualSystem.ink(for: colorScheme))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme))
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close palette")
            }
            .frame(height: 38)

            Rectangle()
                .fill(CanvasVisualSystem.hairline(for: colorScheme))
                .frame(height: 0.7)

            HStack(spacing: 18) {
                VStack(spacing: 9) {
                    Text("Current Color")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme))
                    PigmentSwatch(hex: selectedColorHex, size: 70, isSelected: true, action: {})
                    Text(colorName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme))
                        .lineLimit(1)
                }
                .frame(width: 116)

                Rectangle()
                    .fill(CanvasVisualSystem.hairline(for: colorScheme))
                    .frame(width: 0.7)
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 12) {
                    swatchSection(title: "Recent Colors", colors: recentColors)
                    swatchSection(title: "Suggested Palette", colors: suggestedColors)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Rectangle()
                .fill(CanvasVisualSystem.hairline(for: colorScheme))
                .frame(height: 0.7)

            HStack(spacing: 14) {
                Button(action: onEyedropper) {
                    Label("Eyedropper", systemImage: "eyedropper")
                }
                .accessibilityIdentifier("canvas.eyedropper")

                Spacer(minLength: 0)

                Button(action: onMoreColors) {
                    Label("More Colors", systemImage: "paintpalette")
                }
                .accessibilityIdentifier("canvas.moreColors")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(CanvasVisualSystem.ink(for: colorScheme))
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .frame(height: 42)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CanvasVisualSystem.paper(for: colorScheme).opacity(colorScheme == .dark ? 0.98 : 0.96))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.8)
        }
        .shadow(color: CanvasVisualSystem.shadow(for: colorScheme), radius: 22, x: 0, y: 12)
        .accessibilityIdentifier("canvas.colorTray")
    }

    private var recentColors: [String] {
        let colors = recentColorHexes + fallbackColors
        return Array(colors.prefix(10))
    }

    private var suggestedColors: [String] {
        let colors = suggestedSwatches.map(\.hex) + fallbackColors
        return Array(colors.prefix(9))
    }

    private var colorName: String {
        suggestedSwatches.first { $0.hex.caseInsensitiveCompare(selectedColorHex) == .orderedSame }?.name ?? "Pigment"
    }

    private func swatchSection(title: String, colors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme))

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 10), count: 5), alignment: .leading, spacing: 10) {
                ForEach(colors, id: \.self) { hex in
                    PigmentSwatch(hex: hex, size: 22, isSelected: selectedColorHex.caseInsensitiveCompare(hex) == .orderedSame) {
                        onSelectColor(hex)
                    }
                }
            }
        }
    }
}

private struct PigmentSwatch: View {
    @Environment(\.colorScheme) private var colorScheme
    let hex: String
    let size: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .stroke(
                            isSelected ? CanvasVisualSystem.ink(for: colorScheme).opacity(0.58) : CanvasVisualSystem.hairline(for: colorScheme),
                            lineWidth: isSelected ? 1.4 : 0.75
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.10), radius: size > 40 ? 5 : 2, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(hex)")
        .accessibilityIdentifier(A11y.Canvas.color(hex))
    }
}

private struct CanvasAdjustmentSlider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var size: CGFloat
    @Binding var opacity: CGFloat
    let supportsSize: Bool
    let supportsOpacity: Bool

    var body: some View {
        VStack(spacing: 8) {
            CanvasVerticalGauge(
                title: "Size",
                valueText: "\(Int(size.rounded()))",
                range: ToolSettings.sizeRange,
                value: $size,
                isEnabled: supportsSize
            )
            Rectangle()
                .fill(CanvasVisualSystem.hairline(for: colorScheme).opacity(0.54))
                .frame(height: 0.7)
                .padding(.horizontal, 10)
            CanvasVerticalGauge(
                title: "Opacity",
                valueText: "\(Int((opacity * 100).rounded()))%",
                range: ToolSettings.opacityRangeCGFloat,
                value: $opacity,
                isEnabled: supportsOpacity
            )
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CanvasVisualSystem.paper(for: colorScheme).opacity(colorScheme == .dark ? 0.90 : 0.82))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.75)
        }
        .shadow(color: CanvasVisualSystem.shadow(for: colorScheme).opacity(0.72), radius: 15, x: 0, y: 7)
        .accessibilityIdentifier("canvas.adjustmentSliders")
    }
}

private struct CanvasVerticalGauge: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let valueText: String
    let range: ClosedRange<CGFloat>
    @Binding var value: CGFloat
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(valueText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CanvasVisualSystem.ink(for: colorScheme).opacity(isEnabled ? 1 : 0.42))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(CanvasVisualSystem.mutedInk(for: colorScheme).opacity(isEnabled ? 1 : 0.42))

            GeometryReader { proxy in
                let railHeight = proxy.size.height - 14
                let normalized = normalizedValue

                ZStack {
                    Capsule()
                        .fill(CanvasVisualSystem.hairline(for: colorScheme).opacity(0.62))
                        .frame(width: 3, height: railHeight)

                    Capsule()
                        .fill(CanvasVisualSystem.pigmentClay.opacity(isEnabled ? 0.42 : 0.18))
                        .frame(width: 3, height: railHeight * normalized)
                        .offset(y: railHeight * (1 - normalized) / 2)

                    Circle()
                        .fill(CanvasVisualSystem.paperSecondary(for: colorScheme))
                        .frame(width: 21, height: 21)
                        .overlay {
                            Circle().stroke(CanvasVisualSystem.hairline(for: colorScheme), lineWidth: 0.8)
                        }
                        .shadow(color: CanvasVisualSystem.shadow(for: colorScheme).opacity(0.45), radius: 4, x: 0, y: 2)
                        .offset(y: railHeight * (0.5 - normalized))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard isEnabled else { return }
                            let clampedY = min(max(gesture.location.y, 7), proxy.size.height - 7)
                            let next = 1 - ((clampedY - 7) / max(railHeight, 1))
                            value = range.lowerBound + next * (range.upperBound - range.lowerBound)
                        }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isEnabled ? 1 : 0.58)
    }

    private var normalizedValue: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }
}

private struct CanvasZoomHint: View {
    @Environment(\.colorScheme) private var colorScheme
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            Text("\(Int((scale * 100).rounded()))%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CanvasVisualSystem.paper(for: colorScheme))
                .monospacedDigit()
                .padding(.horizontal, 11)
                .frame(height: 24)
                .background(Color(hex: "#22201C").opacity(colorScheme == .dark ? 0.86 : 0.76), in: Capsule())

            Text("Pinch to zoom. Double tap to fit.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CanvasVisualSystem.paper(for: colorScheme))
                .padding(.horizontal, 13)
                .frame(height: 28)
                .background(Color(hex: "#22201C").opacity(colorScheme == .dark ? 0.82 : 0.68), in: Capsule())
        }
        .shadow(color: Color.black.opacity(0.22), radius: 9, x: 0, y: 4)
        .accessibilityIdentifier("canvas.zoomHint")
    }
}

private extension ToolSettings {
    static var opacityRangeCGFloat: ClosedRange<CGFloat> {
        CGFloat(opacityRange.lowerBound)...CGFloat(opacityRange.upperBound)
    }
}

private struct BottomColorWheelView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ColoringSessionViewModel

    private let colors = [
        "#D4213D", "#F16A37", "#F5B84B", "#6F8E62",
        "#2BBCB3", "#3F7BD9", "#7B68AE", "#111111"
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(colors, id: \.self) { hex in
                Button {
                    viewModel.selectColor(hex: hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Circle().stroke(viewModel.selectedColorHex == hex ? SableTheme.selectedSurface(for: colorScheme) : SableTheme.divider(for: colorScheme), lineWidth: 3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
                .accessibilityIdentifier(A11y.Canvas.color(hex))
            }
        }
        .padding(14)
        .background(SableTheme.canvasChrome(for: colorScheme))
    }
}

private struct CanvasSettingsSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: ColoringSessionViewModel
    @Binding var precisionSlidersEnabled: Bool
    @Binding var eyedropperShortcutEnabled: Bool
    @Binding var leftHandedMode: Bool
    @Binding var colorBlindMode: Bool
    let onRestart: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Tools") {
                    ForEach(ToolType.canvasTools) { tool in
                        Button {
                            viewModel.selectTool(tool)
                        } label: {
                            HStack(spacing: 12) {
                                ToolIconView(
                                    tool: tool,
                                    color: viewModel.selectedTool == tool ? SableTheme.selectedText(for: colorScheme) : SableTheme.primaryText(for: colorScheme),
                                    size: 20,
                                    pigment: Color(hex: viewModel.selectedColorHex)
                                )
                                .frame(width: 36, height: 36)
                                .background(
                                    viewModel.selectedTool == tool ? SableTheme.selectedSurface(for: colorScheme) : SableTheme.surface(for: colorScheme),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )

                                Text(tool.rawValue)
                                    .foregroundStyle(SableTheme.primaryText(for: colorScheme))

                                Spacer()

                                if viewModel.selectedTool == tool {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(SableTheme.progressPink)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tool.accessibilityLabel)
                        .accessibilityIdentifier(tool.accessibilityIdentifier)
                    }
                }

                Section("Brush") {
                    if viewModel.selectedTool.supportsSizeControl {
                        Slider(
                            value: Binding(
                                get: { viewModel.selectedToolSettings.size },
                                set: { viewModel.updateSelectedToolSize($0) }
                            ),
                            in: ToolSettings.sizeRange
                        ) {
                            Text("Size")
                        }
                    }
                    if viewModel.selectedTool.supportsOpacityControl {
                        Slider(
                            value: Binding(
                                get: { viewModel.selectedToolSettings.opacity },
                                set: { viewModel.updateSelectedToolOpacity($0) }
                            ),
                            in: ToolSettings.opacityRange
                        ) {
                            Text("Opacity")
                        }
                    }
                }

                Section("Colors") {
                    ForEach(viewModel.selectedSwatches) { swatch in
                        Button {
                            viewModel.selectColor(hex: swatch.hex)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: swatch.hex))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(SableTheme.divider(for: colorScheme), lineWidth: 1))
                                Text(swatch.name)
                                Spacer()
                                if viewModel.selectedColorHex == swatch.hex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(SableTheme.progressPink)
                                }
                            }
                        }
                        .accessibilityIdentifier(A11y.Canvas.color(swatch.hex))
                    }
                }

                Section("Preferences") {
                    Toggle("Precision Sliders", isOn: $precisionSlidersEnabled)
                    Toggle("Eyedropper Shortcut", isOn: $eyedropperShortcutEnabled)
                    Toggle("Left-Handed Mode", isOn: $leftHandedMode)
                    Toggle("Color Blind Mode", isOn: $colorBlindMode)
                }

                #if DEBUG
                Section("Diagnostics") {
                    Toggle("Canvas Diagnostics", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.enabledKey, alsoSetRuntimeEnabled: true))
                    Toggle("Pencil Movement Logs", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.pencilMovementEnabledKey))
                    Toggle("Pencil Trace Overlay", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.pencilTraceOverlayEnabledKey))
                    Toggle("Pencil Sample Dots", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.pencilSampleDotsEnabledKey, defaultValue: true))
                    Toggle("Pencil Velocity", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.pencilVelocityEnabledKey, defaultValue: true))
                    Toggle("Pencil Pressure", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.pencilPressureEnabledKey, defaultValue: true))
                    Toggle("Log Every Pencil Sample", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.logEveryPencilSampleKey))
                    Toggle("Persist Pencil Trace", isOn: diagnosticsToggle(CanvasDiagnosticsSettings.persistPencilTraceKey))
                    HStack {
                        Text("Movement Log Interval")
                        Slider(
                            value: Binding(
                                get: { CanvasDiagnosticsSettings.minimumMovementLogIntervalMs },
                                set: { CanvasDiagnosticsSettings.minimumMovementLogIntervalMs = $0 }
                            ),
                            in: 0...250,
                            step: 5
                        )
                    }
                }
                #endif

                Section("Artwork") {
                    Button("Restart Artwork", systemImage: "arrow.counterclockwise", action: onRestart)
                    Button("Clear Artwork", systemImage: "trash", role: .destructive, action: onDelete)
                }
            }
            .navigationTitle("Palette & Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("canvas.settings.sheet")
    }

    #if DEBUG
    private func diagnosticsToggle(
        _ key: String,
        defaultValue: Bool = false,
        alsoSetRuntimeEnabled: Bool = false
    ) -> Binding<Bool> {
        Binding(
            get: {
                UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
            },
            set: { value in
                UserDefaults.standard.set(value, forKey: key)
                if alsoSetRuntimeEnabled {
                    viewModel.canvasDiagnostics.isEnabled = value
                }
            }
        )
    }
    #endif
}

#Preview("Canvas") {
    NavigationStack {
        if let template = Template.loadAll().first {
            ColoringCanvasView(
                viewModel: ColoringSessionViewModel(
                    project: Project(template: template),
                    template: template
                )
            )
        } else {
            Text("No templates")
        }
    }
    .environment(RenderTuningStore())
}
