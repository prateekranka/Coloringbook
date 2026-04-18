import SwiftUI

// MARK: - Toolbar (tools capsule — left edge)

/// Floating vertical glass capsule housing the back button, color well,
/// drawing tools, and brush-size slider. Lives on the leading edge of the
/// canvas. Zoom and undo/redo are split into the right-side `CanvasUtilityBar`.
struct ToolbarView: View {
    @Bindable var viewModel: CanvasViewModel
    @Binding var showColorPicker: Bool
    @Binding var showLayerPanel: Bool
    var onDismiss: (() -> Void)? = nil
    var onToggleToolbar: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            if let onDismiss {
                ToolbarIconButton(system: "chevron.left",
                                  label: "Back to gallery",
                                  identifier: "canvas.back",
                                  action: onDismiss)
            }
            if let onToggleToolbar {
                ToolbarIconButton(system: "sidebar.left",
                                  label: "Hide toolbar",
                                  identifier: "canvas.toolbar.toggle",
                                  action: onToggleToolbar)
            }

            ToolbarDivider()

            ColorWellButton(color: viewModel.brushSettings.color) {
                HapticService.shared.toolChanged()
                showColorPicker = true
            }

            ToolbarDivider()

            ForEach(DrawingTool.allCases) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: viewModel.brushSettings.tool == tool
                ) {
                    HapticService.shared.toolChanged()
                    viewModel.brushSettings.tool = tool
                }
            }

            ToolbarDivider()

            BrushSizeSlider(size: $viewModel.brushSettings.size)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .floatingShadow()
        .padding(.leading, 16)
        .padding(.top, 16)
    }
}

// MARK: - Utility bar (zoom / undo / redo / layers — right edge)

struct CanvasUtilityBar: View {
    @Bindable var viewModel: CanvasViewModel
    @Binding var showLayerPanel: Bool

    var body: some View {
        VStack(spacing: 6) {
            ToolbarIconButton(system: "arrow.uturn.backward",
                              label: "Undo",
                              identifier: "canvas.undo") {
                HapticService.shared.undoRedo()
                viewModel.undo()
            }
            ToolbarIconButton(system: "arrow.uturn.forward",
                              label: "Redo",
                              identifier: "canvas.redo") {
                HapticService.shared.undoRedo()
                viewModel.redo()
            }

            ToolbarDivider()

            ToolbarIconButton(system: "square.3.layers.3d",
                              label: "Layers",
                              identifier: "canvas.layers") {
                HapticService.shared.toolChanged()
                showLayerPanel = true
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .floatingShadow()
        .padding(.trailing, 16)
        .padding(.top, 16)
    }
}

// MARK: - Sub-components

private struct ColorWellButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentGradient)
                    .frame(width: 38, height: 38)
                    .opacity(0.6)
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
            }
            .frame(width: AppTheme.minTapTarget, height: AppTheme.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Selected color")
        .accessibilityHint("Opens the color picker")
        .accessibilityIdentifier("canvas.colorWell")
    }
}

private struct ToolButton: View {
    let tool: DrawingTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImageName)
                .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : Color.primary)
                .frame(width: AppTheme.minTapTarget, height: AppTheme.minTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected
                              ? AnyShapeStyle(AppTheme.accentGradient)
                              : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    // Active glow
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.accent.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
                        .blur(radius: isSelected ? 4 : 0)
                )
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("canvas.tool.\(tool.rawValue.lowercased())")
    }
}

private struct BrushSizeSlider: View {
    @Binding var size: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.primary)
                .frame(width: size.clamped(to: 4...24), height: size.clamped(to: 4...24))
                .frame(height: 28)

            Slider(value: $size, in: BrushSettings.sizeRange)
                .rotationEffect(.degrees(-90))
                .frame(width: 110)
                .frame(width: 44, height: 110)
                .tint(AppTheme.accent)
                .accessibilityLabel("Brush size")
                .accessibilityValue("\(Int(size)) points")
                .accessibilityIdentifier("canvas.brushSize")
        }
    }
}

/// Icon-only button used across both toolbars for consistency.
private struct ToolbarIconButton: View {
    let system: String
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: AppTheme.minTapTarget, height: AppTheme.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
