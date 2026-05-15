import SwiftUI

struct GouacheSearchBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SableTheme.secondaryText(for: colorScheme))

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SableTheme.primaryText(for: colorScheme))

            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(SableTheme.secondaryText(for: colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(SableTheme.elevatedSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                .stroke(SableTheme.hairline(for: colorScheme), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.bar")
    }
}

struct SegmentedFilter<Option: Identifiable & Hashable>: View {
    @Environment(\.colorScheme) private var colorScheme
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selection == option ? .white : SableTheme.primaryText(for: colorScheme))
                        .padding(.horizontal, 13)
                        .frame(height: 36)
                        .background(selection == option ? SableTheme.cardBlack : SableTheme.surface(for: colorScheme), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(SableTheme.elevatedSurface(for: colorScheme), in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.hairline(for: colorScheme), lineWidth: 1)
        }
    }
}

struct DifficultyPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let difficulty: Difficulty

    var body: some View {
        Text(difficulty.displayTitle)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(SableTheme.primaryText(for: colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(difficulty.tint.opacity(colorScheme == .dark ? 0.38 : 0.28), in: Capsule())
    }
}

struct FloatingPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                    .stroke(SableTheme.hairline(for: colorScheme), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12), radius: 18, x: 0, y: 10)
    }
}

struct PaintDab: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 46, height: 42)
                .scaleEffect(x: 1.06, y: 0.92)
                .rotationEffect(.degrees(isSelected ? -5 : 4))

            Circle()
                .stroke(.white.opacity(0.62), lineWidth: 1)
                .frame(width: 28, height: 24)
                .offset(x: -6, y: -5)
                .blur(radius: 0.4)
        }
        .overlay {
            Circle()
                .stroke(isSelected ? SableTheme.cardBlack : Color.white.opacity(0.75), lineWidth: isSelected ? 4 : 2)
                .frame(width: 50, height: 50)
        }
        .frame(width: 54, height: 54)
        .shadow(color: Color.black.opacity(0.16), radius: 5, x: 0, y: 3)
    }
}

extension Difficulty: Identifiable {
    var id: Self { self }

    var displayTitle: String {
        switch self {
        case .easy:
            return "Easy"
        case .medium:
            return "Medium"
        case .hard:
            return "Detailed"
        }
    }

    var tint: Color {
        switch self {
        case .easy:
            return SableTheme.sage
        case .medium:
            return SableTheme.butter
        case .hard:
            return SableTheme.blush
        }
    }
}
