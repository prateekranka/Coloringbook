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
    @ObservedObject var viewModel: CanvasViewModel
    @State private var showToolbar = true
    @State private var showColorPicker = false
    @State private var showLayerPanel = false

    var body: some View {
        ZStack {
            // Canvas (fills entire screen including safe areas)
            Color.white.ignoresSafeArea()
            PencilCanvasRepresentable(viewModel: viewModel)
                .ignoresSafeArea()

            // Flood-fill progress overlay
            if viewModel.isFilling {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                ProgressView("Filling…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // ── Chrome layer (toolbar + back button) ──────────────────────
            // Use an HStack so the toolbar is always left-anchored regardless
            // of safe-area or presentation context.
            VStack(spacing: 0) {
                // Back / hide-toolbar button pinned to top-leading
                HStack {
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
                    Spacer()
                }

                // Toolbar below the button, left-aligned
                HStack(alignment: .top, spacing: 0) {
                    if showToolbar {
                        ToolbarView(
                            viewModel: viewModel,
                            showColorPicker: $showColorPicker,
                            showLayerPanel: $showLayerPanel
                        )
                        .transition(.move(edge: .leading))
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea(edges: .all)
        .onAppear {
            NSLog("[CanvasView] onAppear — template: %@", viewModel.template.svgFilename)
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
        .toolbar(.hidden, for: .navigationBar)
    }
}
