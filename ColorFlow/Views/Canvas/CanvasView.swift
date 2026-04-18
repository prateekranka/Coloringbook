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

            // Branded flood-fill progress overlay.
            if viewModel.isFilling {
                FillProgressOverlay(color: viewModel.brushSettings.color)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── Chrome layer (floating glass toolbars) ────────────────────
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
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    VStack(spacing: 8) {
                        FloatingIconButton(system: "chevron.left",
                                           label: "Back to gallery",
                                           identifier: "canvas.back.floating") {
                            dismiss()
                        }
                        FloatingIconButton(system: "sidebar.left",
                                           label: "Show toolbar",
                                           identifier: "canvas.toolbar.restore") {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showToolbar.toggle()
                            }
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 16)
                }
                Spacer(minLength: 0)

                // Right-side utility capsule (undo / redo / layers).
                CanvasUtilityBar(
                    viewModel: viewModel,
                    showLayerPanel: $showLayerPanel
                )
                .fixedSize()
                .transition(.move(edge: .trailing).combined(with: .opacity))
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

// MARK: - Fill progress overlay

/// Subtle branded overlay shown while a flood-fill render is in flight.
/// Uses a radial pulse of the current brush color instead of a generic
/// `ProgressView("Filling…")`.
private struct FillProgressOverlay: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.45), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: pulse ? 260 : 80
                    )
                )
                .frame(width: 520, height: 520)
                .scaleEffect(pulse ? 1.1 : 0.8)
                .opacity(pulse ? 0 : 0.9)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

/// Compact floating circular button used when the main toolbar is hidden.
private struct FloatingIconButton: View {
    let system: String
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .floatingShadow()
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
