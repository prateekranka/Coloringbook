import SwiftUI

/// A compact brightness tweaker that appears after a long-press on a swatch.
/// Lets the user nudge a just-picked color lighter/darker without leaving the sheet.
struct BrightnessStrip: View {
    @Binding var color: Color
    let dismiss: () -> Void

    @State private var brightness: Double = 1
    @State private var baseHue: Double = 0
    @State private var baseSaturation: Double = 1

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.min")
                .foregroundStyle(AppTheme.Ink.secondary)

            Slider(value: $brightness, in: 0.2...1) { _ in }
                .tint(AppTheme.Brand.accent)
                .onChange(of: brightness) { _, new in
                    color = Color(h: baseHue, s: baseSaturation, b: new)
                }

            Image(systemName: "sun.max.fill")
                .foregroundStyle(AppTheme.Ink.primary)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Ink.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppTheme.Surface.elevated))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous).fill(.regularMaterial)
        )
        .overlay {
            Capsule(style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .onAppear {
            let current: Color = color
            let (h, s, b) = current.hsb
            baseHue = h
            baseSaturation = s
            brightness = b
        }
    }
}
