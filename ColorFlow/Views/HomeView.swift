import SwiftUI
import UIKit

@MainActor
struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: HomeViewModel
    @State private var searchText = ""
    let navigate: (AppRoute) -> Void

    init(
        repository: any HomeRepositoryProtocol = SableHomeRepository(),
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: HomeViewModel(repository: repository))
        self.navigate = navigate
    }

    init(
        viewModel: HomeViewModel,
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigate = navigate
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SableTheme.appBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HeroBanner()
                            .frame(height: proxy.size.width > 900 ? 260 : 520)
                            .padding(.top, 26)

                        GouacheSearchBar(text: $searchText, placeholder: "Search templates, moods, subjects")

                        if viewModel.isLoading {
                            LoadingHomeContent()
                        } else {
                            if !filteredContinuePages.isEmpty {
                                ContinueSection(
                                    pages: filteredContinuePages,
                                    compact: proxy.size.width > 900,
                                    navigate: { navigate(.coloringPage($0)) }
                                )
                            }

                            MoodSection(
                                moods: TemplateMood.allCases,
                                navigate: { mood in navigate(.mood(mood.asLegacyMood)) }
                            )

                            FeaturedCollectionsSection(
                                collections: filteredCollections,
                                navigate: { navigate(.collection($0)) }
                            )

                            RecentlyAddedSection(templates: recentlyAddedTemplates, navigate: navigate)
                        }
                    }
                    .frame(width: proxy.size.width - SableTheme.Spacing.pageInset * 2, alignment: .leading)
                    .padding(.horizontal, SableTheme.Spacing.pageInset)
                    .padding(.bottom, 8)
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var filteredContinuePages: [ColoringPage] {
        guard !searchText.isEmpty else { return viewModel.continuePages }
        return viewModel.continuePages.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredCollections: [PageCollection] {
        guard !searchText.isEmpty else { return viewModel.collections }
        return viewModel.collections.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var recentlyAddedTemplates: [Template] {
        let templates = viewModel.collections.flatMap(\.previewTemplates)
        return Array(Dictionary(grouping: templates, by: \.id).compactMap { $0.value.first }.prefix(8))
    }
}

private struct HeroBanner: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isPortrait = width < 900
            let headlineSize: CGFloat = isPortrait ? 78 : 44

            ZStack(alignment: .topLeading) {
                HeroPoppyImage(isPortrait: isPortrait)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                InkSplatter()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: isPortrait ? 22 : 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: -2) {
                            Text("Gouache")
                                .font(SableTheme.Font.brand)
                                .foregroundStyle(SableTheme.ink)
                        }

                        Spacer()

                        HStack(spacing: 28) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundStyle(SableTheme.ink)

                            ProfileAvatar()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gouache")
                            .font(.custom("Fraunces", size: headlineSize).weight(.black))
                            .foregroundStyle(SableTheme.ink)
                            .lineSpacing(isPortrait ? -10 : -4)
                            .minimumScaleFactor(0.72)

                        AnimatedHeroLine()
                            .frame(width: isPortrait ? 420 : 520, height: 38, alignment: .leading)

                        CrimsonBrushStroke()
                            .frame(width: isPortrait ? 340 : 385, height: 22)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: isPortrait ? 430 : 500, alignment: .leading)
                }
                .padding(.horizontal, isPortrait ? 0 : 14)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gouache. Color slowly. Make it yours.")
    }
}

private struct AnimatedHeroLine: View {
    @State private var wordIndex = 0
    private let words = ["slowly", "intentionally", "creatively", "quietly", "freely"]

    var body: some View {
        HStack(spacing: 8) {
            Text("Color")
            ZStack {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    Text(word)
                        .opacity(index == wordIndex ? 1 : 0)
                        .offset(y: index == wordIndex ? 0 : 10)
                }
            }
            .frame(width: 150, alignment: .leading)
            Text("Make it yours.")
        }
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(SableTheme.softInk)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        wordIndex = (wordIndex + 1) % words.count
                    }
                }
            }
        }
    }
}

