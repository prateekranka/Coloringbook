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
    @Bindable var viewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss
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

            // ── Chrome layer (toolbar) ────────────────────────────────────
            // NOTE: do NOT put .ignoresSafeArea on the ZStack itself — that
            // clears safe-area insets for ALL children, hiding chrome under
            // the status bar.  Each full-bleed layer (canvas, white bg) has
            // its own .ignoresSafeArea() above.
            HStack(alignment: .top, spacing: 0) {
                if showToolbar {
                    ToolbarView(
                        viewModel: viewModel,
                        showColorPicker: $showColorPicker,
                        showLayerPanel: $showLayerPanel,
                        onDismiss: { dismiss() },
                        onToggleToolbar: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showToolbar.toggle()
                            }
                        }
                    )
                    .fixedSize()
                    .transition(.move(edge: .leading))
                } else {
                    // When toolbar is hidden, show a small floating button
                    // to restore it (back button is inside the toolbar).
                    VStack(spacing: 4) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .padding(10)
                                .background(.regularMaterial, in: Circle())
                        }
                        .tint(.primary)
                        .frame(minWidth: AppTheme.minTapTarget, minHeight: AppTheme.minTapTarget)
                        .accessibilityLabel("Back to gallery")
                        .accessibilityIdentifier("canvas.back.floating")

                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showToolbar.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.title3)
                                .padding(10)
                                .background(.regularMaterial, in: Circle())
                        }
                        .tint(.primary)
                        .frame(minWidth: AppTheme.minTapTarget, minHeight: AppTheme.minTapTarget)
                        .accessibilityLabel("Show toolbar")
                        .accessibilityIdentifier("canvas.toolbar.restore")
                    }
                    .padding(.leading, 12)
                    .padding(.top, 12)
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            AppLog.trace(AppLog.canvas, "CanvasView onAppear — \(viewModel.template.svgFilename)")
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
