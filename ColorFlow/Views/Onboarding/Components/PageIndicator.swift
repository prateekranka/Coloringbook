import SwiftUI

/// Custom page indicator: the active dot expands into a short capsule.
/// Colour picks up the step's accent so the indicator ties into the hero.
struct PageIndicator: View {
    let count: Int
    let current: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? accent : AppTheme.Ink.secondary.opacity(0.35))
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(AppTheme.Motion.quickSpring, value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}