private struct HeroPoppyImage: View {
    let isPortrait: Bool

    var body: some View {
        GeometryReader { proxy in
            if let image = UIImage(named: "poppy-hero") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .trailing)
                    .offset(x: isPortrait ? proxy.size.width * 0.18 : 0)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ContinueSection: View {
    let pages: [ColoringPage]
    let compact: Bool
    let navigate: (ColoringPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.section) {
            SectionHeader(title: "Continue")

            GeometryReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SableTheme.Spacing.cardGap) {
                        ForEach(pages) { page in
                            ContinueCard(page: page, compact: compact) {
                                navigate(page)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .frame(height: compact ? 140 : 230)
        }
    }
}

private struct FeaturedCollectionsSection: View {
    let collections: [PageCollection]
    let navigate: (PageCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.section) {
            SectionHeader(title: "Featured Collections", showsSeeAll: true)

            GeometryReader { proxy in
                let cardWidth = (proxy.size.width - 40) / 3
                HStack(spacing: 20) {
                    ForEach(Array(collections.prefix(3).enumerated()), id: \.element.id) { index, collection in
                        CollectionCard(collection: collection, index: index) {
                            navigate(collection)
                        }
                        .frame(width: cardWidth)
                    }
                }
            }
            .frame(height: 210)
        }
    }
}

private struct MoodSection: View {
    let moods: [TemplateMood]
    let navigate: (TemplateMood) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.section) {
            SectionHeader(title: "Browse by Mood", showsSeeAll: true)

            GeometryReader { proxy in
                let cardWidth = (proxy.size.width - 40) / 3.35
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(moods) { mood in
                            MoodCard(mood: mood) {
                                navigate(mood)
                            }
                            .frame(width: cardWidth)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }
}

private struct PoppyHeroArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                WatercolorCircle(color: SableTheme.peach, opacity: 0.34)
                    .frame(width: size.width * 0.58, height: size.width * 0.58)
                    .offset(x: -size.width * 0.06, y: -size.height * 0.18)

                WatercolorCircle(color: SableTheme.blush, opacity: 0.28)
                    .frame(width: size.width * 0.44, height: size.width * 0.44)
                    .offset(x: size.width * 0.2, y: size.height * 0.2)

                Canvas { context, size in
                    let ink = SableTheme.ink
                    drawStem(in: &context, size: size, start: CGPoint(x: size.width * 0.5, y: size.height * 0.96), end: CGPoint(x: size.width * 0.47, y: size.height * 0.38), curve: -60)
                    drawStem(in: &context, size: size, start: CGPoint(x: size.width * 0.42, y: size.height * 0.92), end: CGPoint(x: size.width * 0.24, y: size.height * 0.62), curve: -80)
                    drawStem(in: &context, size: size, start: CGPoint(x: size.width * 0.57, y: size.height * 0.9), end: CGPoint(x: size.width * 0.8, y: size.height * 0.5), curve: 60)

                    drawLeaf(context: &context, center: CGPoint(x: size.width * 0.36, y: size.height * 0.72), size: CGSize(width: size.width * 0.2, height: size.height * 0.11), angle: -0.55)
                    drawLeaf(context: &context, center: CGPoint(x: size.width * 0.64, y: size.height * 0.68), size: CGSize(width: size.width * 0.22, height: size.height * 0.12), angle: 0.55)
                    drawPoppy(context: &context, center: CGPoint(x: size.width * 0.47, y: size.height * 0.28), radius: size.width * 0.23, accent: SableTheme.blush)
                    drawBud(context: &context, center: CGPoint(x: size.width * 0.24, y: size.height * 0.6), radius: size.width * 0.07)
                    drawBud(context: &context, center: CGPoint(x: size.width * 0.82, y: size.height * 0.48), radius: size.width * 0.06)

                    var ground = Path()
                    ground.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.96))
                    ground.addLine(to: CGPoint(x: size.width * 0.9, y: size.height * 0.96))
                    context.stroke(ground, with: .color(ink.opacity(0.85)), lineWidth: 1.4)
                }
            }
        }
    }

    private func drawStem(in context: inout GraphicsContext, size: CGSize, start: CGPoint, end: CGPoint, curve: CGFloat) {
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2 + curve, y: (start.y + end.y) / 2))
        context.stroke(path, with: .color(SableTheme.ink), lineWidth: 1.6)
    }

    private func drawPoppy(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, accent: Color) {
        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5
            let length = radius * (index.isMultiple(of: 2) ? 1.05 : 0.86)
            let spread = radius * 0.43
            let inner = CGPoint(
                x: center.x + cos(angle) * radius * 0.14,
                y: center.y + sin(angle) * radius * 0.1
            )
            let tip = CGPoint(
                x: center.x + cos(angle) * length,
                y: center.y + sin(angle) * length * 0.78
            )
            let normal = CGPoint(x: -sin(angle), y: cos(angle))
            var petal = Path()
            petal.move(to: inner)
            petal.addQuadCurve(
                to: tip,
                control: CGPoint(x: center.x + cos(angle - 0.34) * length * 0.72 + normal.x * spread, y: center.y + sin(angle - 0.34) * length * 0.56 + normal.y * spread)
            )
            petal.addQuadCurve(
                to: inner,
                control: CGPoint(x: center.x + cos(angle + 0.34) * length * 0.72 - normal.x * spread, y: center.y + sin(angle + 0.34) * length * 0.56 - normal.y * spread)
            )
            context.fill(petal, with: .color(accent.opacity(index.isMultiple(of: 2) ? 0.22 : 0.08)))
            context.stroke(petal, with: .color(SableTheme.ink), lineWidth: 1.5)
        }

        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.23, y: center.y - radius * 0.23, width: radius * 0.46, height: radius * 0.46)), with: .color(SableTheme.ink))
        for index in 0..<18 {
            let angle = CGFloat(index) * .pi / 9
            var line = Path()
            line.move(to: center)
            line.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 0.9, y: center.y + sin(angle) * radius * 0.56))
            context.stroke(line, with: .color(SableTheme.ink.opacity(0.5)), lineWidth: 0.8)
        }
    }

    private func drawBud(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let bud = Path(ellipseIn: CGRect(x: center.x - radius * 0.62, y: center.y - radius, width: radius * 1.24, height: radius * 1.8))
        context.fill(bud, with: .color(SableTheme.peach.opacity(0.18)))
        context.stroke(bud, with: .color(SableTheme.ink), lineWidth: 1.4)
        var crown = Path()
        crown.move(to: CGPoint(x: center.x - radius * 0.55, y: center.y - radius * 0.2))
        crown.addLine(to: CGPoint(x: center.x, y: center.y - radius * 0.48))
        crown.addLine(to: CGPoint(x: center.x + radius * 0.55, y: center.y - radius * 0.2))
        context.stroke(crown, with: .color(SableTheme.ink), lineWidth: 1)
    }

    private func drawLeaf(context: inout GraphicsContext, center: CGPoint, size: CGSize, angle: CGFloat) {
        var leaf = Path()
        leaf.move(to: CGPoint(x: center.x - size.width / 2, y: center.y))
        leaf.addQuadCurve(to: CGPoint(x: center.x + size.width / 2, y: center.y), control: CGPoint(x: center.x, y: center.y - size.height))
        leaf.addQuadCurve(to: CGPoint(x: center.x - size.width / 2, y: center.y), control: CGPoint(x: center.x, y: center.y + size.height))
        let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
            .rotated(by: angle)
            .translatedBy(x: center.x, y: center.y)
        leaf = leaf.applying(transform)
        context.fill(leaf, with: .color(SableTheme.sage.opacity(0.18)))
        context.stroke(leaf, with: .color(SableTheme.ink), lineWidth: 1.3)
    }
}

