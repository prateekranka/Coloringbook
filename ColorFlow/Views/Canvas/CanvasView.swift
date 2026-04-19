import SwiftUI
import PencilKit

/// Main coloring canvas screen.
///
/// Layout invariants:
/// - Canvas is always full-bleed. Chrome lives in a ZStack overlay so that
///   hiding the toolbar does not resize the canvas (prevents "canvas jump").
/// - Color picker appears as a floating, draggable HUD window over the canvas,
///   not a sheet — the canvas stays interactive behind it.
struct CanvasView: View {
    @Bindable var viewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showToolbar = true
    @State private var showColorPicker = false
    @State private var showLayerPanel = false

    /// Width of the left chrome lane. Kept constant so canvas width never changes
    /// when the toolbar hides/shows.
    private let chromeGutter: CGFloat = 72

    var body: some View {
        ZStack {
            // Canvas (always full-bleed)
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

            // Floating color picker (HUD window)
            if showColorPicker {
                FloatingColorPickerWindow(
                    isPresented: $showColorPicker,
                    selectedColor: $viewModel.brushSettings.color,
                    recentColors: $viewModel.recentColors,
                    palettes: viewModel.palettes
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .ignoresSafeArea()
            }

            // ── Chrome lane (toolbar or retracted restore button) ─────────
            chromeLane
        }
        .onAppear {
            AppLog.trace(AppLog.canvas, "CanvasView onAppear — \(viewModel.template.svgFilename)")
        }
        // ── Sheets (layer panel only; color picker is now an overlay) ──
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

    // MARK: - Chrome lane

    @ViewBuilder
    private var chromeLane: some View {
        HStack(alignment: .top, spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Reserve the gutter width regardless of toolbar state so the
                // canvas behind this ZStack never shifts horizontally.
                Color.clear
                    .frame(width: chromeGutter)

                if showToolbar {
                    ToolbarView(
                        viewModel: viewModel,
                        showColorPicker: $showColorPicker,
                        showLayerPanel: $showLayerPanel,
                        onDismiss: { dismiss() },
                        onToggleToolbar: {
                            withAnimation(AppTheme.Motion.pageTransition) {
                                showToolbar.toggle()
                            }
                        }
                    )
                    .fixedSize()
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    restoreButton
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // When the toolbar is hidden, a single small button (not two) lets the user
    // restore it. The back-to-gallery affordance lives inside the toolbar, so
    // we don't repeat the "<" chevron here.
    private var restoreButton: some View {
        Button {
            withAnimation(AppTheme.Motion.pageTransition) {
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
        .padding(.leading, 16)
        .padding(.top, 72)
    }
}
