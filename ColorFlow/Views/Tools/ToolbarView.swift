import SwiftUI

/// Collapsible left-side toolbar with tool selection, brush settings, and
/// undo/redo. Inspired by Lake's active-tool pill + Pigment's tool drawer:
/// tapping an already-active tool opens a glass drawer to the right of the
/// rail that hosts the brush-size scrubber (and opacity, for inking tools).
struct ToolbarView: View {
    @Bindable var viewModel: CanvasViewModel
    @Binding var showColorPicker: Bool
    @Binding var showLayerPanel: Bool
    @Binding var showCanvasSettings: Bool
    var onDismiss: (() -> Void)? = nil
    var onToggleToolbar: (() -> Void)? = nil

    @State private var drawerTool: DrawingTool? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rail
            drawer
        }
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(spacing: 4) {
            // Back + retract row (retract only visible when toolbar is shown,
            // which it always is while this view exists).
            HStack(spacing: 0) {
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: AppTheme.Size.touchTarget, height: AppTheme.Size.touchTarget)
                            .foregroundStyle(AppTheme.Ink.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to gallery")
                    .accessibilityIdentifier("canvas.back")
                }
                Spacer(minLength: 0)
                if let onToggleToolbar {
                    Button(action: onToggleToolbar) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: AppTheme.Size.touchTarget, height: AppTheme.Size.touchTarget)
                            .foregroundStyle(AppTheme.Ink.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide toolbar")
                    .accessibilityIdentifier("canvas.toolbar.toggle")
                }
            }

            Divider().padding(.horizontal, 6)

            // Drawing tools
            ForEach(DrawingTool.allCases) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: viewModel.brushSettings.tool == tool
                ) {
                    HapticService.shared.impact(.light)
                    if viewModel.brushSettings.tool == tool {
                        toggleDrawer(for: tool)
                    } else {
                        viewModel.brushSettings.tool = tool
                        if toolSupportsDrawer(tool) {
                            drawerTool = tool
                        } else {
                            drawerTool = nil
                        }
                    }
                }
            }

            Divider().padding(.horizontal, 6)

            // Undo / Redo
            Button { viewModel.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Undo")
            .accessibilityIdentifier("canvas.undo")

            Button { viewModel.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Redo")
            .accessibilityIdentifier("canvas.redo")

            Divider().padding(.horizontal, 6)

            // Layers
            Button { showLayerPanel = true } label: {
                Image(systemName: "square.3.layers.3d")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Layers")
            .accessibilityIdentifier("canvas.layers")

            Button {
                showCanvasSettings = true
            } label: {
                Image(systemName: "ellipsis")
            }
            .toolbarButtonStyle()
            .accessibilityLabel("Canvas Settings")
            .accessibilityIdentifier("canvas.settings")

            Spacer(minLength: 10)

            // Color well anchors the bottom of the rail and opens the
            // floating picker window.
            ColorWellButton(color: viewModel.brushSettings.color) {
                showColorPicker = true
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.leading, 12)
        .padding(.top, 12)
    }

    // MARK: - Drawer

    @ViewBuilder
    private var drawer: some View {
        if let tool = drawerTool, toolSupportsDrawer(tool) {
            VStack(alignment: .leading, spacing: 14) {
                Text(drawerTitle(for: tool))
                    .font(Font.cfCaption)
                    .foregroundStyle(AppTheme.Ink.secondary)

                BrushSizeScrubber(size: $viewModel.brushSettings.size)

                // Opacity scrubber, inking tools only.
                if tool.isPencilKitTool && tool != .eraser {
                    OpacityScrubber(opacity: $viewModel.brushSettings.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.top, 12)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    private func toggleDrawer(for tool: DrawingTool) {
        withAnimation(AppTheme.Motion.pageTransition) {
            drawerTool = (drawerTool == tool) ? nil : tool
        }
    }

    private func toolSupportsDrawer(_ tool: DrawingTool) -> Bool {
        tool.isPencilKitTool
    }

    private func drawerTitle(for tool: DrawingTool) -> String {
        "\(tool.rawValue) size"
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
                .overlay(Circle().stroke(AppTheme.Ink.primary.opacity(0.25), lineWidth: 1.5))
                .glow(color: color.opacity(0.5), radius: 6)
                .padding(6)
                .frame(width: AppTheme.Size.touchTarget, height: AppTheme.Size.touchTarget)
                .contentShape(Rectangle())
        }
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
                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppTheme.Brand.accent : AppTheme.Ink.primary)
                .frame(width: AppTheme.Size.touchTarget, height: AppTheme.Size.touchTarget)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AppTheme.Brand.accentSubtle : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("canvas.tool.\(tool.rawValue.lowercased())")
    }
}

/// Thin horizontal opacity slider styled to match the BrushSizeScrubber.
private struct OpacityScrubber: View {
    @Binding var opacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Opacity")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.Ink.secondary)

            Slider(value: $opacity, in: 0.1...1)
                .tint(AppTheme.Brand.accent)
                .frame(width: 120)
                .accessibilityLabel("Opacity")
                .accessibilityValue("\(Int(opacity * 100)) percent")
                .accessibilityIdentifier("canvas.opacity")
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
            .foregroundStyle(AppTheme.Ink.primary)
    }
}