private struct SectionHeader: View {
    let title: String
    var showsSeeAll = false

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(SableTheme.Font.sectionTitle)
                .foregroundStyle(SableTheme.ink)

            Spacer()

            if showsSeeAll {
                HStack(spacing: 4) {
                    Text("See All")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "#F15D76"))
            }
        }
    }
}

private struct ContinueCard: View {
    let page: ColoringPage
    let compact: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .frame(height: compact ? 82 : 156)

                VStack(spacing: compact ? 6 : 9) {
                    HStack {
                        Text(page.title)
                            .font(SableTheme.Font.cardTitle)
                            .foregroundStyle(SableTheme.ink)
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        Text(progressText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(SableTheme.ink)
                    }

                    ProgressTrack(progress: page.progress)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, compact ? 9 : 12)
                .background(.white.opacity(0.8))
            }
            .frame(width: compact ? 300 : 300, height: compact ? 134 : 230)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                    .stroke(Color(hex: "#C99572").opacity(0.5), lineWidth: 1)
            }
            .shadow(color: SableTheme.cardShadow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(page.title), \(progressText) complete")
        .accessibilityIdentifier("home.continue.\(page.title.normalizedIdentifier)")
    }

    private var progressText: String {
        "\(Int((page.progress * 100).rounded()))%"
    }
}

