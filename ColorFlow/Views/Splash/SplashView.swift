import SwiftUI

/// Cold-launch splash. Draws the ColorFlow brush mark tail-to-tip over 1.1s,
/// holds briefly, then crossfades out. Respects Reduce Motion.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 1

    private let strokeDuration: Double = 1.1
    private let hold: Double = 0.3
    private let fade: Double = 0.25

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            BrushMarkShape()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.24, blue: 0.80),
                            AppTheme.accent,
                            Color(red: 0.76, green: 0.67, blue: 0.98)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                )
                .glow(color: AppTheme.accent.opacity(0.55), radius: 14)
                .frame(width: 180, height: 180)
                .opacity(opacity)
        }
        .accessibilityIdentifier("splash.view")
        .onAppear(perform: animate)
    }

    private func animate() {
        if reduceMotion {
            progress = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                withAnimation(.easeOut(duration: fade)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + fade) { onFinish() }
            }
            return
        }

        withAnimation(.easeInOut(duration: strokeDuration)) { progress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + strokeDuration + hold) {
            withAnimation(.easeOut(duration: fade)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + fade) { onFinish() }
        }
    }
}

/// A single-stroke brushmark resembling the app icon: bottom-left sweep up
/// into a hooked tip. Drawn in a 180×180 unit box.
private struct BrushMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0.18 * w, y: 0.86 * h))
        path.addCurve(
            to: CGPoint(x: 0.58 * w, y: 0.32 * h),
            control1: CGPoint(x: 0.22 * w, y: 0.58 * h),
            control2: CGPoint(x: 0.40 * w, y: 0.40 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.84 * w, y: 0.20 * h),
            control1: CGPoint(x: 0.70 * w, y: 0.24 * h),
            control2: CGPoint(x: 0.80 * w, y: 0.18 * h)
        )
        return path
    }
}
