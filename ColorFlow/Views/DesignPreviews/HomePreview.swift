import SwiftUI

/// Proposed Home Tab layout — full-width hero card + horizontal scroll rows.
/// Renders real SVG templates with proper ColorFlow branding (Fraunces font, sage accent).
struct ProposedHomeView: View {
    let templates: [Template]
    let thumbnails: [UUID: UIImage]

    private var featured: Template? { templates.first }
    private var recent: [Template] { Array(templates.dropFirst().prefix(4)) }
    private var inspiration: [Template] { Array(templates.prefix(6)) }
    private var suggested: [Template] { Array(templates.suffix(6)) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Brand header with brush mark
                        brandHeader

                        if let template = featured {
                            featuredCard(template)
                        }

                        sectionHeader("My Recent Work", showSeeAll: true)
                        recentRow

                        sectionHeader("Inspiration", showSeeAll: true)
                        inspirationRow

                        sectionHeader("Suggested For You", showSeeAll: true)
                        suggestedRow
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack(spacing: 10) {
            // Brush mark icon (sage green)
            BrushMarkShape()
                .stroke(
                    AppTheme.Brand.accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .glow(color: AppTheme.Brand.accent.opacity(0.55), radius: 6)
                .frame(width: 28, height: 28)

            Text("ColorFlow")
                .font(Font.cfTitle)
                .foregroundStyle(AppTheme.Ink.primary)

            Spacer()

            Button { } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Featured Hero Card

    private func featuredCard(_ template: Template) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                .fill(Color.white)
                .aspectRatio(16/10, contentMode: .fit)

            if let img = thumbnails[template.id] {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            }

            // Gradient overlay (sage-tinted)
            LinearGradient(
                colors: [
                    AppTheme.Brand.accent.opacity(0.15),
                    .black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))

            // Text overlay
            VStack(alignment: .leading, spacing: 8) {
                // Eyebrow
                Text("FEATURED")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(AppTheme.Brand.accent)

                Text(template.name)
                    .font(Font.cfDisplayLarge)
                    .foregroundStyle(.white)

                Text("\(template.category.rawValue) · \(template.difficulty.rawValue)")
                    .font(Font.cfSubheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Button { } label: {
                    Text("Start Coloring")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.Brand.onAccent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [AppTheme.Brand.accent, AppTheme.Brand.accentPressed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        .overlay(
                            Capsule().stroke(AppTheme.Brand.onAccent.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: AppTheme.Brand.accent.opacity(0.45), radius: 12, y: 6)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Row

    private var recentRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(recent) { template in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                .fill(Color.white)
                                .aspectRatio(1, contentMode: .fit)

                            if let img = thumbnails[template.id] {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(8)
                            }
                        }
                        .frame(width: 140, height: 140)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                        Text(template.name)
                            .font(Font.cfCaptionBold)
                            .foregroundStyle(AppTheme.Ink.primary)
                            .lineLimit(1)
                            .frame(width: 140, alignment: .leading)

                        // Progress bar (mock)
                        HStack(spacing: 4) {
                            ProgressView(value: Double.random(in: 0.2...1.0))
                                .tint(AppTheme.Brand.accent)
                                .frame(width: 80)
                            Text("\(Int.random(in: 20...100))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AppTheme.Ink.tertiary)
                        }
                    }
                }

                // "Start new" card
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .fill(AppTheme.Surface.elevated)
                            .frame(width: 140, height: 140)

                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.Brand.accent)
                                .glow(color: AppTheme.Brand.accent.opacity(0.4), radius: 8)
                            Text("Start New")
                                .font(Font.cfCaptionBold)
                                .foregroundStyle(AppTheme.Ink.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Inspiration Row

    private var inspirationRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(inspiration) { template in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                .fill(Color.white)
                                .aspectRatio(4/3, contentMode: .fit)

                            if let img = thumbnails[template.id] {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(8)
                            }
                        }
                        .frame(width: 160, height: 120)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                        Text(template.name)
                            .font(Font.cfCaptionBold)
                            .foregroundStyle(AppTheme.Ink.primary)
                            .lineLimit(1)
                            .frame(width: 160, alignment: .leading)

                        DifficultyPillView(difficulty: template.difficulty)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Suggested Row

    private var suggestedRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(suggested) { template in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                .fill(Color.white)
                                .aspectRatio(4/3, contentMode: .fit)

                            if let img = thumbnails[template.id] {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(8)
                            }
                        }
                        .frame(width: 160, height: 120)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                        Text(template.name)
                            .font(Font.cfCaptionBold)
                            .foregroundStyle(AppTheme.Ink.primary)
                            .lineLimit(1)
                            .frame(width: 160, alignment: .leading)

                        DifficultyPillView(difficulty: template.difficulty)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, showSeeAll: Bool) -> some View {
        HStack {
            Text(title)
                .font(Font.cfHeadline)
                .foregroundStyle(AppTheme.Ink.primary)
            Spacer()
            if showSeeAll {
                Button("See All") { }
                    .font(Font.cfSubheadline)
                    .foregroundStyle(AppTheme.Brand.accent)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - BrushMarkShape (from SplashView)

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

// MARK: - Difficulty Pill

private struct DifficultyPillView: View {
    let difficulty: Difficulty

    private var color: Color {
        switch difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.18)))
    }
}

// MARK: - SVG Rendering Helper

private func homePreviewThumb(for template: Template, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
    guard let url = template.svgURL,
          case .success(let geo) = SVGParser.parse(url: url) else { return nil }
    return TemplateRenderer.renderThumbnail(geometry: geo, fills: [:], size: size)
}

// MARK: - Preview

#Preview("Proposed Home — Branded") {
    let allTemplates = Template.loadAll()
    var thumbs: [UUID: UIImage] = [:]
    for t in allTemplates {
        if let img = homePreviewThumb(for: t) {
            thumbs[t.id] = img
        }
    }
    return ProposedHomeView(templates: allTemplates, thumbnails: thumbs)
        .environment(AppState.shared)
        .preferredColorScheme(.dark)
}
