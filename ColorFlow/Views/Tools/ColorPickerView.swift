import SwiftUI

/// Full-featured color picker: palette swatches, recent colors, and HSB + hex inputs.
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var recentColors: [Color]
    let palettes: [ColorPalette]

    @State private var selectedPalette: ColorPalette?
    @State private var hexInput = ""
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Color preview
                    colorPreview

                    // Palette selector
                    palettePicker

                    // Selected palette swatches
                    if let palette = selectedPalette {
                        swatchGrid(palette: palette)
                    }

                    // Recent colors
                    if !recentColors.isEmpty {
                        recentColorsRow
                    }

                    // HSB sliders
                    hsbSliders

                    // Hex input
                    hexInputRow
                }
                .padding()
            }
            .navigationTitle("Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { syncFromSelectedColor() }
        .onChange(of: selectedColor) { syncFromSelectedColor() }
    }

    // MARK: - Sub-views

    private var colorPreview: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(selectedColor)
            .frame(height: 60)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2), lineWidth: 1))
    }

    private var palettePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(palettes) { palette in
                    Button {
                        selectedPalette = palette
                    } label: {
                        Text(palette.name)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selectedPalette?.id == palette.id
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.15))
                            )
                            .foregroundStyle(selectedPalette?.id == palette.id ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { selectedPalette = palettes.first }
    }

    private func swatchGrid(palette: ColorPalette) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(palette.swatches) { swatch in
                SwatchCell(color: swatch.color, isSelected: selectedColor == swatch.color) {
                    selectedColor = swatch.color
                    syncFromSelectedColor()
                }
            }
        }
    }

    private var recentColorsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentColors.indices, id: \.self) { i in
                        SwatchCell(color: recentColors[i], isSelected: selectedColor == recentColors[i]) {
                            selectedColor = recentColors[i]
                            syncFromSelectedColor()
                        }
                    }
                }
            }
        }
    }

    private var hsbSliders: some View {
        VStack(spacing: 12) {
            LabeledSlider(label: "H", value: $hue, range: 0...1,
                          gradient: Gradient(colors: (0...10).map { Color(hue: Double($0)/10, saturation: 1, brightness: 1) })) {
                syncFromHSB()
            }
            LabeledSlider(label: "S", value: $saturation, range: 0...1,
                          gradient: Gradient(colors: [Color(hue: hue, saturation: 0, brightness: brightness),
                                                      Color(hue: hue, saturation: 1, brightness: brightness)])) {
                syncFromHSB()
            }
            LabeledSlider(label: "B", value: $brightness, range: 0...1,
                          gradient: Gradient(colors: [.black, Color(hue: hue, saturation: saturation, brightness: 1)])) {
                syncFromHSB()
            }
        }
    }

    private var hexInputRow: some View {
        HStack {
            Text("#")
                .font(.monospaced(.body)())
                .foregroundStyle(.secondary)
            TextField("RRGGBB", text: $hexInput)
                .font(.monospaced(.body)())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onSubmit { applyHex() }
            Button("Apply") { applyHex() }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Sync Helpers

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
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2.5)
                )
        }
        .buttonStyle(.plain)
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
                .frame(width: 16)
            Slider(value: $value, in: range)
                .onChange(of: value) { _, _ in onChange() }
        }
    }
}
