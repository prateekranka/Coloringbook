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
    @State private var showExport = false
    @State private var showAmbientSound = false
    @EnvironmentObject private var soundService: AmbientSoundService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Single representable that hosts ALL pixel layers internally.
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
        }
        // ── Side toolbar ──────────────────────────────────────────────────
        .overlay(alignment: .leading) {
            if showToolbar {
                ToolbarView(
                    viewModel: viewModel,
                    showColorPicker: $showColorPicker,
                    showLayerPanel: $showLayerPanel,
                    showAmbientSound: $showAmbientSound
                )
                .transition(.move(edge: .leading))
            }
        }
        // ── Toolbar toggle (top-leading) ───────────────────────────────────
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
        // ── Export + Close (top-trailing) ─────────────────────────────────
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 0) {
                Button {
                    viewModel.save()
                    showExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.title2)
                        .padding(12)
                }
                .tint(.primary)

                Button {
                    viewModel.save()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .padding(12)
                }
                .tint(.primary)
            }
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
        .sheet(isPresented: $showAmbientSound) {
            AmbientSoundView(soundService: soundService)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showExport) {
            ExportOptionsView(viewModel: viewModel)
        }
        // ── Lifecycle ─────────────────────────────────────────────────────
        .task {
            await viewModel.loadTemplate()
        }
        .navigationBarHidden(true)
    }
}
