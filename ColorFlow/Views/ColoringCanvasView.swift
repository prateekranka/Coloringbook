import SwiftUI
import UIKit
import QuartzCore
import PencilKit

@MainActor
struct ColoringCanvasView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(RenderTuningStore.self) private var renderTuning
    @State private var viewModel: ColoringSessionViewModel
    @State private var showClearArtworkConfirmation = false
    @State private var fillFeedbackID: UUID?
    @State private var isUIHidden = false
    @State private var fingerPaints = false
    @State private var liveStrokeSamples: [StrokeSample] = []
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
    #if DEBUG
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
            SableTheme.cream.ignoresSafeArea()

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
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                renderTuningButton
            }
            #endif

            ToolbarItem(placement: .topBarTrailing) {
                toolbarActions
            }
        }
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
            viewModel.saveNow()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                viewModel.saveNow()
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
                            fingerPaints: fingerPaints,
                            canvasSize: canvasSize,
                            viewportSize: availableSize,
                            viewport: viewModel.viewport,
                            onViewportChanged: { viewport in
                                viewModel.updateViewport(viewport)
                            },
                            onViewportCommitted: {
                                viewModel.commitViewportChange()
                            },
                            onFill: { point in
                                handleFill(atCanvasPoint: point, canvasSize: canvasSize)
                            },
                            onStrokeChanged: { samples in
                                liveStrokeSamples = samples
                            },
                            onStrokeEnded: { samples in
                                handleStroke(samples: samples, canvasSize: canvasSize)
                            }
                        )
                        .frame(width: availableSize.width, height: availableSize.height)
                    }

                    if !isUIHidden && precisionSlidersEnabled {
                        PrecisionSliderRail(
                            tool: viewModel.selectedTool,
                            size: Binding(
                                get: { viewModel.selectedToolSettings.size },
                                set: { viewModel.updateSelectedToolSize($0) }
                            ),
                            opacity: Binding(
                                get: { viewModel.selectedToolSettings.opacity },
                                set: { viewModel.updateSelectedToolOpacity($0) }
                            )
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: leftHandedMode ? .leading : .trailing)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 110)
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
                VStack {
                    HStack {
                        Spacer()
                        CanvasTopControls(
                            onSettings: { showSettingsSheet = true },
                            onShare: { presentShareSheet() },
                            onDone: { viewModel.saveNow() }
                        )
                    }
                    Spacer()
                    CanvasHUDView(
                        viewModel: viewModel,
                        showColorPicker: $showColorPicker,
                        showPalettePicker: $showPalettePicker,
                        fingerPaints: $fingerPaints,
                        isUIHidden: $isUIHidden,
                        resetViewport: resetViewport
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettingsSheet) {
            CanvasSettingsSheet(
                precisionSlidersEnabled: $precisionSlidersEnabled,
                opacityEnabled: Binding(
                    get: { viewModel.selectedTool.supportsOpacityControl },
                    set: { _ in }
                ),
                eyedropperShortcutEnabled: $eyedropperShortcutEnabled,
                colorHistoryEnabled: $colorHistoryEnabled,
                leftHandedMode: $leftHandedMode,
                toolPreviewEnabled: $toolPreviewEnabled,
                brushSoundsEnabled: $brushSoundsEnabled,
                colorBlindMode: $colorBlindMode,
                onRestart: { showClearArtworkConfirmation = true },
                onDuplicate: {},
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

    private var canvasHeader: some View {
        HStack(spacing: 16) {
            Text(viewModel.title)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(SableTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if fillFeedbackID != nil {
                Label("Filled", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SableTheme.cardBlack, in: Capsule())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Filled")
                    .accessibilityIdentifier(A11y.Canvas.fillFeedback)
            }

            Spacer()

            Picker("Coloring mode", selection: Binding(
                get: { viewModel.coloringMode },
                set: { viewModel.selectColoringMode($0) }
            )) {
                ForEach(CanvasColoringMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
            .accessibilityIdentifier("canvas.cleanFreeToggle")

            Button {
                fingerPaints.toggle()
            } label: {
                Image(systemName: fingerPaints ? "hand.draw.fill" : "hand.draw")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(fingerPaints ? Color.white : SableTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(fingerPaints ? SableTheme.cardBlack : Color.white.opacity(0.78), in: Capsule())
            }
            .accessibilityLabel(fingerPaints ? "Finger painting on" : "Finger painting off")
            .accessibilityIdentifier("canvas.fingerPaint")

            Text(viewModel.progressLabel)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(SableTheme.cardBlack, in: Capsule())
                .accessibilityIdentifier(A11y.Canvas.progress)

            Label(viewModel.saveState.label, systemImage: viewModel.saveState.systemImageName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(viewModel.saveState == .dirty ? SableTheme.crimson : SableTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.78), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(viewModel.saveState.label)
                .accessibilityIdentifier(A11y.Canvas.saveState)

            Text("\(Int((viewModel.viewport.scale * 100).rounded()))%")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(SableTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.78), in: Capsule())
                .accessibilityLabel("Zoom \(Int((viewModel.viewport.scale * 100).rounded())) percent")
                .accessibilityIdentifier(A11y.Canvas.zoom)

            Button(isUIHidden ? "Show UI" : "Hide UI", systemImage: isUIHidden ? "eye" : "eye.slash") {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isUIHidden.toggle()
                }
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(SableTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.78), in: Capsule())
            .accessibilityIdentifier("canvas.hideUI")
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: 12) {
            Button("Undo", systemImage: "arrow.uturn.backward") {
                Task {
                    await viewModel.undoLastFill()
                }
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canUndo)
            .accessibilityIdentifier(A11y.Canvas.undo)

            Button("Redo", systemImage: "arrow.uturn.forward") {
                Task {
                    await viewModel.redoFill()
                }
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canRedo)
            .accessibilityIdentifier(A11y.Canvas.redo)

            Button("Clear Artwork", systemImage: "trash") {
                showClearArtworkConfirmation = true
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.hasArtwork)
            .accessibilityIdentifier(A11y.Canvas.clearArtwork)

            Button("Reset View", systemImage: "arrow.counterclockwise", action: resetViewport)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier(A11y.Canvas.resetView)

            Button(
                viewModel.canSave ? "Save" : viewModel.saveState.label,
                systemImage: viewModel.canSave ? "square.and.arrow.down" : viewModel.saveState.systemImageName
            ) {
                viewModel.save()
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canSave || viewModel.isSaving)
            .accessibilityIdentifier(A11y.Canvas.save)
        }
        .font(.system(size: 18, weight: .bold))
        .tint(SableTheme.progressPink)
    }

    #if DEBUG
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

    private var colorDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Label(viewModel.selectedColorName, systemImage: "paintpalette.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(SableTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(minWidth: 150, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.palettes) { palette in
                            Button {
                                viewModel.selectPalette(palette)
                            } label: {
                                Text(palette.name)
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(viewModel.selectedPaletteID == palette.id ? .white : SableTheme.ink)
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.selectedPaletteID == palette.id ? SableTheme.cardBlack : Color.white.opacity(0.7),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(A11y.Canvas.palette(palette.name))
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                        ForEach(viewModel.selectedSwatches) { swatch in
                            colorSwatchButton(swatch)
                        }
                }
                .padding(.vertical, 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                .stroke(SableTheme.hairline, lineWidth: 1)
        }
    }

    private var toolDock: some View {
        FloatingPanel {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ToolType.allCases) { tool in
                        Button {
                            viewModel.selectTool(tool)
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: tool.systemImageName)
                                    .font(.system(size: 18, weight: .bold))
                                Text(tool.rawValue)
                                    .font(.system(size: 9, weight: .black))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .foregroundStyle(viewModel.selectedTool == tool ? .white : SableTheme.ink)
                            .frame(width: 74, height: 56)
                            .background(viewModel.selectedTool == tool ? SableTheme.cardBlack : Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("canvas.tool.\(tool.rawValue.normalizedIdentifier)")
                    }

                    Divider()
                        .frame(height: 96)

                    ToolAdjustmentPanel(
                        tool: viewModel.selectedTool,
                        size: Binding(
                            get: { viewModel.selectedToolSettings.size },
                            set: { viewModel.updateSelectedToolSize($0) }
                        ),
                        opacity: Binding(
                            get: { viewModel.selectedToolSettings.opacity },
                            set: { viewModel.updateSelectedToolOpacity($0) }
                        ),
                        textureAmount: viewModel.selectedToolSettings.textureAmount
                    )
                }
            }
        }
    }

    private func colorSwatchButton(_ swatch: ColorSwatch) -> some View {
        Button {
            viewModel.selectColor(hex: swatch.hex)
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(.clear)
                    .overlay {
                        PaintDab(
                            color: Color(hex: swatch.hex),
                            isSelected: viewModel.selectedColorHex == swatch.hex
                        )
                    }
                    .frame(width: 54, height: 54)

                Text(swatch.name)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(SableTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: 72)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(swatch.name)
        .accessibilityIdentifier(A11y.Canvas.color(swatch.hex))
    }

    private func canvasArtwork(canvasSize: CGSize) -> some View {
        let liveClip = viewModel.liveStrokeClip(samples: liveStrokeSamples, canvasSize: canvasSize)

        return ZStack {
            NotebookCanvasRepresentable(
                fillLayerImage: viewModel.fillLayerImage,
                lineArtImage: viewModel.lineArtImage,
                freehandDrawing: viewModel.coloringMode == .free ? PKDrawing() : viewModel.freehandDrawing,
                showsLineArt: viewModel.coloringMode == .clean,
                liveStrokeSamples: liveStrokeSamples,
                liveStrokeClip: liveClip,
                liveStrokeColorHex: viewModel.selectedColorHex,
                liveStrokeSettings: viewModel.selectedToolSettings
            )

            if viewModel.coloringMode == .free, viewModel.selectedTool != .fillBucket {
                FreehandCanvasRepresentable(
                    drawing: Binding(
                        get: { viewModel.freehandDrawing },
                        set: { viewModel.updateFreehandDrawing($0) }
                    ),
                    selectedTool: viewModel.selectedTool,
                    colorHex: viewModel.selectedColorHex,
                    settings: viewModel.selectedToolSettings,
                    fingerPaints: fingerPaints
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
                .stroke(SableTheme.cardBlack, lineWidth: 2)
        }
        .shadow(color: Color.black.opacity(0.2), radius: 18, x: 0, y: 10)
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
        let inset: CGFloat = 18
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

    private func handleStroke(samples: [StrokeSample], canvasSize: CGSize) {
        guard viewModel.selectedTool != .fillBucket else { return }
        Task {
            _ = await viewModel.drawStroke(samples: samples, canvasSize: canvasSize)
        }
    }

    private func resetViewport() {
        var viewport = viewModel.viewport
        viewport.reset()
        viewModel.updateViewport(viewport)
        viewModel.commitViewportChange()
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
    let showsLineArt: Bool
    let liveStrokeSamples: [StrokeSample]
    let liveStrokeClip: StrokeRenderClip?
    let liveStrokeColorHex: String
    let liveStrokeSettings: ToolSettings

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
            showsLineArt: showsLineArt,
            liveStrokeSamples: liveStrokeSamples,
            liveStrokeClip: liveStrokeClip,
            liveStrokeColorHex: liveStrokeColorHex,
            liveStrokeSettings: liveStrokeSettings
        )
    }
}

private final class NotebookCanvasUIView: UIView {
    private var fillLayerImage: UIImage?
    private var lineArtImage: UIImage?
    private var freehandDrawing = PKDrawing()
    private var showsLineArt = true
    private var liveStrokeSamples: [StrokeSample] = []
    private var liveStrokeClip: StrokeRenderClip?
    private var liveStrokeColorHex = SableTheme.progressPinkHex
    private var liveStrokeSettings = ToolType.crayon.defaultSettings

    func configure(
        fillLayerImage: UIImage?,
        lineArtImage: UIImage?,
        freehandDrawing: PKDrawing,
        showsLineArt: Bool,
        liveStrokeSamples: [StrokeSample],
        liveStrokeClip: StrokeRenderClip?,
        liveStrokeColorHex: String,
        liveStrokeSettings: ToolSettings
    ) {
        let imageChanged = self.fillLayerImage !== fillLayerImage
            || self.lineArtImage !== lineArtImage
            || self.freehandDrawing.dataRepresentation() != freehandDrawing.dataRepresentation()
            || self.showsLineArt != showsLineArt
        let changed = imageChanged
            || self.liveStrokeSamples != liveStrokeSamples
            || self.liveStrokeColorHex != liveStrokeColorHex
            || self.liveStrokeSettings != liveStrokeSettings
            || !sameClip(self.liveStrokeClip, liveStrokeClip)
        let oldDirtyRect = dirtyRect(for: self.liveStrokeSamples, clip: self.liveStrokeClip)

        self.fillLayerImage = fillLayerImage
        self.lineArtImage = lineArtImage
        self.freehandDrawing = freehandDrawing
        self.showsLineArt = showsLineArt
        self.liveStrokeSamples = liveStrokeSamples
        self.liveStrokeClip = liveStrokeClip
        self.liveStrokeColorHex = liveStrokeColorHex
        self.liveStrokeSettings = liveStrokeSettings

        if changed {
            if imageChanged {
                setNeedsDisplay()
            } else {
                setNeedsDisplay(oldDirtyRect.union(dirtyRect(for: liveStrokeSamples, clip: liveStrokeClip)))
            }
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

        if liveStrokeSamples.count > 1 {
            context.saveGState()
            BrushRenderers.drawLiveStroke(
                samples: liveStrokeSamples,
                tool: liveStrokeSettings.tool,
                colorHex: liveStrokeColorHex,
                size: liveStrokeSettings.size,
                opacity: CGFloat(liveStrokeSettings.opacity),
                clipPath: liveStrokeClip?.path,
                clipFillRule: liveStrokeClip?.fillRule ?? .winding,
                in: context
            )
            context.restoreGState()
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

    private func dirtyRect(for samples: [StrokeSample], clip: StrokeRenderClip?) -> CGRect {
        guard !samples.isEmpty else { return bounds }

        let radius = max(CGFloat(liveStrokeSettings.size) * 2, 48)
        var rect = samples
            .map(\.cgPoint)
            .reduce(CGRect.null) { partial, point in
                partial.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
            }
            .insetBy(dx: -radius, dy: -radius)

        if let clip {
            rect = rect.intersection(clip.path.boundingBoxOfPath.insetBy(dx: -radius, dy: -radius))
        }

        return rect.isNull || rect.isEmpty ? bounds : rect.intersection(bounds)
    }

    private func sameClip(_ lhs: StrokeRenderClip?, _ rhs: StrokeRenderClip?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.path === rhs.path && lhs.fillRule == rhs.fillRule
        default:
            return false
        }
    }
}

private struct FreehandCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var selectedTool: ToolType
    var colorHex: String
    var settings: ToolSettings
    var fingerPaints: Bool

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
        canvas.tool = makeTool()
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.bounces = false
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if uiView.drawing.dataRepresentation() != drawing.dataRepresentation() {
            uiView.drawing = drawing
        }
        uiView.drawingPolicy = fingerPaints ? .anyInput : .pencilOnly
        uiView.tool = makeTool()
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

        init(parent: FreehandCanvasRepresentable) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

private struct CanvasInteractionOverlay: UIViewRepresentable {
    var selectedTool: ToolType
    var fingerPaints: Bool
    var canvasSize: CGSize
    var viewportSize: CGSize
    var viewport: CanvasViewport
    var onViewportChanged: (CanvasViewport) -> Void
    var onViewportCommitted: () -> Void
    var onFill: (CGPoint) -> Void
    var onStrokeChanged: ([StrokeSample]) -> Void
    var onStrokeEnded: ([StrokeSample]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CanvasInteractionUIView {
        let view = CanvasInteractionUIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.isAccessibilityElement = false
        view.coordinator = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pan.maximumNumberOfTouches = 1
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
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CanvasInteractionOverlay
        private var panStartOffset = CGSize.zero
        private var pinchStartScale = CanvasViewport.minimumScale
        private var pinchStartOffset = CGSize.zero
        private var strokeSamples: [StrokeSample] = []

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

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            if parent.fingerPaints && parent.selectedTool != .fillBucket {
                handleFingerStroke(recognizer)
            } else {
                handleViewportPan(recognizer)
            }
        }

        private func handleFingerStroke(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                beginStroke(at: recognizer.location(in: recognizer.view))
            case .changed:
                appendStrokePoint(recognizer.location(in: recognizer.view))
            case .ended:
                endStroke(at: recognizer.location(in: recognizer.view))
            case .cancelled, .failed:
                cancelStroke()
            default:
                break
            }
        }

        private func handleViewportPan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                panStartOffset = parent.viewport.offset
            case .changed, .ended:
                var nextViewport = parent.viewport
                let translation = recognizer.translation(in: recognizer.view)
                nextViewport.updateOffset(
                    from: panStartOffset,
                    translation: CGSize(width: translation.x, height: translation.y),
                    canvasSize: parent.canvasSize,
                    viewportSize: parent.viewportSize
                )
                parent.onViewportChanged(nextViewport)
                if recognizer.state == .ended {
                    parent.onViewportCommitted()
                }
            case .cancelled, .failed:
                parent.onViewportCommitted()
            default:
                break
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                pinchStartScale = parent.viewport.scale
                pinchStartOffset = parent.viewport.offset
            case .changed, .ended:
                var nextViewport = parent.viewport
                nextViewport.updateScale(
                    from: pinchStartScale,
                    baseOffset: pinchStartOffset,
                    magnification: recognizer.scale,
                    anchor: recognizer.location(in: recognizer.view),
                    canvasSize: parent.canvasSize,
                    viewportSize: parent.viewportSize
                )
                parent.onViewportChanged(nextViewport)
                if recognizer.state == .ended {
                    parent.onViewportCommitted()
                }
            case .cancelled, .failed:
                parent.onViewportCommitted()
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            gestureRecognizer.view === otherGestureRecognizer.view
        }

        func beginStroke(at point: CGPoint) {
            guard parent.selectedTool != .fillBucket,
                  let canvasPoint = canvasPoint(for: point) else { return }
            strokeSamples = [StrokeSample(point: canvasPoint, timestamp: CACurrentMediaTime())]
            parent.onStrokeChanged(strokeSamples)
        }

        func appendStrokePoint(_ point: CGPoint) {
            guard parent.selectedTool != .fillBucket,
                  !strokeSamples.isEmpty,
                  let canvasPoint = canvasPoint(for: point) else { return }
            strokeSamples.append(StrokeSample(point: canvasPoint, timestamp: CACurrentMediaTime()))
            parent.onStrokeChanged(strokeSamples)
        }

        func endStroke(at point: CGPoint?) {
            if let point {
                appendStrokePoint(point)
            }

            let completedSamples = strokeSamples
            strokeSamples = []
            parent.onStrokeChanged([])
            if completedSamples.count > 1 {
                parent.onStrokeEnded(completedSamples)
            }
        }

        func cancelStroke() {
            strokeSamples = []
            parent.onStrokeChanged([])
        }

        func beginPencilStroke(with touch: UITouch, in view: UIView) {
            guard parent.selectedTool != .fillBucket,
                  let sample = strokeSample(for: touch, in: view) else { return }
            strokeSamples = [sample]
            parent.onStrokeChanged(strokeSamples)
        }

        func appendPencilStroke(with touch: UITouch, in view: UIView) {
            guard parent.selectedTool != .fillBucket,
                  !strokeSamples.isEmpty,
                  let sample = strokeSample(for: touch, in: view) else { return }
            strokeSamples.append(sample)
            parent.onStrokeChanged(strokeSamples)
        }

        func endPencilStroke(with touch: UITouch, in view: UIView) {
            appendPencilStroke(with: touch, in: view)
            let completedSamples = strokeSamples
            strokeSamples = []
            parent.onStrokeChanged([])
            if completedSamples.count > 1 {
                parent.onStrokeEnded(completedSamples)
            }
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

private final class CanvasInteractionUIView: UIView {
    weak var coordinator: CanvasInteractionOverlay.Coordinator?

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
}

#if DEBUG
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

private struct ToolAdjustmentPanel: View {
    let tool: ToolType
    @Binding var size: CGFloat
    @Binding var opacity: Double
    let textureAmount: Double

    var body: some View {
        HStack(spacing: 14) {
            if tool.supportsSizeControl {
                BrushSizeScrubber(size: $size)
            }

            VStack(alignment: .leading, spacing: 9) {
                Label(tool.rawValue, systemImage: tool.systemImageName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(SableTheme.ink)
                    .lineLimit(1)

                Text(tool.supportsSizeControl ? "\(Int(size.rounded())) pt" : "Tap to fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(SableTheme.ink)
                    .monospacedDigit()

                if tool.supportsOpacityControl {
                    OpacityScrubber(opacity: $opacity)
                } else {
                    Text("Texture \(Int((textureAmount * 100).rounded()))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SableTheme.mutedInk)
                }
            }
            .frame(width: 148, alignment: .leading)
        }
        .frame(height: 108)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("canvas.tool.adjustments")
    }
}

private struct BrushSizeScrubber: View {
    @Binding var size: CGFloat

    private let trackHeight: CGFloat = 96
    private let trackWidth: CGFloat = 14
    private let thumbDisplayRange: ClosedRange<CGFloat> = 4...24

    @State private var isDragging = false

    var body: some View {
        let fraction = normalize(size, in: ToolSettings.sizeRange)

        ZStack(alignment: .bottom) {
            Capsule()
                .fill(.regularMaterial)
                .frame(width: trackWidth, height: trackHeight)
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.36), lineWidth: 1)
                }

            Capsule()
                .fill(SableTheme.progressPink.opacity(0.76))
                .frame(width: trackWidth, height: max(trackWidth, trackHeight * fraction))

            Circle()
                .fill(Color.white)
                .frame(width: displayDiameter(for: size), height: displayDiameter(for: size))
                .overlay {
                    Circle().stroke(Color.black.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.24), radius: 4, y: 2)
                .offset(y: -trackHeight * fraction + trackWidth / 2)
                .overlay(alignment: .trailing) {
                    if isDragging {
                        Text("\(Int(size.rounded())) pt")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(SableTheme.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.92), in: Capsule())
                            .offset(x: 48, y: -trackHeight * fraction + trackWidth / 2)
                            .transition(.opacity)
                    }
                }
        }
        .frame(width: 40, height: trackHeight)
        .contentShape(Rectangle().inset(by: -14))
        .gesture(dragGesture)
        .sensoryFeedback(.selection, trigger: Int(size.rounded()))
        .accessibilityLabel("Brush size")
        .accessibilityValue("\(Int(size.rounded())) points")
        .accessibilityIdentifier("canvas.brush.size")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let clampedY = min(max(0, trackHeight - value.location.y), trackHeight)
                let fraction = Double(clampedY / trackHeight)
                let nextSize = apply(fraction: fraction, to: ToolSettings.sizeRange)
                if !isDragging {
                    withAnimation(.easeOut(duration: 0.12)) {
                        isDragging = true
                    }
                }
                size = nextSize
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.12)) {
                    isDragging = false
                }
            }
    }

    private func apply(fraction: Double, to range: ClosedRange<CGFloat>) -> CGFloat {
        let shaped = fraction * fraction
        let lower = Double(range.lowerBound)
        let upper = Double(range.upperBound)
        return CGFloat(lower + (upper - lower) * shaped)
    }

    private func normalize(_ value: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let linear = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(sqrt(max(0, Double(linear))))
    }

    private func displayDiameter(for size: CGFloat) -> CGFloat {
        let range = ToolSettings.sizeRange
        let fraction = (size - range.lowerBound) / (range.upperBound - range.lowerBound)
        return thumbDisplayRange.lowerBound + (thumbDisplayRange.upperBound - thumbDisplayRange.lowerBound) * fraction
    }
}

private struct OpacityScrubber: View {
    @Binding var opacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Opacity")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SableTheme.mutedInk)
                Text("\(Int((opacity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(SableTheme.ink)
                    .monospacedDigit()
            }

            Slider(value: $opacity, in: ToolSettings.opacityRange)
                .tint(SableTheme.progressPink)
                .frame(width: 126)
                .accessibilityLabel("Opacity")
                .accessibilityValue("\(Int((opacity * 100).rounded())) percent")
                .accessibilityIdentifier("canvas.opacity")
        }
    }
}

private struct CanvasHUDView: View {
    let viewModel: ColoringSessionViewModel
    @Binding var showColorPicker: Bool
    @Binding var showPalettePicker: Bool
    @Binding var fingerPaints: Bool
    @Binding var isUIHidden: Bool
    let resetViewport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Undo", systemImage: "arrow.uturn.backward") {
                Task { await viewModel.undoLastFill() }
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canUndo)
            .accessibilityIdentifier(A11y.Canvas.undo)

            Button("Redo", systemImage: "arrow.uturn.forward") {
                Task { await viewModel.redoFill() }
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canRedo)
            .accessibilityIdentifier(A11y.Canvas.redo)

            ToolDockView(viewModel: viewModel)

            LinesModeToggle(viewModel: viewModel)

            CompactColorControl(
                viewModel: viewModel,
                showColorPicker: $showColorPicker,
                showPalettePicker: $showPalettePicker
            )

            Button("Finger", systemImage: fingerPaints ? "hand.draw.fill" : "hand.draw") {
                fingerPaints.toggle()
            }
            .labelStyle(.iconOnly)

            Button("Reset View", systemImage: "arrow.counterclockwise", action: resetViewport)
                .labelStyle(.iconOnly)

            Button(isUIHidden ? "Show UI" : "Hide UI", systemImage: isUIHidden ? "eye" : "eye.slash") {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isUIHidden.toggle()
                }
            }
            .labelStyle(.iconOnly)
        }
        .font(.system(size: 16, weight: .bold))
        .tint(SableTheme.progressPink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.36), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityIdentifier("canvas.bottomHUD")
    }
}

