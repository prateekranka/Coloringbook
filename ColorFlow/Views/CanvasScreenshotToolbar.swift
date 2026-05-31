import SwiftUI

struct CanvasScreenshotToolbar: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ColoringSessionViewModel
    @Binding var showColorPicker: Bool
    @Binding var showPalettePicker: Bool
    @Binding var showSettingsSheet: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void

    private let dockHeight: CGFloat = 86
    private let dockMaxWidth: CGFloat = 660

    private var dockBackground: Color {
        colorScheme == .dark
            ? Color(hex: "#151615").opacity(0.94)
            : Color(hex: "#1D1E1B").opacity(0.92)
    }

    private var dockBorder: Color {
        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.10)
    }

    private var dockShadow: Color {
        Color.black.opacity(colorScheme == .dark ? 0.40 : 0.18)
    }

    var body: some View {
        HStack(spacing: 0) {
            undoRedoCluster
                .padding(.leading, 10)

            Divider()
                .frame(height: 36)
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 8)

            toolCluster
                .padding(.horizontal, 4)

            Spacer(minLength: 6)

            modeToggle
                .padding(.trailing, 8)

            colorWheelButton
                .padding(.trailing, 4)

            settingsButton
                .padding(.trailing, 12)
        }
        .frame(height: dockHeight)
        .frame(maxWidth: dockMaxWidth)
        .background(
            Capsule(style: .continuous)
                .fill(dockBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(dockBorder, lineWidth: 0.8)
        )
        .shadow(color: dockShadow, radius: 16, x: 0, y: 8)
        .padding(.horizontal, 24)
    }

    private var undoRedoCluster: some View {
        VStack(spacing: 2) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        viewModel.canUndo
                            ? Color(hex: "#D8CFC4")
                            : Color(hex: "#D8CFC4").opacity(0.28)
                    )
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canUndo)
            .accessibilityLabel("Undo")
            .accessibilityIdentifier(A11y.Canvas.undo)

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        viewModel.canRedo
                            ? Color(hex: "#D8CFC4")
                            : Color(hex: "#D8CFC4").opacity(0.28)
                    )
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRedo)
            .accessibilityLabel("Redo")
            .accessibilityIdentifier(A11y.Canvas.redo)
        }
    }

    private var toolCluster: some View {
        HStack(spacing: 4) {
            ForEach(dockTools, id: \.self) { tool in
                CanvasDockToolButton(
                    tool: tool,
                    isSelected: viewModel.selectedTool == tool,
                    selectedColorHex: viewModel.selectedColorHex,
                    colorScheme: colorScheme,
                    action: { viewModel.selectTool(tool) }
                )
            }
        }
    }

    private var dockTools: [ToolType] {
        [.watercolor, .coloredPencil, .crayon, .marker, .eraser]
    }

    private var modeToggle: some View {
        Picker("Coloring mode", selection: Binding(
            get: { viewModel.coloringMode },
            set: { viewModel.selectColoringMode($0) }
        )) {
            Text("Clean").tag(CanvasColoringMode.clean)
            Text("Free").tag(CanvasColoringMode.free)
        }
        .pickerStyle(.segmented)
        .frame(width: 108)
        .accessibilityIdentifier("canvas.cleanFreeToggle")
    }

    private var colorWheelButton: some View {
        Button {
            showColorPicker.toggle()
        } label: {
            CanvasDockColorWheelButton(
                selectedColorHex: viewModel.selectedColorHex
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
            BottomColorWheelPopover(viewModel: viewModel)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Change color")
        .accessibilityIdentifier("canvas.color.compact")
    }

    private var settingsButton: some View {
        Button {
            showSettingsSheet = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#B5AA9A"))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tools and settings")
        .accessibilityIdentifier("canvas.tools")
    }
}

struct CanvasDockToolButton: View {
    let tool: ToolType
    let isSelected: Bool
    let selectedColorHex: String
    let colorScheme: ColorScheme
    let action: () -> Void

    private var iconColor: Color {
        if isSelected {
            if tool == .eraser {
                return Color(hex: "#F0EBE3")
            }
            return Color(hex: selectedColorHex)
        }
        return Color(hex: "#8A8178")
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.white.opacity(0.08)
        }
        return .clear
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
                    .frame(width: 48, height: 56)

                ToolIconView(
                    tool: tool,
                    color: iconColor,
                    size: isSelected ? 26 : 22
                )
            }
            .frame(width: 48, height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.accessibilityLabel)
        .accessibilityIdentifier(tool.accessibilityIdentifier)
    }
}

