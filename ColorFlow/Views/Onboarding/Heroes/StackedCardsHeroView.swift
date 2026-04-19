import SwiftUI

/// Step 3 hero: three "project" cards animate into a neatly-offset stack,
/// suggesting a saved library of the user's work.
struct StackedCardsHeroView: View {
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stacked = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                CardTile(index: index, accent: accent)
                    .frame(width: 160, height: 200)
                    .offset(offset(for: index))
                    .rotationEffect(rotation(for: index))
                    .zIndex(Double(index))
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
            }
        }
        .frame(width: 260, height: 240)
        .onAppear {
            if reduceMotion {
                stacked = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) {
                    stacked = true
                }
            }
        }
    }

    private func offset(for index: Int) -> CGSize {
        guard stacked else {
            // Off-screen entry positions
            let directions: [CGSize] = [
                CGSize(width: -180, height: -40),
                CGSize(width:    0, height: 160),
                CGSize(width:  180, height: -40),
            ]
            return directions[index]
        }
        let spread: CGFloat = 18
        return CGSize(width: CGFloat(index - 1) * spread, height: CGFloat(index - 1) * -6)
    }

    private func rotation(for index: Int) -> Angle {
        guard stacked else { return .degrees(Double(index - 1) * 20) }
        return .degrees(Double(index - 1) * -4)
    }
}

private struct CardTile: View {
    let index: Int
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                // Mini artwork motif
                VStack(alignment: .leading, spacing: 10) {
                    Circle()
                        .fill(accent.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .glow(color: accent.opacity(0.6), radius: 12)
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 90, height: 10)
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 60, height: 8)
                }
                .padding(18)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(accent)
                    .padding(14)
                    .opacity(index == 1 ? 1 : 0.35)
            }
    }
}
