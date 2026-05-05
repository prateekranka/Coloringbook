import SwiftUI

/// Proposed Canvas layout — toolbar rail + floating color picker mockup.
/// Renders a real SVG template on the canvas with proper ColorFlow branding.
struct ProposedCanvasView: View {
    let template: Template
    let canvasImage: UIImage?

    @State private var selectedTool: PreviewDrawingTool = .pencil
    @State private var showColorPicker = true
    @State private var showDrawer = true
    @State private var selectedColor: Color = AppTheme.Brand.accent
    @State private var brushSize: CGFloat = 8

    var body: some View {
        ZStack {
            // Canvas background (white — the user's paper)
            Color.white.ignoresSafeArea()

            // Template artwork on canvas
            if let img = canvasImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(40)
            }

            // Toolbar rail (left side)
            HStack(alignment: .top, spacing: 0) {
                toolbarRail
                    .fixedSize()

                if showDrawer {
                    brushDrawer
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.top, 12)

            // Floating color picker
            if showColorPicker {
                colorPickerCard
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
    }

    // MARK: - Toolbar Rail

    private var toolbarRail: some View {
        VStack(spacing: 4) {
            // Back + toggle row
            HStack(spacing: 0) {
                Button { } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                Spacer(minLength: 0)
                Button { } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(AppTheme.Ink.primary)
                }
            }

            Divider().padding(.horizontal, 6)

            // Drawing tools
            ForEach(PreviewDrawingTool.allCases) { tool in
                toolButton(tool)
            }

            Divider().padding(.horizontal, 6)

            // Undo / Redo
            HStack(spacing: 0) {
                Button { } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                Button { } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(AppTheme.Ink.primary)
                }
            }

            Divider().padding(.horizontal, 6)

            // Layers + Settings
            Button { } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(AppTheme.Ink.primary)
            }

            Button { } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(AppTheme.Ink.primary)
            }

            Spacer(minLength: 10)

