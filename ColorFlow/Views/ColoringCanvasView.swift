import SwiftUI
import UIKit

@MainActor
struct ColoringCanvasView: View {
    @State private var viewModel: ColoringSessionViewModel
    @State private var viewport = CanvasViewport()
    @State private var gestureStartScale = CanvasViewport.minimumScale
    @State private var gestureStartOffset = CGSize.zero
    @State private var showClearArtworkConfirmation = false
    @State private var fillFeedbackID: UUID?

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
    }

    private var readyBody: some View {
        VStack(spacing: 16) {
            canvasHeader

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
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel(viewModel.title)
                .accessibilityIdentifier(A11y.Canvas.surface)
            }

            colorDock
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 22)
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

    private func colorSwatchButton(_ swatch: ColorSwatch) -> some View {
        Button {
            viewModel.selectColor(hex: swatch.hex)
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: swatch.hex))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Circle()
                            .stroke(
                                viewModel.selectedColorHex == swatch.hex ? SableTheme.cardBlack : .white,
                                lineWidth: viewModel.selectedColorHex == swatch.hex ? 4 : 2
                            )
                    }
                    .shadow(color: Color.black.opacity(0.16), radius: 5, x: 0, y: 3)

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
}
