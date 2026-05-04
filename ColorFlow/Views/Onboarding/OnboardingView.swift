import SwiftUI

/// Premium onboarding: three animated steps, themed for the dark app chrome.
/// Routing contract preserved: `OnboardingView(isPresented:)` toggled by
/// `ContentView` via `@AppStorage("hasSeenOnboarding")`.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0

    private let steps = OnboardingStep.allCases

    private var currentStep: OnboardingStep {
        steps[currentIndex]
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 12)

                heroAndCopy
                    .frame(maxWidth: 620)

                Spacer(minLength: 12)

                PageIndicator(count: steps.count, current: currentIndex, accent: currentStep.accent)
                    .padding(.bottom, 28)

                ctaButton
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .sensoryFeedback(.selection, trigger: currentIndex)
        .sensoryFeedback(.success, trigger: isPresented)
        .simultaneousGesture(pageDrag)
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        ZStack {
            AppTheme.Surface.background
                .ignoresSafeArea()

            // A subtle gradient tinted by the current step's accent.
            RadialGradient(
                colors: [currentStep.accent.opacity(0.28), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 520
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.7), value: currentIndex)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Skip")
                    .font(Font.cfCaption)
                    .foregroundStyle(AppTheme.Ink.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(.regularMaterial)
                    )
            }
            .opacity(currentIndex == steps.count - 1 ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: currentIndex)
            .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.top, 8)
    }

    private var heroAndCopy: some View {
        VStack(spacing: 36) {
            hero(for: currentStep)
                .frame(height: 260)
                .id(currentStep.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.92)),
                    removal: .opacity
                ))

            VStack(spacing: 14) {
                Text(currentStep.eyebrow.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(currentStep.accent)
                    .contentTransition(.opacity)
                    .id("eyebrow-\(currentStep.id)")

                Text(currentStep.title)
                    .font(Font.cfDisplayHero)
                    .foregroundStyle(AppTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .id("title-\(currentStep.id)")

                Text(currentStep.body)
                    .font(Font.cfBody)
                    .foregroundStyle(AppTheme.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .id("body-\(currentStep.id)")
            }
            .animation(AppTheme.Motion.pageTransition, value: currentIndex)
        }
        .offset(x: dragOffset * 0.12)   // subtle parallax while dragging
        .animation(AppTheme.Motion.pageTransition, value: currentIndex)
    }

    @ViewBuilder
    private func hero(for step: OnboardingStep) -> some View {
        switch step {
        case .stayInLines:   FillHeroView(accent: step.accent)
        case .multipleTools: PencilStrokeHeroView(accent: step.accent)
        case .iCloudSync:    StackedCardsHeroView(accent: step.accent)
        }
    }

    private var ctaButton: some View {
        Button {
            advance()
        } label: {
            Text(currentStep.ctaLabel)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.Brand.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Brand.accent, AppTheme.Brand.accentPressed],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay {
                    Capsule().stroke(AppTheme.Brand.onAccent.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: AppTheme.Brand.accent.opacity(0.45), radius: 18, x: 0, y: 10)
                .contentTransition(.opacity)
        }
        .accessibilityIdentifier("onboarding.cta")
    }

    // MARK: - Interaction

    private var pageDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 60
                if value.translation.width < -threshold, currentIndex < steps.count - 1 {
                    move(to: currentIndex + 1)
                } else if value.translation.width > threshold, currentIndex > 0 {
                    move(to: currentIndex - 1)
                }
                withAnimation(AppTheme.Motion.pageTransition) {
                    dragOffset = 0
                }
            }
    }

    private func advance() {
        if currentIndex < steps.count - 1 {
            move(to: currentIndex + 1)
        } else {
            dismiss()
        }
    }

    private func move(to index: Int) {
        withAnimation(AppTheme.Motion.pageTransition) {
            currentIndex = index
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }
}

#Preview {
    StatefulPreview()
}

private struct StatefulPreview: View {
    @State var visible = true
    var body: some View {
        OnboardingView(isPresented: $visible)
    }
}