private struct CollectionCard: View {
    let collection: PageCollection
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                CollectionThumbnailStrip(
                    templates: collection.previewTemplates,
                    fallbackTint: collection.category.accentColor,
                    seed: collection.name
                )
                .frame(height: 116)

                VStack(spacing: 8) {
                    Text(collection.name)
                        .font(SableTheme.Font.cardSerif)
                        .foregroundStyle(SableTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(collection.pageCountLabel)
                        .font(SableTheme.Font.pill)
                        .foregroundStyle(SableTheme.ink.opacity(0.78))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(pageCountColor.opacity(0.45), in: Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                    .stroke(Color(hex: "#C99572").opacity(0.45), lineWidth: 1)
            }
            .shadow(color: SableTheme.cardShadow, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(collection.name), \(collection.pageCountLabel)")
        .accessibilityIdentifier("home.collection.\(collection.name.normalizedIdentifier)")
    }

    private var pageCountColor: Color {
        [SableTheme.blush, SableTheme.sage, SableTheme.peach, SableTheme.butter][index % 4]
    }
}

private struct CollectionThumbnailStrip: View {
    let templates: [Template]
    let fallbackTint: Color
    let seed: String

    var body: some View {
        GeometryReader { proxy in
            if let template = templates.first {
                TemplateArtworkView(template: template, size: CGSize(width: 260, height: 180), strokeWidth: 1.25)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                PlaceholderArtwork(tint: fallbackTint, seed: seed, style: .compact)
            }
        }
        .background(SableTheme.paper)
        .clipped()
    }
}

private struct MoodCard: View {
    let mood: TemplateMood
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                PigmentMoodArtwork(mood: mood)
                    .frame(height: 142)

                Text(mood.title)
                    .font(SableTheme.Font.cardSerif)
                    .foregroundStyle(SableTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(moodBackground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.card)
                    .stroke(Color(hex: "#C99572").opacity(0.4), lineWidth: 1)
            }
            .shadow(color: SableTheme.cardShadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.title)
        .accessibilityIdentifier("home.mood.\(mood.rawValue)")
    }

    private var moodBackground: Color {
        switch mood {
        case .calm, .focus:
            return SableTheme.sage
        case .bold:
            return SableTheme.butter
        case .dreamy:
            return SableTheme.mist
        }
    }
}

private struct PigmentMoodArtwork: View {
    let mood: TemplateMood

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SableTheme.paper))
                for index in 0..<8 {
                    let width = size.width * CGFloat(0.32 + Double((index % 3)) * 0.08)
                    let height = size.height * CGFloat(0.2 + Double((index % 4)) * 0.04)
                    let x = CGFloat((index * 41) % 100) / 100 * size.width
                    let y = CGFloat((index * 29) % 100) / 100 * size.height
                    let rect = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
                    var path = Path(ellipseIn: rect)
                    path = path.applying(.init(rotationAngle: CGFloat(index) * 0.34))
                    context.fill(path, with: .color(mood.color.opacity(index.isMultiple(of: 2) ? 0.42 : 0.24)))
                }

                var line = Path()
                line.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.7))
                line.addCurve(
                    to: CGPoint(x: size.width * 0.86, y: size.height * 0.34),
                    control1: CGPoint(x: size.width * 0.38, y: size.height * 0.18),
                    control2: CGPoint(x: size.width * 0.58, y: size.height * 0.82)
                )
                context.stroke(line, with: .color(SableTheme.ink.opacity(0.64)), lineWidth: 1.4)
            }
        }
    }
}