            // Color well (sage green glow)
            Button { showColorPicker.toggle() } label: {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 32, height: 32)
                    .overlay { Circle().stroke(AppTheme.Stroke.swatchBorder, lineWidth: 1.5) }
                    .glow(color: selectedColor.opacity(0.5), radius: 6)
                    .padding(6)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
    }

    // MARK: - Tool Button

    private func toolButton(_ tool: PreviewDrawingTool) -> some View {
        Button {
            if selectedTool == tool {
                showDrawer.toggle()
            } else {
                selectedTool = tool
                showDrawer = true
            }
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 18, weight: selectedTool == tool ? .semibold : .regular))
                .foregroundStyle(selectedTool == tool ? AppTheme.Brand.accent : AppTheme.Ink.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedTool == tool ? AppTheme.Brand.accentSubtle : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Brush Drawer

    private var brushDrawer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(selectedTool.rawValue) size")
                .font(Font.cfCaption)
                .foregroundStyle(AppTheme.Ink.secondary)

            // Size scrubber with sage accent
            Slider(value: $brushSize, in: 1...32)
                .tint(AppTheme.Brand.accent)

            Text("\(Int(brushSize))pt")
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.Ink.tertiary)

            if selectedTool != .eraser {
                Text("Opacity")
                    .font(Font.cfCaption)
                    .foregroundStyle(AppTheme.Ink.secondary)

                Slider(value: .constant(0.8), in: 0.1...1)
                    .tint(AppTheme.Brand.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(AppTheme.Stroke.hairline, lineWidth: 1)
        }
        .padding(.top, 12)
    }

    // MARK: - Color Picker Card

    private var colorPickerCard: some View {
        VStack(spacing: 14) {
            // Header with drag handle
            VStack(spacing: 6) {
                Capsule()
                    .fill(AppTheme.Ink.tertiary)
                    .frame(width: 36, height: 4)

                HStack {
                    Text("Color")
                        .font(Font.cfCaption)
                        .foregroundStyle(AppTheme.Ink.primary)
                    Spacer()
                    Button { showColorPicker = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.Ink.primary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(AppTheme.Surface.background))
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.top, 6)

            // Mode pill (sage accent)
            HStack {
                Label("Default", systemImage: "circle.hexagongrid")
                    .font(Font.cfCaption)
                    .foregroundStyle(AppTheme.Ink.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.Brand.accentSubtle))
                Spacer()
            }
            .padding(.horizontal, 18)

            // Flower wheel placeholder (hue ring with swatches)
            ZStack {
                // Hue ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        ),
                        lineWidth: 20
                    )
                    .frame(width: 280, height: 280)

                // Swatch nodes in a ring
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) * 30.0
                    let rad = angle * .pi / 180
                    let x = cos(rad) * 100
                    let y = sin(rad) * 100
                    Circle()
                        .fill(Color(hue: Double(i) / 12, saturation: 0.8, brightness: 0.9))
                        .frame(width: 32, height: 32)
                        .overlay { Circle().stroke(.white.opacity(0.3), lineWidth: 1) }
                        .offset(x: x, y: y)
                }

                // Selected swatch (center, sage green)
                Circle()
                    .fill(selectedColor)
                    .frame(width: 48, height: 48)
                    .overlay { Circle().stroke(.white, lineWidth: 3) }
                    .glow(color: selectedColor.opacity(0.5), radius: 8)
            }
            .frame(height: 320)
            .padding(.horizontal, 18)

            // Brightness strip
            VStack(alignment: .leading, spacing: 4) {
                LinearGradient(
                    colors: [.black, selectedColor, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 18)

            // Recent colors
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(Font.cfCaption)
                    .foregroundStyle(AppTheme.Ink.secondary)
                    .padding(.horizontal, 18)

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(recentSwatches, id: \.self) { c in
                            Circle()
                                .fill(c)
                                .frame(width: 28, height: 28)
                                .overlay { Circle().stroke(AppTheme.Stroke.swatchBorder, lineWidth: 1) }
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
            }

            // NEW: Hex input field
            HStack(spacing: 8) {
                Text("Hex")
                    .font(Font.cfCaption)
                    .foregroundStyle(AppTheme.Ink.secondary)

                Text("#7AB887")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Surface.elevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.Stroke.hairline, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 6)
        }
        .padding(.vertical, 14)
        .frame(width: 340, height: 600)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous)
                .stroke(AppTheme.Stroke.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 80)
        .padding(.top, 40)
    }

    // Mock recent colors (sage + complementary)
    private var recentSwatches: [Color] {
        [
            AppTheme.Brand.accent,
            .red,
            .blue,
            .yellow,
            .purple,
            .orange,
            Color(hue: 0.55, saturation: 0.7, brightness: 0.8),
        ]
    }
}

// MARK: - Drawing Tool Enum (Preview-only)

private enum PreviewDrawingTool: String, CaseIterable, Identifiable {
    case pencil = "Pencil"
    case brush = "Brush"
    case fill = "Fill"
    case eraser = "Eraser"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pencil: return "pencil"
        case .brush:  return "paintbrush"
        case .fill:   return "paintbucket"
        case .eraser: return "eraser"
        }
    }
}

// MARK: - SVG Rendering Helper

private func canvasPreviewImage(for template: Template, size: CGSize = CGSize(width: 600, height: 600)) -> UIImage? {
    guard let url = template.svgURL,
          case .success(let geo) = SVGParser.parse(url: url) else { return nil }
    return TemplateRenderer.renderThumbnail(geometry: geo, fills: [:], size: size)
}

// MARK: - Preview

#Preview("Proposed Canvas — Branded") {
    let template = Template.loadAll().first!
    let img = canvasPreviewImage(for: template)
    return ProposedCanvasView(template: template, canvasImage: img)
        .environment(AppState.shared)
        .preferredColorScheme(.dark)
}
