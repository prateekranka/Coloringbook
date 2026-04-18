import SwiftUI

/// Onboarding carousel — three looping demo cards that show off the tap-to-fill,
/// pencil stroke, and auto-save experiences before the user hits the home tab.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Tap to Fill",
            description: "Tap any region of a template and it fills instantly with your chosen color."
        ),
        OnboardingStep(
            title: "Draw with Pencil",
            description: "Use Apple Pencil to add fine details with pressure-sensitive strokes."
        ),
        OnboardingStep(
            title: "Auto-saved",
            description: "Your work saves automatically. Pick up where you left off, any time."
        ),
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $currentStep) {
                    ForEach(steps.indices, id: \.self) { i in
                        StepCard(step: steps[i], index: i)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentStep ? AppTheme.accent : AppTheme.surfaceElevated)
                            .frame(width: i == currentStep ? 22 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.vertical, 24)

                Spacer()

                Button {
                    if currentStep < steps.count - 1 {
                        withAnimation(.spring(duration: 0.35)) { currentStep += 1 }
                    } else {
                        HapticService.shared.projectCompleted()
                        isPresented = false
                    }
                } label: {
                    Text(currentStep < steps.count - 1 ? "Next" : "Start Coloring")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(AppTheme.accentGradient)
                        )
                        .floatingShadow()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Step card

private struct StepCard: View {
    let step: OnboardingStep
    let index: Int

    var body: some View {
        VStack(spacing: 32) {
            Group {
                switch index {
                case 0: TapFillDemo()
                case 1: PencilStrokeDemo()
                default: AutoSaveDemo()
                }
            }
            .frame(width: 220, height: 220)

            VStack(spacing: 12) {
                Text(step.title)
                    .font(AppTheme.displayFont(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(step.description)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Demo: Tap to Fill

private struct TapFillDemo: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Line-art stand-in: three overlapping leaf shapes that get filled in sequence.
            LeafShape()
                .stroke(Color.white, lineWidth: 3)
                .overlay(LeafShape().fill(AppTheme.accent.opacity(animate ? 1 : 0)))
                .rotationEffect(.degrees(-20))
                .offset(x: -36)

            LeafShape()
                .stroke(Color.white, lineWidth: 3)
                .overlay(LeafShape().fill(Color(hex: "#FF7A7A").opacity(animate ? 1 : 0)))
                .rotationEffect(.degrees(12))
                .offset(y: 20)

            LeafShape()
                .stroke(Color.white, lineWidth: 3)
                .overlay(LeafShape().fill(Color(hex: "#E879F9").opacity(animate ? 1 : 0)))
                .rotationEffect(.degrees(32))
                .offset(x: 36)

            // Floating finger that taps each leaf.
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                .offset(y: animate ? 20 : 100)
                .opacity(animate ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

/// Simple leaf-like shape used in the tap-fill demo.
private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 10))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY - 10),
            control: CGPoint(x: rect.maxX, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + 10),
            control: CGPoint(x: rect.minX, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Demo: Pencil stroke

private struct PencilStrokeDemo: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            // The target stroke (dashed preview).
            DemoStrokePath()
                .stroke(Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 6]))

            // The animated colored stroke being drawn.
            DemoStrokePath()
                .trim(from: 0, to: progress)
                .stroke(
                    AppTheme.accentGradient,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )

            // Pencil tip riding the leading edge of the stroke.
            GeometryReader { proxy in
                let point = strokePoint(at: progress, in: proxy.size)
                Image(systemName: "pencil.tip")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.white)
                    .position(point)
                    .opacity(progress > 0 && progress < 1 ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }

    /// Approximates the stroke position at a given progress by sampling the
    /// same curve used in `DemoStrokePath`. Good enough for a demo — no need
    /// for `TimingCurve`-style accuracy.
    private func strokePoint(at t: CGFloat, in size: CGSize) -> CGPoint {
        let x = size.width * t
        let y = size.height * 0.5 + sin(t * .pi * 2) * 50
        return CGPoint(x: x, y: y)
    }
}

private struct DemoStrokePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 60
        path.move(to: CGPoint(x: 0, y: rect.midY))
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.width * t
            let y = rect.midY + sin(t * .pi * 2) * 50
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

// MARK: - Demo: Auto save

private struct AutoSaveDemo: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Thumbnail placeholder that slides into the My Work tile.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(colors: [AppTheme.accent, AppTheme.accentSecondary],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 110, height: 110)
                .overlay(
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.9))
                )
                .offset(x: phase < 0.5 ? -60 : 50, y: phase < 0.5 ? -40 : 40)
                .opacity(phase < 0.5 ? 1 : 0.35)
                .scaleEffect(phase < 0.5 ? 1 : 0.5)

            // Target "My Work" card.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: 130, height: 130)
                .offset(x: 50, y: 40)

            // Checkmark appears once the thumbnail "lands".
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(hex: "#6DBE71"))
                .offset(x: 84, y: 16)
                .opacity(phase > 0.55 ? 1 : 0)
                .scaleEffect(phase > 0.55 ? 1 : 0.4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Model

private struct OnboardingStep {
    let title: String
    let description: String
}
