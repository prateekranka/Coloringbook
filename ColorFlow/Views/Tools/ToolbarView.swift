import SwiftUI

/// Collapsible left-side toolbar with tool selection, brush size, and undo/redo.
struct ToolbarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var showColorPicker: Bool
    @Binding var showLayerPanel: Bool
    var onDismiss: (() -> Void)? = nil
    var onToggleToolbar: (() -> Void)? = nil
    var onFitToScreen: (() -> Void)? = nil
    var onExport: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 4) {
            // Back + toggle row at the top of the panel
            HStack(spacing: 0) {
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                Spacer(minLength: 0)
                if let onToggleToolbar {
                    Button(action: onToggleToolbar) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide toolbar")
                }
            }

            Divider().padding(.horizontal, 6)

            // Color well — opens full color picker sheet
            ColorWellButton(color: viewModel.brushSettings.color) {
                showColorPicker = true
            }

            Divider().padding(.horizontal, 6)

            // Drawing tools
            ForEach(DrawingTool.allCases) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: viewModel.brushSettings.tool == tool
                ) {
                    HapticService.shared.impact(.light)
                    viewModel.brushSettings.tool = tool
                }
            }

            Divider().padding(.horizontal, 6)

            // Brush size slider (vertical)
            BrushSizeSlider(size: $viewModel.brushSettings.size)

            Divider().padding(.horizontal, 6)

            // Opacity slider (vertical)
            OpacitySlider(opacity: $viewModel.brushSettings.opacity)

            Divider().padding(.horizontal, 6)

            // Undo / Redo
            Button { viewModel.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Undo")

            Button { viewModel.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Redo")

            Divider().padding(.horizontal, 6)

            // Layers
            Button { showLayerPanel = true } label: {
                Image(systemName: "square.3.layers.3d")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Layers")
            .accessibilityHint("Opens layer panel")

            Divider().padding(.horizontal, 6)

            // Fit to screen
            Button { onFitToScreen?() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Fit to screen")

            // Export
            Button { onExport?() } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Export artwork")
            .accessibilityHint("Share or save your artwork")

            // Sound toggle
            Button {
                viewModel.soundEnabled.toggle()
            } label: {
                Image(systemName: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .toolbarButtonStyle()
            .foregroundStyle(viewModel.soundEnabled ? Color.accentColor : Color.primary)
            .accessibilityLabel(viewModel.soundEnabled ? "Disable sounds" : "Enable sounds")

            Divider().padding(.horizontal, 6)

            // Symmetry toggle
            Button {
                viewModel.symmetryEnabled.toggle()
                HapticService.shared.impact(.light)
            } label: {
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(viewModel.symmetryEnabled ? Color.accentColor : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.symmetryEnabled ? Color.accentColor.opacity(0.15) : Color.clear)
                            .frame(width: 40, height: 40)
                    )
            }
            .toolbarButtonStyle()
            .accessibilityLabel(viewModel.symmetryEnabled ? "Disable mirror symmetry" : "Enable mirror symmetry")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.leading, 12)
        .padding(.top, 12)
    }
}

// MARK: - Sub-components

private struct ColorWellButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1.5))
                .padding(6)
        }
        .accessibilityLabel("Brush color")
        .accessibilityHint("Opens color picker")
    }
}

private struct ToolButton: View {
    let tool: DrawingTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImageName)
                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.accessibilityName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BrushSizeSlider: View {
    @Binding var size: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            // Preview dot
            Circle()
                .fill(Color.primary)
                .frame(width: size.clamped(to: 4...24), height: size.clamped(to: 4...24))
                .frame(height: 28)

            Slider(value: $size, in: BrushSettings.sizeRange)
                .accessibilityLabel("Brush size")
                .accessibilityValue("\(Int(size)) points")
                .rotationEffect(.degrees(-90))
                .frame(width: 100)
                .frame(width: 44, height: 100)
        }
    }
}

private struct OpacitySlider: View {
    @Binding var opacity: Double

    var body: some View {
        VStack(spacing: 4) {
            // Opacity preview
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(opacity))
                .frame(width: 20, height: 20)
                .frame(height: 28)

            Slider(value: $opacity, in: 0.05...1.0)
                .accessibilityLabel("Brush opacity")
                .accessibilityValue("\(Int(opacity * 100)) percent")
                .rotationEffect(.degrees(-90))
                .frame(width: 100)
                .frame(width: 44, height: 100)
        }
    }
}

// MARK: - ViewModifier

private extension View {
    func toolbarButtonStyle() -> some View {
        self
            .font(.system(size: 18))
            .frame(width: 40, height: 40)
            .buttonStyle(.plain)
            .foregroundStyle(Color.primary)
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
