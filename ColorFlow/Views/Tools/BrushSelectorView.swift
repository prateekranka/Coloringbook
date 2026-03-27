import SwiftUI

/// Standalone brush size selector with a live preview of the brush circle.
/// Used as a popover or embedded component.
struct BrushSelectorView: View {
    @Binding var brushSettings: BrushSettings

    var body: some View {
        VStack(spacing: 16) {
            Text("Brush Size")
                .font(.headline)

            // Live preview
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(brushSettings.color)
                    .frame(width: brushSettings.size, height: brushSettings.size)
                    .opacity(brushSettings.opacity)
            }
            .frame(width: 80, height: 80)

            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.secondary)
                Slider(value: $brushSettings.size, in: BrushSettings.sizeRange)
                    .accessibilityLabel("Brush size")
                    .accessibilityValue("\(Int(brushSettings.size)) points")
                Image(systemName: "circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }

            // Opacity
            Text("Opacity")
                .font(.headline)

            HStack {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.secondary)
                Slider(value: $brushSettings.opacity, in: 0.05...1.0)
                    .accessibilityLabel("Brush opacity")
                    .accessibilityValue("\(Int(brushSettings.opacity * 100)) percent")
                Image(systemName: "circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 260)
    }
}
