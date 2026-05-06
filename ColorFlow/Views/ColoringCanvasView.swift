import SwiftUI
import UIKit

@MainActor
struct ColoringCanvasView: View {
    @State private var viewModel: ColoringSessionViewModel
    @State private var viewport = CanvasViewport()
    @State private var gestureStartScale = CanvasViewport.minimumScale
    @State private var gestureStartOffset = CGSize.zero

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
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel(viewModel.title)
                .accessibilityIdentifier("canvas.surface")
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

            Spacer()

            Text(viewModel.progressLabel)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(SableTheme.cardBlack, in: Capsule())
                .accessibilityIdentifier("canvas.progress")

            Text("\(Int((viewport.scale * 100).rounded()))%")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(SableTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.78), in: Capsule())
                .accessibilityLabel("Zoom \(Int((viewport.scale * 100).rounded())) percent")
                .accessibilityIdentifier("canvas.zoom")
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: 14) {
            Button("Reset View", systemImage: "arrow.counterclockwise", action: resetViewport)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("canvas.resetView")

            Button("Save", systemImage: viewModel.isSaving ? "checkmark.circle.fill" : "square.and.arrow.down") {
                viewModel.save()
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("canvas.save")
        }
        .font(.system(size: 18, weight: .bold))
        .tint(SableTheme.progressPink)
    }

    private var colorDock: some View {
        HStack(spacing: 13) {
            ForEach(viewModel.paletteHexes, id: \.self) { hex in
                Button {
                    viewModel.selectedColorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle()
                                .stroke(
                                    viewModel.selectedColorHex == hex ? SableTheme.cardBlack : .white,
                                    lineWidth: viewModel.selectedColorHex == hex ? 4 : 2
                                )
                        }
                        .shadow(color: Color.black.opacity(0.16), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hex)
                .accessibilityIdentifier("canvas.color.\(hex.normalizedColorIdentifier)")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.hairline, lineWidth: 1)
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
                    await viewModel.fill(
                        atCanvasPoint: value.location,
                        canvasSize: canvasSize
                    )
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

private extension String {
    var normalizedColorIdentifier: String {
        trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
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
