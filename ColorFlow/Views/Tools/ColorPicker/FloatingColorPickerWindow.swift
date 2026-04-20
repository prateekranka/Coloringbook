import SwiftUI

/// A draggable HUD-style color picker card that floats above the canvas.
/// Replaces the old sheet presentation so the canvas stays interactive behind it.
///
/// - Contains: flower wheel (spectrum or palette), recent-colors row, mode switch, close button.
/// - Position persists across launches via AppStorage.
/// - No tap-outside dismiss; user closes with the × button.
struct FloatingColorPickerWindow: View {
    @Binding var isPresented: Bool
    @Binding var selectedColor: Color
    @Binding var recentColors: [Color]
    let palettes: [ColorPalette]

    // Persist last-dragged offset as a fraction of container size so rotation
    // re-anchors proportionally instead of slamming the card off-screen.
    @AppStorage("colorPicker.lastOffsetFractionX") private var offsetFractionX: Double = 0
    @AppStorage("colorPicker.lastOffsetFractionY") private var offsetFractionY: Double = 0

    @State private var mode: FlowerMode = .spectrum
    @State private var brightnessTarget: Color? = nil
    @State private var showPaletteMenu = false
    @GestureState private var dragTranslation: CGSize = .zero

    private let cardWidth: CGFloat = 560
    private let cardHeight: CGFloat = 680