private struct ToolDockView: View {
    let viewModel: ColoringSessionViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ToolType.allCases) { tool in
                Button {
                    viewModel.selectTool(tool)
                } label: {
                    Image(systemName: tool.systemImageName)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(viewModel.selectedTool == tool ? .white : SableTheme.ink)
                        .frame(width: 34, height: 34)
                        .background(viewModel.selectedTool == tool ? SableTheme.cardBlack : Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.rawValue)
                .accessibilityIdentifier("canvas.tool.\(tool.rawValue.normalizedIdentifier)")
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct LinesModeToggle: View {
    let viewModel: ColoringSessionViewModel

    var body: some View {
        Picker("Lines", selection: Binding(
            get: { viewModel.coloringMode },
            set: { viewModel.selectColoringMode($0) }
        )) {
            Text("Lines Closed").tag(CanvasColoringMode.clean)
            Text("Lines Open").tag(CanvasColoringMode.free)
        }
        .pickerStyle(.segmented)
        .frame(width: 226)
        .accessibilityIdentifier("canvas.cleanFreeToggle")
    }
}

private struct CompactColorControl: View {
    let viewModel: ColoringSessionViewModel
    @Binding var showColorPicker: Bool
    @Binding var showPalettePicker: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showColorPicker.toggle()
            } label: {
                Circle()
                    .fill(Color(hex: viewModel.selectedColorHex))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                BottomColorWheelView(viewModel: viewModel)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("Color picker")
            .accessibilityIdentifier("canvas.color.compact")

            Button("Palette", systemImage: "paintpalette.fill") {
                showPalettePicker.toggle()
            }
            .labelStyle(.iconOnly)
            .popover(isPresented: $showPalettePicker, arrowEdge: .bottom) {
                PalettePickerPopover(viewModel: viewModel)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityIdentifier("canvas.palette.popover")
        }
    }
}

private struct BottomColorWheelView: View {
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
                            Circle().stroke(viewModel.selectedColorHex == hex ? SableTheme.cardBlack : Color.white, lineWidth: 3)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(SableTheme.cream)
    }
}

