import SwiftUI
import UIKit

@MainActor
struct ColoringCanvasView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(RenderTuningStore.self) private var renderTuning
    @State private var viewModel: ColoringSessionViewModel
    @State private var viewport = CanvasViewport()
    @State private var gestureStartScale = CanvasViewport.minimumScale
    @State private var gestureStartOffset = CGSize.zero
    @State private var showClearArtworkConfirmation = false
    @State private var fillFeedbackID: UUID?
    @State private var isUIHidden = false
    @State private var liveStrokePoints: [CGPoint] = []
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
        VStack(spacing: 16) {
            if !isUIHidden {
                canvasHeader
            }

            GeometryReader { proxy in
                let availableSize = proxy.size
                let canvasSize = fittedCanvasSize(in: availableSize)

                ZStack {
                    SableTheme.paper

                    if let fillLayerImage = viewModel.fillLayerImage {
                        Image(uiImage: fillLayerImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    }

                    if let lineArtImage = viewModel.lineArtImage {
                        Image(uiImage: lineArtImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .blendMode(.multiply)
                    }

                    if fillFeedbackID != nil {
                        fillFeedback
                    }

                    if !liveStrokePoints.isEmpty {
                        LiveStrokePreview(points: liveStrokePoints, colorHex: viewModel.selectedColorHex, settings: viewModel.selectedToolSettings)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                        .stroke(SableTheme.cardBlack, lineWidth: 2)
                }
                .shadow(color: Color.black.opacity(0.2), radius: 18, x: 0, y: 10)
                .position(x: availableSize.width / 2, y: availableSize.height / 2)
                .scaleEffect(viewport.scale)
                .offset(viewport.offset)
                .contentShape(Rectangle())
                .gesture(tapToFillGesture(canvasSize: canvasSize))
                .simultaneousGesture(
                    panGesture(canvasSize: canvasSize, viewportSize: availableSize)
                )
                .simultaneousGesture(
                    zoomGesture(canvasSize: canvasSize, viewportSize: availableSize)
                )
                .simultaneousGesture(
                    drawGesture(canvasSize: canvasSize)
                )
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel(viewModel.title)
                .accessibilityIdentifier(A11y.Canvas.surface)
            }

            if !isUIHidden {
                toolDock
                colorDock
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 22)
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

            Text("\(Int((viewport.scale * 100).rounded()))%")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(SableTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.78), in: Capsule())
                .accessibilityLabel("Zoom \(Int((viewport.scale * 100).rounded())) percent")
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

    private func tapToFillGesture(canvasSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard viewModel.selectedTool == .fillBucket else { return }
                Task {
                    let didFill = await viewModel.fill(
                        atCanvasPoint: value.location,
                        canvasSize: canvasSize
                    )
                    if didFill {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showFillFeedback()
                        }
                    }
                }
            }
    }

    private func panGesture(canvasSize: CGSize, viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                viewport.updateOffset(
                    from: gestureStartOffset,
                    translation: value.translation,
                    canvasSize: canvasSize,
                    viewportSize: viewportSize
                )
            }
            .onEnded { value in
                viewport.updateOffset(
                    from: gestureStartOffset,
                    translation: value.translation,
                    canvasSize: canvasSize,
                    viewportSize: viewportSize
                )
                gestureStartOffset = viewport.offset
            }
    }

    private func drawGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard viewModel.selectedTool != .fillBucket else { return }
                if liveStrokePoints.isEmpty {
                    liveStrokePoints = [value.startLocation]
                }
                liveStrokePoints.append(value.location)
            }
            .onEnded { value in
                guard viewModel.selectedTool != .fillBucket else { return }
                liveStrokePoints.append(value.location)
                let points = liveStrokePoints
                liveStrokePoints = []
                Task {
                    _ = await viewModel.drawStroke(canvasPoints: points, canvasSize: canvasSize)
                }
            }
    }

    private func zoomGesture(canvasSize: CGSize, viewportSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                viewport.updateScale(
                    from: gestureStartScale,
                    magnification: magnification,
                    canvasSize: canvasSize,
                    viewportSize: viewportSize
                )
            }
            .onEnded { magnification in
                viewport.updateScale(
                    from: gestureStartScale,
                    magnification: magnification,
                    canvasSize: canvasSize,
                    viewportSize: viewportSize
                )
                gestureStartScale = viewport.scale
                gestureStartOffset = viewport.offset
            }
    }

    private func resetViewport() {
        viewport.reset()
        gestureStartScale = viewport.scale
        gestureStartOffset = viewport.offset
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

private struct LiveStrokePreview: View {
    let points: [CGPoint]
    let colorHex: String
    let settings: ToolSettings

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(settings.tool == .eraser ? .white.opacity(0.55) : Color(hex: colorHex).opacity(settings.opacity)),
                style: StrokeStyle(lineWidth: settings.size, lineCap: .round, lineJoin: .round)
            )
        }
        .allowsHitTesting(false)
    }
}

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