    var body: some View {
        GeometryReader { geo in
            let base = resolvedOffset(in: geo.size)
            let current = CGSize(
                width: base.width + dragTranslation.width,
                height: base.height + dragTranslation.height
            )

            card
                .frame(width: cardWidth, height: cardHeight)
                .position(x: geo.size.width / 2 + current.width,
                          y: geo.size.height / 2 + current.height)
                .onChange(of: geo.size) { _, _ in
                    // After rotation, re-clamp the persisted offset to new bounds.
                    let clamped = clampedOffset(resolvedOffset(in: geo.size), in: geo.size)
                    offsetFractionX = Double(clamped.width / max(geo.size.width, 1))
                    offsetFractionY = Double(clamped.height / max(geo.size.height, 1))
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("picker.floating")
    }

    // MARK: - Card body

    private var card: some View {
        VStack(spacing: 14) {
            header
            modeSwitch
            FlowerWheelView(
                selectedColor: $selectedColor,
                mode: mode,
                onLongPressSwatch: { color in
                    selectedColor = color
                    brightnessTarget = color
                }
            )
            .frame(height: 420)
            .padding(.horizontal, 18)

            if brightnessTarget != nil {
                BrightnessStrip(color: $selectedColor) {
                    withAnimation(AppTheme.Motion.quickSpring) {
                        brightnessTarget = nil
                    }
                }
                .padding(.horizontal, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !recentColors.isEmpty {
                recentRow
            }

            Spacer(minLength: 6)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: AppTheme.Brand.accent.opacity(0.28), radius: 24, x: 0, y: 12)
        .onDisappear { commitRecent() }
    }

    // MARK: - Header (drag + close)

    private var header: some View {
        HStack {
            Text("Color")
                .font(Font.cfCaption)
                .foregroundStyle(AppTheme.Ink.primary)

            Spacer()

            Button {
                commitRecent()
                withAnimation(AppTheme.Motion.quickSpring) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppTheme.Surface.background))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close color picker")
            .accessibilityIdentifier("picker.close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    // MARK: - Mode switch (Spectrum / Palette)

    private var modeSwitch: some View {
        HStack(spacing: 10) {
            Button {
                showPaletteMenu.toggle()
            } label: {
                modePill(system: mode == .spectrum ? "circle.hexagongrid" : "drop.fill",
                         label: mode == .spectrum ? "Default" : (activePaletteName ?? "Palette"),
                         active: true)
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .accessibilityIdentifier("picker.mode.palette")
            .popover(isPresented: $showPaletteMenu, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                paletteList
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func modePill(system: String, label: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
            Text(label)
        }
        .font(Font.cfCaption)
        .foregroundStyle(active ? AppTheme.Ink.primary : AppTheme.Ink.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(active ? AppTheme.Brand.accentSubtle : AppTheme.Surface.elevated.opacity(0.6))
        )
    }

    private var paletteList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(AppTheme.Motion.pageTransition) {
                    mode = .spectrum
                }
                showPaletteMenu = false
            } label: {
                HStack {
                    Image(systemName: "circle.hexagongrid")
                    Text("Default")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Ink.primary)
                    Spacer()
                    if mode == .spectrum {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Brand.accent)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("picker.palette.default")

            Divider().padding(.horizontal, 8)

            ForEach(palettes) { p in
                Button {
                    withAnimation(AppTheme.Motion.pageTransition) {
                        mode = .palette(p)
                    }
                    showPaletteMenu = false
                } label: {
                    HStack {
                        Text(p.name)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Ink.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("picker.palette.\(p.name.lowercased().replacingOccurrences(of: " ", with: "_"))")
            }
        }
        .frame(minWidth: 180)
        .background(AppTheme.Surface.background)
    }

    private var isPaletteMode: Bool {
        if case .palette = mode { return true }
        return false
    }

    private var activePaletteName: String? {
        if case let .palette(p) = mode { return p.name }
        return nil
    }

    // MARK: - Recent row

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(Font.cfCaption)
                .foregroundStyle(AppTheme.Ink.secondary)
                .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentColors.indices, id: \.self) { i in
                        let c = recentColors[i]
                        Button {
                            withAnimation(AppTheme.Motion.quickSpring) {
                                selectedColor = c
                            }
                            HapticService.shared.impact(.light)
                        } label: {
                            Circle()
                                .fill(c)
                                .strokeBorder(
                                    UIColor(c).hexString == UIColor(selectedColor).hexString
                                        ? Color.white
                                        : .clear,
                                    lineWidth: 2
                                )
                                .frame(width: 28, height: 28)
                                .glow(color: c.opacity(0.5), radius: 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("picker.recent.\(i)")
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Drag

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                // Read geometry from the latest view — compute once and persist fraction.
                // We don't have a GeometryReader proxy here so re-derive on end from UIScreen.
                let screen = UIScreen.main.bounds.size
                let base = resolvedOffset(in: screen)
                let raw = CGSize(
                    width: base.width + value.translation.width,
                    height: base.height + value.translation.height
                )
                let clamped = clampedOffset(raw, in: screen)
                offsetFractionX = Double(clamped.width / max(screen.width, 1))
                offsetFractionY = Double(clamped.height / max(screen.height, 1))
            }
    }

    private func resolvedOffset(in size: CGSize) -> CGSize {
        // First launch defaults: anchored slightly right of the left toolbar, near the top.
        if offsetFractionX == 0 && offsetFractionY == 0 {
            let firstX = -size.width / 2 + cardWidth / 2 + 96
            let firstY = -size.height / 2 + cardHeight / 2 + 80
            return CGSize(width: firstX, height: firstY)
        }
        return CGSize(width: CGFloat(offsetFractionX) * size.width,
                      height: CGFloat(offsetFractionY) * size.height)
    }

    private func clampedOffset(_ offset: CGSize, in size: CGSize) -> CGSize {
        let horizontalLimit = max(0, (size.width - cardWidth) / 2)
        let verticalLimit = max(0, (size.height - cardHeight) / 2)
        return CGSize(
            width: max(-horizontalLimit, min(horizontalLimit, offset.width)),
            height: max(-verticalLimit, min(verticalLimit, offset.height))
        )
    }

    // MARK: - Recent commit

    private func commitRecent() {
        let hex = UIColor(selectedColor).hexString
        var next = recentColors.filter { UIColor($0).hexString != hex }
        next.insert(selectedColor, at: 0)
        recentColors = Array(next.prefix(12))
    }
}
