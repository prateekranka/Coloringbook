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
    @State private var showPalettePicker = false
    @State private var precisionSlidersEnabled = true
    @State private var eyedropperShortcutEnabled = true
    @State private var colorHistoryEnabled = true
    @State private var leftHandedMode = false
    @State private var toolPreviewEnabled = true
    @State private var brushSoundsEnabled = false
    @State private var colorBlindMode = false
    @State private var sharePayload: CanvasSharePayload?
    @State private var freehandFlushRequestID = 0
    @AppStorage("gouache.canvasGestureTipDismissed") private var gestureTipDismissed = false
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
            SableTheme.canvasBackground(for: colorScheme).ignoresSafeArea()

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

                    if viewModel.coloringMode == .clean || viewModel.selectedTool == .fillBucket {
                        CanvasInteractionOverlay(
                            selectedTool: viewModel.selectedTool,
                            colorHex: viewModel.selectedTool == .eraser ? "#000000" : viewModel.selectedColorHex,
                            toolSettings: viewModel.selectedToolSettings,
                            fingerPaints: fingerPaints,
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
                                Task { await viewModel.undoLastFill() }
                            },
                            onRedo: {
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

                    if !gestureTipDismissed && !isUIHidden {
                        gestureTip
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 74)
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

            if !isUIHidden {
                VStack(spacing: 0) {
                    CanvasShellHeader(
                        title: viewModel.title,
                        canUndo: viewModel.canUndo,
                        canRedo: viewModel.canRedo,
                        canSave: viewModel.canSave,
                        hasArtwork: viewModel.hasArtwork,
                        saveLabel: viewModel.saveState.label,
                        onBack: {
                            flushFreehandThenSave()
                            dismiss()
                        },
                        onUndo: { Task { await viewModel.undoLastFill() } },
                        onRedo: { Task { await viewModel.redoFill() } },
                        onSettings: { showSettingsSheet = true },
                        onShare: { presentShareSheet() },
                        onSave: { Task { await viewModel.saveNowAfterPendingPigmentCommits() } },
                        onResetView: resetViewport,
                        onFocus: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isUIHidden = true
                            }
                        },
                        onClear: { showClearArtworkConfirmation = true }
                    )

                    Spacer()

                    MinimalCanvasDock(
                        viewModel: viewModel,
                        showColorPicker: $showColorPicker,
                        showPalettePicker: $showPalettePicker,
                        showSettingsSheet: $showSettingsSheet
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 18)
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
        .task(id: renderTuning.canvasStrokeWidth) {
            await viewModel.updateCanvasStrokeWidth(renderTuning.canvasStrokeWidth)
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

    private var gestureTip: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                gestureTipDismissed = true
            }
        } label: {
            Text("Two-finger tap to undo • Pinch to zoom • Tap color to change")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(SableTheme.canvasChrome(for: colorScheme), in: Capsule())
                .overlay {
                    Capsule().stroke(SableTheme.divider(for: colorScheme), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("canvas.gestureTip")
    }

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
        .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                .stroke(SableTheme.divider(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: SableTheme.shadow(for: colorScheme), radius: 18, x: 0, y: 10)
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
        let inset: CGFloat = 58
        let documentSize = viewModel.canvasDocumentSize
        let maxSize = CGSize(
            width: max(1, availableSize.width - inset * 2),
            height: max(1, availableSize.height - inset * 2)
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
        case .marker, .watercolor, .sprayPaint:
            inkType = .marker
        case .crayon, .coloredPencil:
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
                detail: parent.selectedTool == .fillBucket ? "fill tap" : "tap ignored for tool=\(parent.selectedTool.rawValue)"
            )
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
        case .coloredPencil:
            return max(1.2, viewportStrokeSize * 0.06)
        case .crayon:
            return max(1.8, viewportStrokeSize * 0.08)
        case .watercolor:
            return max(2.4, viewportStrokeSize * 0.10)
        case .marker:
            return max(2.0, viewportStrokeSize * 0.075)
        case .eraser:
            return max(2.3, viewportStrokeSize * 0.08)
        case .sprayPaint, .fillBucket:
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

private struct ToolIconView: View {
    let tool: ToolType
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            if tool == .sprayPaint {
                SprayToolIcon(color: color)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: tool.systemImageName)
                    .font(.system(size: size * 0.9, weight: .black))
                    .foregroundStyle(color)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SprayToolIcon: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(1.6, side * 0.08)

            ZStack {
                RoundedRectangle(cornerRadius: side * 0.12)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                    .frame(width: side * 0.36, height: side * 0.52)
                    .rotationEffect(.degrees(-16))
                    .offset(x: -side * 0.12, y: side * 0.08)

                Path { path in
                    path.move(to: CGPoint(x: side * 0.46, y: side * 0.31))
                    path.addLine(to: CGPoint(x: side * 0.63, y: side * 0.25))
                    path.addLine(to: CGPoint(x: side * 0.66, y: side * 0.33))
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(color)
                        .frame(width: dotSize(side, index: index), height: dotSize(side, index: index))
                        .position(dotPosition(side, index: index))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dotSize(_ side: CGFloat, index: Int) -> CGFloat {
        let scales: [CGFloat] = [0.10, 0.075, 0.085, 0.06, 0.07]
        return side * scales[index]
    }

    private func dotPosition(_ side: CGFloat, index: Int) -> CGPoint {
        let points: [CGPoint] = [
            CGPoint(x: side * 0.78, y: side * 0.18),
            CGPoint(x: side * 0.90, y: side * 0.30),
            CGPoint(x: side * 0.76, y: side * 0.43),
            CGPoint(x: side * 0.95, y: side * 0.48),
            CGPoint(x: side * 0.66, y: side * 0.20)
        ]
        return points[index]
    }
}

private struct CanvasShellHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let canUndo: Bool
    let canRedo: Bool
    let canSave: Bool
    let hasArtwork: Bool
    let saveLabel: String
    let onBack: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSettings: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onResetView: () -> Void
    let onFocus: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Back", systemImage: "chevron.left", action: onBack)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("canvas.back")

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)

            Menu {
                Button("Save", systemImage: "square.and.arrow.down", action: onSave)
                    .disabled(!canSave)
                Button("Share", systemImage: "square.and.arrow.up", action: onShare)
                Button("Fit Artwork", systemImage: "arrow.up.left.and.down.right.magnifyingglass", action: onResetView)
                Button("Focus Mode", systemImage: "eye.slash", action: onFocus)
                Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo)
                    .disabled(!canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward", action: onRedo)
                    .disabled(!canRedo)
                Button("Palette & Tools", systemImage: "paintpalette", action: onSettings)
                Button("Clear Artwork", systemImage: "trash", role: .destructive, action: onClear)
                    .disabled(!hasArtwork)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Canvas options")
            .accessibilityIdentifier("canvas.more")
        }
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
        .padding(.horizontal, 8)
        .frame(height: 52)
        .background(SableTheme.canvasChrome(for: colorScheme), in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.divider(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: SableTheme.shadow(for: colorScheme), radius: 12, y: 5)
    }
}

private struct MinimalCanvasDock: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ColoringSessionViewModel
    @Binding var showColorPicker: Bool
    @Binding var showPalettePicker: Bool
    @Binding var showSettingsSheet: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button {
                showColorPicker.toggle()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: viewModel.selectedColorHex))
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(SableTheme.divider(for: colorScheme), lineWidth: 1))

                    recentColors
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                BottomColorWheelView(viewModel: viewModel)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("Change color")
            .accessibilityIdentifier("canvas.color.compact")

            Button("Palette", systemImage: "paintpalette.fill") {
                showPalettePicker.toggle()
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .bold))
            .popover(isPresented: $showPalettePicker, arrowEdge: .bottom) {
                PalettePickerPopover(viewModel: viewModel)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityIdentifier("canvas.palette.popover")

            Picker("Coloring mode", selection: Binding(
                get: { viewModel.coloringMode },
                set: { viewModel.selectColoringMode($0) }
            )) {
                Text("Clean").tag(CanvasColoringMode.clean)
                Text("Free").tag(CanvasColoringMode.free)
            }
            .pickerStyle(.segmented)
            .frame(width: 138)
            .accessibilityIdentifier("canvas.cleanFreeToggle")

            Button("Tools", systemImage: "slider.horizontal.3") {
                showSettingsSheet = true
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .bold))
            .accessibilityIdentifier("canvas.tools")
        }
        .tint(SableTheme.progressPink)
        .foregroundStyle(SableTheme.primaryText(for: colorScheme))
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(SableTheme.canvasChrome(for: colorScheme), in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.divider(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: SableTheme.shadow(for: colorScheme), radius: 14, y: 7)
    }

    private var recentColors: some View {
        HStack(spacing: -3) {
            ForEach(Array(viewModel.recentColorHexes.prefix(5)), id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(SableTheme.canvasChrome(for: colorScheme), lineWidth: 1))
            }
        }
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

private struct PalettePickerPopover: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ColoringSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.palettes) { palette in
                Button {
                    viewModel.selectPalette(palette)
                    if let first = palette.swatches.first {
                        viewModel.selectColor(hex: first.hex)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(palette.name)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(SableTheme.primaryText(for: colorScheme))
                            .frame(width: 120, alignment: .leading)
                        HStack(spacing: -4) {
                            ForEach(palette.swatches.prefix(5)) { swatch in
                                Circle()
                                    .fill(Color(hex: swatch.hex))
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Canvas.palette(palette.name))
            }
        }
        .padding(16)
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
                    ForEach(ToolType.allCases) { tool in
                        Button {
                            viewModel.selectTool(tool)
                        } label: {
                            HStack(spacing: 12) {
                                ToolIconView(
                                    tool: tool,
                                    color: viewModel.selectedTool == tool ? SableTheme.selectedText(for: colorScheme) : SableTheme.primaryText(for: colorScheme),
                                    size: 20
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
