import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "drop.fill",
            iconColor: AppTheme.accent,
            title: "Tap to Fill",
            description: "Tap any enclosed region to instantly fill it with your chosen color."
        ),
        OnboardingStep(
            icon: "applepencil",
            iconColor: Color(red: 0.20, green: 0.67, blue: 0.86),
            title: "Draw with Pencil",
            description: "Use your Apple Pencil to add fine details with pressure-sensitive strokes."
        ),
        OnboardingStep(
            icon: "arrow.clockwise.icloud",
            iconColor: Color(red: 0.30, green: 0.76, blue: 0.45),
            title: "Auto-saved",
            description: "Your work saves automatically. Pick up where you left off, any time."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon + content
            TabView(selection: $currentStep) {
                ForEach(steps.indices, id: \.self) { i in
                    StepCard(step: steps[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 380)

            // Page dots
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle()
                        .fill(i == currentStep ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                        .animation(reduceMotion ? nil : .easeInOut, value: currentStep)
                }
            }
            .accessibilityHidden(true)
            .padding(.vertical, 24)

            Spacer()

            // CTA
            Button {
                if currentStep < steps.count - 1 {
                    withAnimation(reduceMotion ? nil : .default) { currentStep += 1 }
                } else {
                    isPresented = false
                }
            } label: {
                Text(currentStep < steps.count - 1 ? "Next" : "Start Coloring")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Step Card

private struct StepCard: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: step.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(step.iconColor)
            }

            VStack(spacing: 12) {
                Text(step.title)
                    .font(.title.bold())
                Text(step.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.top, 20)
    }
}

// MARK: - Model

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}