private extension TemplateMood {
    var asLegacyMood: MoodCategory {
        switch self {
        case .calm:
            return .calm
        case .bold:
            return .bold
        case .dreamy:
            return .dreamy
        case .focus:
            return .noir
        }
    }
}

private struct RecentlyAddedSection: View {
    let templates: [Template]
    let navigate: (AppRoute) -> Void

    var body: some View {
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: SableTheme.Spacing.section) {
                SectionHeader(title: "Recently Added")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SableTheme.Spacing.cardGap) {
                        ForEach(templates) { template in
                            Button {
                                navigate(.canvas(CanvasRoute(projectId: UUID(), templateId: template.id, title: template.name)))
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    TemplateArtworkView(template: template, size: CGSize(width: 210, height: 180), strokeWidth: 1.1)
                                        .frame(width: 210, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))

                                    Text(template.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(SableTheme.ink)
                                        .lineLimit(1)
                                }
                                .frame(width: 210, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct ProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.13))

                Capsule()
                    .fill(Color(hex: "#F35C78"))
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 5)
    }
}

private struct TemplateArtworkView: View {
    let template: Template
    let size: CGSize
    let strokeWidth: CGFloat
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            SableTheme.paper

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .task(id: template.id) {
            image = await TemplateRenderer.thumbnail(
                for: template,
                size: size,
                strokeWidthPixels: strokeWidth
            )
        }
    }
}

private struct LoadingHomeContent: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .tint(SableTheme.progressPink)
                .scaleEffect(1.3)

            Text("Loading Gouache")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SableTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }
}

private struct CrimsonBrushStroke: View {
    var body: some View {
        Canvas { context, size in
            var main = Path()
            main.move(to: CGPoint(x: 0, y: size.height * 0.52))
            main.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.46),
                control1: CGPoint(x: size.width * 0.28, y: size.height * 0.14),
                control2: CGPoint(x: size.width * 0.72, y: size.height * 0.82)
            )
            context.stroke(main, with: .color(Color(hex: "#F05C77")), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            var lower = Path()
            lower.move(to: CGPoint(x: 16, y: size.height * 0.72))
            lower.addCurve(
                to: CGPoint(x: size.width * 0.92, y: size.height * 0.7),
                control1: CGPoint(x: size.width * 0.32, y: size.height * 0.6),
                control2: CGPoint(x: size.width * 0.62, y: size.height * 0.84)
            )
            context.stroke(lower, with: .color(Color(hex: "#F38BA0").opacity(0.8)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }
}

private struct WatercolorBackground: View {
    var body: some View {
        ZStack {
            WatercolorCircle(color: SableTheme.peach, opacity: 0.48)
                .frame(width: 330, height: 330)
                .offset(x: 475, y: 96)

            WatercolorCircle(color: SableTheme.blush, opacity: 0.4)
                .frame(width: 245, height: 245)
                .offset(x: 735, y: 250)

            WatercolorCircle(color: Color(hex: "#F8CF9F"), opacity: 0.34)
                .frame(width: 128, height: 128)
                .offset(x: 835, y: 184)
        }
    }
}

private struct WatercolorCircle: View {
    let color: Color
    let opacity: Double

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(color.opacity(opacity / Double(index + 1)))
                    .scaleEffect(1 + CGFloat(index) * 0.04)
                    .blur(radius: CGFloat(index) * 1.7)
                    .offset(x: CGFloat((index % 3) - 1) * 4, y: CGFloat(index - 3) * 2)
            }
        }
    }
}

