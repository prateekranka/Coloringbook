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
                            canvasSize: canvasSize,
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
                        onSave: { viewModel.save() },
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
                showsLineArt: viewModel.coloringMode == .clean
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
                    onDrawingChanged: { viewModel.syncFreehandDrawingFromCanvas($0) }
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
            viewModel.saveNow()
        }
    }

    private func presentShareSheet() {
        guard let image = viewModel.exportImage() else { return }
        sharePayload = CanvasSharePayload(image: image)
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

private struct NotebookCanvasRepresentable: UIViewRepresentable {
    let fillLayerImage: UIImage?
    let lineArtImage: UIImage?
    let freehandDrawing: PKDrawing
    let freehandDrawingRevision: Int
    let showsLineArt: Bool

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
            showsLineArt: showsLineArt
        )
    }
}

private final class NotebookCanvasUIView: UIView {
    private var fillLayerImage: UIImage?
    private var lineArtImage: UIImage?
    private var freehandDrawing = PKDrawing()
    private var freehandDrawingRevision = Int.min
    private var showsLineArt = true

    func configure(
        fillLayerImage: UIImage?,
        lineArtImage: UIImage?,
        freehandDrawing: PKDrawing,
        freehandDrawingRevision: Int,
        showsLineArt: Bool
    ) {
        let imageChanged = self.fillLayerImage !== fillLayerImage
            || self.lineArtImage !== lineArtImage
            || self.freehandDrawingRevision != freehandDrawingRevision
            || self.showsLineArt != showsLineArt

        self.fillLayerImage = fillLayerImage
        self.lineArtImage = lineArtImage
        self.freehandDrawing = freehandDrawing
        self.freehandDrawingRevision = freehandDrawingRevision
        self.showsLineArt = showsLineArt

        if imageChanged {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let canvasBounds = bounds

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

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = fingerPaints ? .anyInput : .pencilOnly
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        context.coordinator.appliedExternalRevision = drawingExternalRevision
        canvas.tool = makeTool()
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.bounces = false
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
            return PKEraserTool(.bitmap)
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

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: FreehandCanvasRepresentable
        var appliedExternalRevision = 0
        var handledFlushRequestID = 0
        var isApplyingExternalDrawing = false
        private var idleSyncTask: Task<Void, Never>?
        private var hasPendingCanvasDrawingChange = false

        init(parent: FreehandCanvasRepresentable) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            CanvasPerformanceProbe.count(.pencilKitDelegateSync)
            hasPendingCanvasDrawingChange = true
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
            flushDrawing(from: canvasView)
        }

        func flushDrawing(from canvasView: PKCanvasView) {
            idleSyncTask?.cancel()
            hasPendingCanvasDrawingChange = false
            parent.onDrawingChanged(canvasView.drawing)
        }
    }
}

