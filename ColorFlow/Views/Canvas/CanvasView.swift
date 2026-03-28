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
    @Environment(\.dismiss) private var dismiss
    @State private var showToolbar = true
    @State private var showColorPicker = false
    @State private var showLayerPanel = false
    @State private var showSaveIndicator = false
    @State private var showExportSheet = false
    @State private var exportImage: UIImage?
    @State private var skeletonThumbnail: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Canvas (fills entire screen including safe areas)
            Color.white.ignoresSafeArea()
            PencilCanvasRepresentable(viewModel: viewModel)
                .ignoresSafeArea()
                .accessibilityLabel("Coloring canvas")
                .accessibilityHint("Draw with Apple Pencil, or tap to fill regions")
                .accessibilityAddTraits(.allowsDirectInteraction)

            // Skeleton thumbnail — shown while loadTemplate() is running, then crossfades out
            if viewModel.templateImage == nil, let skeleton = skeletonThumbnail {
                Image(uiImage: skeleton)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 24)
                    .overlay(Color.black.opacity(0.15).ignoresSafeArea())
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.templateImage != nil)
            }

            // Flood-fill progress overlay
            if viewModel.isFilling {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                ProgressView("Filling…")
                    .accessibilityLabel("Filling region, please wait")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // Save failure banner
            if viewModel.saveError {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Could not save your work.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button("Retry") {
                            viewModel.saveError = false
                            viewModel.save()
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.saveError)
            }

            // "Saved ✓" indicator
            if showSaveIndicator {
                VStack {
                    HStack {
                        Spacer()
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.85), in: Capsule())
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showSaveIndicator)
                .allowsHitTesting(false)
            }

            // Completion % badge (top-right, below save indicator)
            if viewModel.completionPercentage > 0 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(Int(viewModel.completionPercentage * 100))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45), in: Capsule())
                            .padding(.top, 52)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
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
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                                showToolbar.toggle()
                            }
                        },
                        onFitToScreen: {
                            viewModel.fitToScreen()
                        },
                        onExport: {
                            Task {
                                let vm = viewModel
                                let image = await Task.detached(priority: .userInitiated) {
                                    ExportService().compositeImage(
                                        geometry: vm.templateGeometry,
                                        fills: vm.regionFills,
                                        drawing: vm.drawing,
                                        background: vm.backgroundColor,
                                        canvasSize: vm.canvasSize
                                    )
                                }.value
                                exportImage = image
                                showExportSheet = true
                                HapticService.shared.notify(.success)
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
                        .accessibilityLabel("Back")

                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                                showToolbar.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.title3)
                                .padding(10)
                                .background(.regularMaterial, in: Circle())
                        }
                        .tint(.primary)
                        .accessibilityLabel("Show toolbar")
                    }
                    .padding(.leading, 12)
                    .padding(.top, 12)
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            NSLog("[CanvasView] onAppear — template: %@", viewModel.template.svgFilename)
            // Pre-load the saved thumbnail as a skeleton while the template loads
            let thumbnailPath = viewModel.project.thumbnailPath
            Task.detached(priority: .background) {
                let url = StorageService.documentsURL.appendingPathComponent(thumbnailPath)
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    await MainActor.run { skeletonThumbnail = img }
                }
            }
        }
        // ── Sheets ────────────────────────────────────────────────────────
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedColor: $viewModel.brushSettings.color,
                recentColors: $viewModel.recentColors,
                favoriteColors: $viewModel.favoriteColors,
                palettes: viewModel.palettes,
                onToggleFavorite: { viewModel.toggleFavoriteColor($0) }
            )
            .presentationDetents([.height(280), .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .height(280)))
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExportSheet) {
            if let img = exportImage {
                ShareSheet(image: img)
            }
        }
        .sheet(isPresented: $showLayerPanel) {
            LayerPanelView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        // ── Lifecycle ─────────────────────────────────────────────────────
        .task {
            await viewModel.loadTemplate()
        }
        .onChange(of: viewModel.lastSaveTime) { _, newValue in
            guard newValue != nil else { return }
            showSaveIndicator = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showSaveIndicator = false
            }
        }
        .alert("Template Error", isPresented: Binding(
            get: { viewModel.loadError != nil },
            set: { if !$0 { viewModel.loadError = nil } }
        )) {
            Button("Go Back") {
                viewModel.loadError = nil
                dismiss()
            }
        } message: {
            Text("This template couldn't be loaded. Please try a different one.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
