import SwiftUI

/// A single glowing circular swatch in the flower wheel.
/// Blooms in with a spring on appear, and gets a white halo + scale when selected.
struct SwatchNode: View {
    let color: Color
    let radius: CGFloat
    let isSelected: Bool
    let appearanceDelay: Double
    let onTap: () -> Void
    let onLongPress: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(color)
                    .blur(radius: radius * 0.55)
                    .opacity(isSelected ? 0.9 : 0.55)

                // Main disc
                Circle()
                    .fill(color)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                // Selection halo
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .blur(radius: 0.5)
                        .padding(-3)
                }
            }
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(appeared ? (isSelected ? 1.15 : 1.0) : 0.3)
            .opacity(appeared ? 1 : 0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in onLongPress() }
        )
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(AppTheme.Motion.bloomSpring.delay(appearanceDelay)) {
                    appeared = true
                }
            }
        }
        .accessibilityLabel(UIColor(color).hexString)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