private struct InkSplatter: View {
    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { index in
                Circle()
                    .fill(SableTheme.ink)
                    .frame(width: CGFloat(2 + (index % 5) * 2), height: CGFloat(2 + (index % 5) * 2))
                    .offset(
                        x: CGFloat((index * 67) % 860) + 310,
                        y: CGFloat((index * 41) % 340) + 20
                    )
                    .opacity(index.isMultiple(of: 4) ? 0.35 : 0.9)
            }
        }
    }
}

private struct ProfileAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#F6DDD1"))
            Circle()
                .stroke(Color(hex: "#EF9E8E"), lineWidth: 1)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 47))
                .foregroundStyle(SableTheme.ink, Color(hex: "#D98974"))
                .offset(y: 1)
        }
        .frame(width: 58, height: 58)
        .accessibilityLabel("Profile")
    }
}

enum PlaceholderArtworkStyle {
    case wide
    case compact
    case mood
}

struct PlaceholderArtwork: View {
    let tint: Color
    let seed: String
    let style: PlaceholderArtworkStyle

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SableTheme.paper
                lineField(in: proxy.size)
                tint.opacity(0.3)
                    .clipShape(PlaceholderArtShape(style: style))
                    .overlay {
                        PlaceholderArtShape(style: style)
                            .stroke(SableTheme.ink, lineWidth: 1.4)
                    }
            }
        }
    }

    private func lineField(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            for row in 0..<7 {
                let y = size.height * CGFloat(row + 1) / 8
                path.move(to: CGPoint(x: -12, y: y))
                for step in 0...8 {
                    let x = size.width * CGFloat(step) / 8
                    let wave = sin(CGFloat(step) + CGFloat(row) + CGFloat(seed.count)) * 9
                    path.addLine(to: CGPoint(x: x, y: y + wave))
                }
            }
            context.stroke(path, with: .color(SableTheme.ink.opacity(0.55)), lineWidth: 1)
        }
    }
}

private struct PlaceholderArtShape: Shape {
    let style: PlaceholderArtworkStyle

    func path(in rect: CGRect) -> Path {
        switch style {
        case .wide:
            return RoundedRectangle(cornerRadius: rect.height * 0.2).path(in: rect.insetBy(dx: 34, dy: 24))
        case .compact:
            return Ellipse().path(in: rect.insetBy(dx: 24, dy: 18))
        case .mood:
            return Capsule().path(in: rect.insetBy(dx: 30, dy: 24))
        }
    }
}

private extension TemplateCategory {
    var accentColor: Color {
        switch self {
        case .mandalas:
            return MoodCategory.dreamy.accentColor
        case .animals:
            return MoodCategory.wild.accentColor
        case .architecture:
            return MoodCategory.noir.accentColor
        case .abstract:
            return MoodCategory.bold.accentColor
        case .botanicals:
            return MoodCategory.calm.accentColor
        case .lifestyle:
            return MoodCategory.playful.accentColor
        }
    }
}

private struct TemplateThumbnailTaskID: Hashable {
    let templateID: UUID
    let strokeWidth: Double
}

#Preview("Home") {
    HomeView(viewModel: .previewLoaded)
        .environment(RenderTuningStore())
}

#Preview("Loading") {
    HomeView(viewModel: .previewLoading)
        .environment(RenderTuningStore())
}
