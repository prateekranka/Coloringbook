import SwiftUI
import PencilKit

/// Main coloring canvas screen.
///
/// The SwiftUI layer is responsible for:
///   - Screen chrome (toolbar, sheets, fill-progress overlay)
///   - Loading the template on first appearance
///
/// All pixel layers (background, fill image, PencilKit strokes, line-art
/// overlay) live inside `PencilCanvasRepresentable` so that PKCanvasView's
/// built-in UIScrollView zoom/pan keeps every layer in sync automatically.
struct CanvasView: View {
    @StateObject var viewModel: CanvasViewModel
    @State private var showToolbar = true
    @State private var showColorPicker = false
    @State private var showLayerPanel = false

    var body: some View {
        ZStack {
            // Single representable that hosts ALL pixel layers internally.
            // Zoom/pan is provided by PKCanvasView's UIScrollView; finger
            // taps are intercepted by the representable's gesture recogniser
            // and forwarded to the view model.
            PencilCanvasRepresentable(viewModel: viewModel)
                .ignoresSafeArea()

            // Flood-fill progress overlay — intentionally outside the
            // representable so it floats above the canvas at screen coords.
            if viewModel.isFilling {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ProgressView("Filling…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        // ── Side toolbar ──────────────────────────────────────────────────
        .overlay(alignment: .leading) {
            if showToolbar {
                ToolbarView(
                    viewModel: viewModel,
                    showColorPicker: $showColorPicker,
                    showLayerPanel: $showLayerPanel
                )
                .transition(.move(edge: .leading))
            }
        }
        // ── Toolbar toggle button (top-leading corner) ────────────────────
        .overlay(alignment: .topLeading) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showToolbar.toggle()
                }
            } label: {
                Image(systemName: showToolbar
                      ? "chevron.left.circle.fill"
                      : "chevron.right.circle.fill")
                    .font(.title2)
                    .padding(12)
            }
            .tint(.primary)
        }
        // ── Sheets ────────────────────────────────────────────────────────
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedColor: $viewModel.brushSettings.color,
                recentColors: $viewModel.recentColors,
                palettes: viewModel.palettes
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showLayerPanel) {
            LayerPanelView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        // ── Lifecycle ─────────────────────────────────────────────────────
        .task {
            await viewModel.loadTemplate()
        }
        .navigationBarHidden(true)
    }
}
