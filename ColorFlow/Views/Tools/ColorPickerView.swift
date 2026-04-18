import SwiftUI

/// Full-featured color picker: radial HSB wheel, shade/brightness slider,
/// curated palettes, recent colors, user's saved palette, and hex entry.
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var recentColors: [Color]
    let palettes: [ColorPalette]

    @State private var selectedPaletteID: UUID?
    @State private var hexInput = ""
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var showAdvanced = false
    @Environment(UserPaletteStore.self) private var userPalette
    @Environment(\.dismiss) private var dismiss

    // Curated + user's own palette, presented as a unified list.
    private enum PaletteKind: Hashable {
        case user
        case curated(UUID)
    }
    @State private var selectedKind: PaletteKind = .user

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Live preview of the picked color, spanning the top.
                    colorPreview

                    // Primary picker: wheel + brightness slider.
                    wheelSection

                    // Secondary picker: palette list (user + curated).
                    paletteSelector
                    swatchesSection

                    // Tertiary: recent colors (most-recently-used across sessions).
                    if !recentColors.isEmpty {
                        recentColorsRow
                    }

                    // Advanced disclosure: HSB sliders + hex entry.
                    advancedDisclosure
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                        .bold()
                }
            }
        }
        .onAppear {
            selectedPaletteID = palettes.first?.id
            selectedKind = palettes.first.map { .curated($0.id) } ?? .user
            syncFromSelectedColor()
        }
        .onChange(of: selectedColor) { _, _ in syncFromSelectedColor() }
    }

    // MARK: - Preview

    private var colorPreview: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(selectedColor)
                .frame(height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            Button {
                if userPalette.contains(selectedColor) {
                    userPalette.remove(selectedColor)
                } else {
                    userPalette.add(selectedColor)
                    HapticService.shared.paletteChanged()
                }
            } label: {
                Image(systemName: userPalette.contains(selectedColor)
                      ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(userPalette.contains(selectedColor)
                                     ? Color.pink : AppTheme.textSecondary)
                    .frame(width: AppTheme.minTapTarget, height: AppTheme.minTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(userPalette.contains(selectedColor)
                                ? "Remove from my palette"
                                : "Save to my palette")
            .accessibilityIdentifier("color.saveToPalette")
        }
    }

    // MARK: - Wheel + brightness slider

    private var wheelSection: some View {
        VStack(spacing: 14) {
            ColorWheelView(
                hue: $hue,
                saturation: $saturation,
                brightness: brightness,
                onChange: { syncFromHSB() }
            )
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)

            // Shade (brightness) slider — runs from black through the pure hue.
            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                    .foregroundStyle(AppTheme.textSecondary)
                Slider(value: Binding(
                    get: { brightness },
                    set: { brightness = $0; syncFromHSB() }
                ), in: 0...1)
                .tint(Color(hue: hue, saturation: saturation, brightness: 1))
                .accessibilityLabel("Shade")
                .accessibilityValue("\(Int(brightness * 100))%")
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Palette selector

    private var paletteSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                paletteChip(label: "My Palette",
                            isSelected: selectedKind == .user,
                            icon: "heart.fill") {
                    selectedKind = .user
                    HapticService.shared.selectionMoved()
                }
                ForEach(palettes) { palette in
                    paletteChip(label: palette.name,
                                isSelected: selectedKind == .curated(palette.id),
                                icon: nil) {
                        selectedKind = .curated(palette.id)
                        selectedPaletteID = palette.id
                        HapticService.shared.selectionMoved()
                    }
                }
            }
        }
    }

    private func paletteChip(label: String, isSelected: Bool, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected
                               ? AnyShapeStyle(AppTheme.accentGradient)
                               : AnyShapeStyle(AppTheme.surfaceElevated))
            )
            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Swatches

    @ViewBuilder
    private var swatchesSection: some View {
        switch selectedKind {
        case .user:
            userSwatchGrid
        case .curated(let id):
            if let palette = palettes.first(where: { $0.id == id }) {
                curatedSwatchGrid(palette: palette)
            }
        }
    }

    private var userSwatchGrid: some View {
        Group {
            if userPalette.colors.isEmpty {
                HStack {
                    Image(systemName: "heart")
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Tap the heart to save colors to your palette.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
                swatchGrid(colors: userPalette.colors)
            }
        }
    }

    private func curatedSwatchGrid(palette: ColorPalette) -> some View {
        swatchGrid(colors: palette.swatches.map { $0.color })
    }

    private func swatchGrid(colors: [Color]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
            spacing: 10
        ) {
            ForEach(colors.indices, id: \.self) { i in
                SwatchCell(color: colors[i], isSelected: colors[i] == selectedColor) {
                    selectedColor = colors[i]
                    syncFromSelectedColor()
                    HapticService.shared.paletteChanged()
                }
            }
        }
    }

    // MARK: - Recent

    private var recentColorsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentColors.indices, id: \.self) { i in
                        SwatchCell(color: recentColors[i],
                                   isSelected: selectedColor == recentColors[i]) {
                            selectedColor = recentColors[i]
                            syncFromSelectedColor()
                        }
                        .frame(width: 40, height: 40)
                    }
                }
            }
        }
    }

    // MARK: - Advanced disclosure

    private var advancedDisclosure: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(spacing: 12) {
                LabeledSlider(label: "H", value: $hue, range: 0...1,
                              gradient: Gradient(colors: (0...10).map {
                                  Color(hue: Double($0) / 10, saturation: 1, brightness: 1)
                              })) {
                    syncFromHSB()
                }
                LabeledSlider(label: "S", value: $saturation, range: 0...1,
                              gradient: Gradient(colors: [
                                  Color(hue: hue, saturation: 0, brightness: brightness),
                                  Color(hue: hue, saturation: 1, brightness: brightness)
                              ])) {
                    syncFromHSB()
                }
                LabeledSlider(label: "B", value: $brightness, range: 0...1,
                              gradient: Gradient(colors: [
                                  .black,
                                  Color(hue: hue, saturation: saturation, brightness: 1)
                              ])) {
                    syncFromHSB()
                }
                hexInputRow
            }
            .padding(.top, 10)
        } label: {
            Text("Advanced")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .tint(AppTheme.textSecondary)
    }

    private var hexInputRow: some View {
        HStack {
            Text("#")
                .font(.monospaced(.body)())
                .foregroundStyle(AppTheme.textSecondary)
            TextField("RRGGBB", text: $hexInput)
                .font(.monospaced(.body)())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onSubmit { applyHex() }
            Button("Apply") { applyHex() }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
        }
    }

    // MARK: - Sync helpers

    private func syncFromSelectedColor() {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(selectedColor).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h); saturation = Double(s); brightness = Double(b)
        hexInput = UIColor(selectedColor).hexString
    }

    private func syncFromHSB() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness)
        hexInput = UIColor(selectedColor).hexString
    }

    private func applyHex() {
        let cleaned = hexInput.trimmingCharacters(in: .alphanumerics.inverted)
        if cleaned.count == 6 {
            selectedColor = Color(hex: "#\(cleaned)")
            syncFromSelectedColor()
        }
    }
}

// MARK: - Sub-components

private struct SwatchCell: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2.5 : 1)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1)
                        .opacity(isSelected ? 1 : 0)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(UIColor(color).hexString)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let gradient: Gradient
    let onChange: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 16)
            Slider(value: $value, in: range)
                .onChange(of: value) { _, _ in onChange() }
        }
    }
}