private struct CanvasInteractionOverlay: UIViewRepresentable {
    var selectedTool: ToolType
    var colorHex: String
    var toolSettings: ToolSettings
    var fingerPaints: Bool
    var liveStrokeSeed: UInt64?
    var canvasSize: CGSize
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
    }

    private var previewConfiguration: LiveStrokePreviewConfiguration {
        LiveStrokePreviewConfiguration(
            tool: selectedTool,
            colorHex: colorHex,
            size: toolSettings.size,
            opacity: selectedTool == .eraser ? 1 : CGFloat(toolSettings.opacity),
            seed: liveStrokeSeed ?? 0,
            viewport: viewport,
            canvasSize: canvasSize,
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

        init(parent: CanvasInteractionOverlay) {
            self.parent = parent
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  parent.selectedTool == .fillBucket,
                  let canvasPoint = canvasPoint(for: recognizer.location(in: recognizer.view)) else {
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
                if recognizer.numberOfTouches >= 2 || parent.selectedTool == .fillBucket {
                    lockedMode = .viewportPan
                    panStartOffset = activeViewport.offset
                    #if DEBUG
                    AppLog.trace(AppLog.canvas, "pan began: touches=\(recognizer.numberOfTouches), mode=viewportPan")
                    #endif
                } else if parent.selectedTool != .fillBucket {
                    lockedMode = .drawing
                    #if DEBUG
                    AppLog.trace(AppLog.canvas, "pan began: touches=\(recognizer.numberOfTouches), mode=drawing, tool=\(parent.selectedTool.rawValue)")
                    #endif
                } else {
                    lockedMode = .viewportPan
                    panStartOffset = activeViewport.offset
                }
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
            beginStroke(at: recognizer.location(in: recognizer.view), in: recognizer.view)
        }

        private func handleFingerStrokeMoved(_ recognizer: UIPanGestureRecognizer) {
            appendStrokePoint(recognizer.location(in: recognizer.view))
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
            case .ended:
                #if DEBUG
                AppLog.trace(AppLog.canvas, "pinch ended: scale=\(workingViewport?.scale ?? activeViewport.scale)")
                #endif
                parent.onViewportCommitted()
                workingViewport = nil
                resetInteractionMode()
            case .cancelled, .failed:
                #if DEBUG
                AppLog.trace(AppLog.canvas, "pinch cancelled/failed")
                #endif
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
            guard parent.onStrokeBegan(strokeSamples) else {
                strokeSamples = []
                return
            }
            startPreview(in: view)
        }

        func appendStrokePoint(_ point: CGPoint) {
            guard parent.selectedTool != .fillBucket,
                  !strokeSamples.isEmpty,
                  let canvasPoint = canvasPoint(for: point) else { return }
            strokeSamples.append(StrokeSample(point: canvasPoint, timestamp: CACurrentMediaTime()))
            _ = parent.onStrokeChanged(strokeSamples)
            appendPreview()
        }

        func endStroke(at point: CGPoint?) {
            if let point {
                appendStrokePoint(point)
            }

            let completedSamples = strokeSamples
            if completedSamples.count > 1 {
                _ = parent.onStrokeEnded(completedSamples)
            }
            previewView?.finishPreview()
            strokeSamples = []
        }

        func cancelStroke() {
            strokeSamples = []
            previewView?.finishPreview()
            parent.onStrokeCancelled()
        }

        func beginPencilStroke(with touch: UITouch, in view: UIView) {
            guard parent.selectedTool != .fillBucket,
                  let sample = strokeSample(for: touch, in: view) else { return }
            strokeSamples = [sample]
            guard parent.onStrokeBegan(strokeSamples) else {
                strokeSamples = []
                return
            }
            startPreview(in: view)
        }

        func appendPencilStroke(with touch: UITouch, in view: UIView) {
            guard parent.selectedTool != .fillBucket,
                  !strokeSamples.isEmpty,
                  let sample = strokeSample(for: touch, in: view) else { return }
            strokeSamples.append(sample)
            _ = parent.onStrokeChanged(strokeSamples)
            appendPreview()
        }

        func endPencilStroke(with touch: UITouch, in view: UIView) {
            appendPencilStroke(with: touch, in: view)
            let completedSamples = strokeSamples
            if completedSamples.count > 1 {
                _ = parent.onStrokeEnded(completedSamples)
            }
            previewView?.finishPreview()
            strokeSamples = []
        }

        private func startPreview(in view: UIView?) {
            previewView = view as? CanvasInteractionUIView
            previewView?.beginPreview(samples: strokeSamples, clip: parent.liveStrokeClip(strokeSamples))
        }

        private func appendPreview() {
            previewView?.appendPreview(samples: strokeSamples, clip: parent.liveStrokeClip(strokeSamples))
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
    let viewport: CanvasViewport
    let canvasSize: CGSize
    let viewportSize: CGSize

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
}

private final class CanvasInteractionUIView: UIView {
    weak var coordinator: CanvasInteractionOverlay.Coordinator?
    private var previewConfiguration: LiveStrokePreviewConfiguration?
    private var previewImage: UIImage?
    private var previewedSampleCount = 0

    func updatePreviewConfiguration(_ configuration: LiveStrokePreviewConfiguration) {
        previewConfiguration = configuration
    }

    func beginPreview(samples: [StrokeSample], clip: StrokeRenderClip?) {
        previewImage = nil
        previewedSampleCount = 0
        appendPreview(samples: samples, clip: clip)
    }

    func appendPreview(samples: [StrokeSample], clip: StrokeRenderClip?) {
        guard let previewConfiguration, samples.count > 1 else { return }
        let startIndex = max(0, previewedSampleCount - 1)
        guard startIndex < samples.count - 1 else { return }
        let newSamples = samples[startIndex...].map(previewConfiguration.viewportSample(from:))
        let dirtyRect = Self.dirtyRect(for: newSamples.map(\.cgPoint), size: previewConfiguration.size, bounds: bounds)
        let viewportClip = previewConfiguration.viewportClip(from: clip)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        previewImage = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            previewImage?.draw(in: bounds)
            let stroke = PigmentStroke(
                tool: previewConfiguration.tool,
                colorHex: previewConfiguration.colorHex,
                opacity: Double(previewConfiguration.opacity),
                size: Double(previewConfiguration.size * previewConfiguration.viewport.scale),
                points: newSamples.map(\.cgPoint),
                regionID: nil,
                seed: previewConfiguration.seed
            )
            let mask = viewportClip.map { RegionMask(regionID: "preview", path: $0.path, fillRule: $0.fillRule, image: UIImage()) }
            PigmentStrokeRenderer.render(stroke, in: context.cgContext, mask: mask)
        }
        previewedSampleCount = samples.count
        setNeedsDisplay(dirtyRect)
    }

    func finishPreview() {
        let rect = previewImage == nil ? .null : bounds
        previewImage = nil
        previewedSampleCount = 0
        if !rect.isNull {
            setNeedsDisplay(rect)
        }
    }

    override func draw(_ rect: CGRect) {
        previewImage?.draw(in: bounds)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        coordinator?.beginPencilStroke(with: touch, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
        for coalescedTouch in coalescedTouches where coalescedTouch.type == .pencil {
            coordinator?.appendPencilStroke(with: coalescedTouch, in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        coordinator?.endPencilStroke(with: touch, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.contains(where: { $0.type == .pencil }) else { return }
        coordinator?.cancelStroke()
    }

    private static func dirtyRect(for points: [CGPoint], size: CGFloat, bounds: CGRect) -> CGRect {
        guard let first = points.first else { return .null }
        let rect = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
        return rect
            .insetBy(dx: -max(24, size * 3), dy: -max(24, size * 3))
            .integral
            .intersection(bounds)
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
