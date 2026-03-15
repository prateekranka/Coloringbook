import SwiftUI
import PencilKit

/// Main coloring canvas. Layer order (bottom → top):
///   1. Background color
///   2. Fill layer (flood-filled regions)
///   3. PencilKit canvas (pencil strokes)
///   4. Template line art overlay (.multiply blend mode)
struct CanvasView: View {
    @StateObject var viewModel: CanvasViewModel
    @State private var showToolbar = true
    @State private var showColorPicker = false
    @State private var showLayerPanel = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Background color
                viewModel.backgroundColor

                // 2. Flood fill layer
                if let fillImage = viewModel.fillLayerImage {
                    Image(uiImage: fillImage)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                // 3. PencilKit drawing layer
                PencilCanvasRepresentable(
                    drawing: $viewModel.drawing,
                    tool: viewModel.currentPKTool,
                    onDrawingChanged: { viewModel.scheduleAutoSave() },
                    onCanvasReady: { viewModel.pencilCanvas = $0 }
                )

                // 4. Template line art (always on top, multiply blend)
                if let templateImage = viewModel.templateImage {
                    Image(uiImage: templateImage)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blendMode(.multiply)
                        .allowsHitTesting(false)
                }

                // Flood fill progress overlay
                if viewModel.isFilling {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("Filling…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTap(at: location, in: geo.size)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .leading) {
            if showToolbar {
                ToolbarView(viewModel: viewModel, showColorPicker: $showColorPicker, showLayerPanel: $showLayerPanel)
                    .transition(.move(edge: .leading))
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                withAnimation { showToolbar.toggle() }
            } label: {
                Image(systemName: showToolbar ? "chevron.left.circle.fill" : "chevron.right.circle.fill")
                    .font(.title2)
                    .padding(12)
            }
            .tint(.primary)
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(selectedColor: $viewModel.brushSettings.color,
                           recentColors: $viewModel.recentColors,
                           palettes: viewModel.palettes)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showLayerPanel) {
            LayerPanelView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .task {
            await viewModel.loadTemplate()
        }
        .navigationBarHidden(true)
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        switch viewModel.brushSettings.tool {
        case .floodFill:
            Task { await viewModel.performFloodFill(at: location, in: size) }
        case .eyedropper:
            viewModel.pickColor(at: location, in: size)
        default:
            break  // PencilKit handles pencil/marker/eraser
        }
    }
}
