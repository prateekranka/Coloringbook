import SwiftUI

/// Step 1 hero: a soft rounded "region" that fills up with rising colored droplets.
/// Loops a fill → drain cycle; static end-state when reduce-motion is on.
struct FillHeroView: View {
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            // Outline region (rounded blob)
            BlobShape()
                .stroke(AppTheme.Ink.primary.opacity(0.35), lineWidth: 3)
                .frame(width: 220, height: 220)
                .glow(color: accent.opacity(0.35), radius: 18)

            // Animated fill, clipped to the blob
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: geo.size.height * progress)
                        .animation(.easeInOut(duration: 1.6), value: progress)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            .frame(width: 220, height: 220)
            .mask(BlobShape().frame(width: 220, height: 220))

            // Droplets falling in
            if !reduceMotion {
                TimelineView(.animation) { ctx in
                    DropletsCanvas(date: ctx.date, tint: accent)
                }
                .frame(width: 220, height: 220)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            if reduceMotion {
                progress = 0.8
            } else {
                startCycle()
            }
        }
    }

    private func startCycle() {
        progress = 0
        withAnimation(.easeInOut(duration: 1.6)) { progress = 0.85 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 1.0)) { progress = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                startCycle()
            }
        }
    }
}

private struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.width * 0.28)
    }
}

private struct DropletsCanvas: View {
    let date: Date
    let tint: Color

    var body: some View {
        Canvas { ctx, size in
            let t = date.timeIntervalSinceReferenceDate
            for i in 0..<3 {
                let phase = (t + Double(i) * 0.65).truncatingRemainder(dividingBy: 2.4) / 2.4
                let x = size.width * (0.28 + 0.22 * Double(i))
                let y = size.height * phase
                let r = 8.0 * (1 - phase * 0.3)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(tint.opacity(0.85))
                )
            }
        }
    }
}