private struct PalettePickerPopover: View {
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
                            .foregroundStyle(SableTheme.ink)
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
        .background(SableTheme.cream)
    }
}

private struct PrecisionSliderRail: View {
    let tool: ToolType
    @Binding var size: CGFloat
    @Binding var opacity: Double

    var body: some View {
        VStack(spacing: 14) {
            if tool.supportsSizeControl {
                BrushSizeScrubber(size: $size)
            }
            if tool.supportsOpacityControl {
                VStack(spacing: 8) {
                    Text("\(Int((opacity * 100).rounded()))")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(SableTheme.ink)
                    Slider(value: $opacity, in: ToolSettings.opacityRange)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 104, height: 34)
                }
                .frame(width: 44, height: 120)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("canvas.precisionSliders")
    }
}

private struct CanvasTopControls: View {
    let onSettings: () -> Void
    let onShare: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("Settings", systemImage: "gearshape.fill", action: onSettings)
            Button("Share", systemImage: "square.and.arrow.up", action: onShare)
            Button("Done", systemImage: "checkmark", action: onDone)
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 17, weight: .bold))
        .tint(SableTheme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("canvas.topControls")
    }
}

private struct CanvasSettingsSheet: View {
    @Binding var precisionSlidersEnabled: Bool
    @Binding var opacityEnabled: Bool
    @Binding var eyedropperShortcutEnabled: Bool
    @Binding var colorHistoryEnabled: Bool
    @Binding var leftHandedMode: Bool
    @Binding var toolPreviewEnabled: Bool
    @Binding var brushSoundsEnabled: Bool
    @Binding var colorBlindMode: Bool
    let onRestart: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Actions") {
                    Button("Restart", systemImage: "arrow.counterclockwise", action: onRestart)
                    Button("Duplicate", systemImage: "doc.on.doc", action: onDuplicate)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                }

                Section("Coloring Settings") {
                    Toggle("Precision Sliders", isOn: $precisionSlidersEnabled)
                    Toggle("Opacity", isOn: $opacityEnabled)
                    Toggle("Eyedropper Shortcut", isOn: $eyedropperShortcutEnabled)
                    Toggle("Color History", isOn: $colorHistoryEnabled)
                    Toggle("Left-Handed Mode", isOn: $leftHandedMode)
                    Toggle("Tool Preview", isOn: $toolPreviewEnabled)
                    Toggle("ASMR / Brush Sounds", isOn: $brushSoundsEnabled)
                    Toggle("Color Blind Mode", isOn: $colorBlindMode)
                    Button("Learn the Basics", systemImage: "questionmark.circle") {}
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