struct CanvasDockColorWheelButton: View {
    let selectedColorHex: String

    private let hueColors: [Color] = [
        Color(hex: "#E83A3A"),
        Color(hex: "#F17835"),
        Color(hex: "#F5C842"),
        Color(hex: "#6BBF59"),
        Color(hex: "#2BBCB3"),
        Color(hex: "#3F7BD9"),
        Color(hex: "#7B68AE"),
        Color(hex: "#D45B90"),
        Color(hex: "#E83A3A")
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: hueColors),
                        center: .center
                    )
                )
                .frame(width: 64, height: 64)
                .mask(
                    Circle()
                        .frame(width: 64, height: 64)
                )

            Circle()
                .fill(Color(hex: "#1A1A18"))
                .frame(width: 40, height: 40)

            Circle()
                .fill(Color(hex: selectedColorHex))
                .frame(width: 34, height: 34)

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: 8, height: 8)
                .offset(y: -26)
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }
}

private struct BottomColorWheelPopover: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ColoringSessionViewModel

    private let colors = [
        "#D4213D", "#F16A37", "#F5B84B", "#6F8E62",
        "#2BBCB3", "#3F7BD9", "#7B68AE", "#111111"
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(colors, id: \.self) { hex in
                Button {
                    viewModel.selectColor(hex: hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Circle().stroke(
                                viewModel.selectedColorHex == hex
                                    ? SableTheme.selectedSurface(for: colorScheme)
                                    : SableTheme.divider(for: colorScheme),
                                lineWidth: 3
                            )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
                .accessibilityIdentifier(A11y.Canvas.color(hex))
            }
        }
        .padding(14)
        .background(SableTheme.canvasChrome(for: colorScheme))
    }
}

struct CanvasColorHistoryRail: View {
    @Environment(\.colorScheme) private var colorScheme
    let recentColorHexes: [String]
    let selectedColorHex: String
    let onSelectColor: (String) -> Void
    let onOpenColorPicker: () -> Void

    private var railBackground: Color {
        colorScheme == .dark
            ? Color(hex: "#151615").opacity(0.88)
            : Color(hex: "#1D1E1B").opacity(0.86)
    }

    var body: some View {
        VStack(spacing: 11) {
            diamondMarker

            recentSwatches

            pickerButton
        }
        .frame(width: 38)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(railBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
        )
    }

    private var diamondMarker: some View {
        Rectangle()
            .fill(Color(hex: selectedColorHex))
            .frame(width: 10, height: 10)
            .rotationEffect(.degrees(45))
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(45))
            )
    }

    private var recentSwatches: some View {
        VStack(spacing: 6) {
            ForEach(Array(recentColorHexes.prefix(5).enumerated()), id: \.offset) { _, hex in
                Button {
                    onSelectColor(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().stroke(
                                hex == selectedColorHex ? Color.white.opacity(0.6) : Color.white.opacity(0.12),
                                lineWidth: hex == selectedColorHex ? 1.5 : 0.6
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recent color \(hex)")
                .accessibilityIdentifier(A11y.Canvas.color(hex))
            }
        }
    }

    private var pickerButton: some View {
        Button(action: onOpenColorPicker) {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open color picker")
    }
}
