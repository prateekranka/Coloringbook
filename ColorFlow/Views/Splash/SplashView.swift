import SwiftUI

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
            AppTheme.Surface.background.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                BrushMarkShape()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppTheme.Brand.accent,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    )
                    .glow(color: AppTheme.Brand.accent.opacity(0.55), radius: 14)
                    .frame(width: 180, height: 180)

                Text("ColorFlow")
                    .font(Font.cfTitleLarge)
                    .foregroundStyle(AppTheme.Ink.primary)
            }
            .opacity(opacity)
        }
        .accessibilityIdentifier("splash.view")
        .task { await animate() }
    }

    private func animate() async {
        if reduceMotion {
            progress = 1
            try? await Task.sleep(for: .seconds(hold))
            withAnimation(.easeOut(duration: fade)) { opacity = 0 }
            try? await Task.sleep(for: .seconds(fade))
            onFinish()
            return
        }

        withAnimation(.easeInOut(duration: strokeDuration)) { progress = 1 }
        try? await Task.sleep(for: .seconds(strokeDuration + hold))
        withAnimation(.easeOut(duration: fade)) { opacity = 0 }
        try? await Task.sleep(for: .seconds(fade))
        onFinish()
    }
}

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

#Preview {
    SplashView(onFinish: {})
}