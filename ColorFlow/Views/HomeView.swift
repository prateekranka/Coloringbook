import SwiftUI

@MainActor
struct HomeView: View {
    @State private var viewModel: HomeViewModel
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
        ZStack {
            SableTheme.cream.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HeroBanner()
                        .padding(.top, 14)

                    if viewModel.isLoading {
                        LoadingHomeContent()
                    } else {
                        if !viewModel.continuePages.isEmpty {
                            ContinueSection(
                                pages: viewModel.continuePages,
                                navigate: { navigate(.coloringPage($0)) }
                            )
                        }

                        FeaturedCollectionsSection(
                            collections: viewModel.collections,
                            navigate: { navigate(.collection($0)) }
                        )

                        MoodSection(
                            moods: viewModel.moods,
                            navigate: { navigate(.mood($0)) }
                        )
                    }
                }
                .padding(.horizontal, SableTheme.Spacing.pageInset)
                .padding(.bottom, 18)
            }
        }
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }
}

private struct HeroBanner: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            PoppyHero()
                .frame(height: 230)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 8, y: -8)
                .accessibilityHidden(true)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SABLE")
                        .font(SableTheme.Font.hero)
                        .foregroundStyle(SableTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("COLOR YOUR WORLD")
                        .font(SableTheme.Font.heroSubtitle)
                        .foregroundStyle(SableTheme.crimson)
                        .lineLimit(1)

                    CrimsonBrushStroke()
                        .frame(width: 220, height: 18)
                        .padding(.top, 10)
                }
                .frame(width: 340, alignment: .leading)

                Spacer()

                HStack(spacing: 16) {
                    CircleIconButton(systemImage: "magnifyingglass", identifier: "home.search")
                    CircleIconButton(systemImage: "person.crop.circle.fill", identifier: "home.profile")
                }
                .padding(.top, 8)
            }
        }
        .frame(height: 230)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sable, Color Your World")
    }
}

private struct ContinueSection: View {
    let pages: [ColoringPage]
    let navigate: (ColoringPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.section) {
            SectionBadge(title: "CONTINUE")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SableTheme.Spacing.cardGap) {
                    ForEach(pages) { page in
                        ContinueCard(page: page) {
                            navigate(page)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct FeaturedCollectionsSection: View {
    let collections: [PageCollection]
    let navigate: (PageCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.section) {
            SectionBadge(title: "FEATURED COLLECTIONS")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SableTheme.Spacing.cardGap) {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        CollectionCard(collection: collection, index: index) {
                            navigate(collection)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct MoodSection: View {
    let moods: [MoodCategory]
    let navigate: (MoodCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.section) {
            SectionBadge(title: "BROWSE BY MOOD")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SableTheme.Spacing.cardGap) {
                    ForEach(moods) { mood in
                        MoodCard(mood: mood) {
                            navigate(mood)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct SectionBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(SableTheme.Font.badge)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(SableTheme.cardBlack)
                    .overlay(alignment: .leading) {
                        tornEdge
                    }
                    .overlay(alignment: .trailing) {
                        tornEdge.rotationEffect(.degrees(180))
                    }
            }
    }

    private var tornEdge: some View {
        HStack(spacing: -3) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(SableTheme.cream)
                    .frame(width: index.isMultiple(of: 2) ? 8 : 5, height: index.isMultiple(of: 2) ? 8 : 5)
            }
        }
        .offset(x: -4)
    }
}

private struct ContinueCard: View {
    let page: ColoringPage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .accessibilityIdentifier("home.continue.\(page.title.normalizedIdentifier).thumbnail")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(page.title)
                            .font(SableTheme.Font.cardTitle)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        Text(progressText)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                    }

                    ProgressTrack(progress: page.progress)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(SableTheme.cardBlack.opacity(0.96))
            }
            .frame(width: 420, height: 154)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(color: SableTheme.cardShadow, radius: 8, x: 0, y: 5)
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
            ZStack(alignment: .bottomLeading) {
                PlaceholderArtwork(
                    tint: palette[index % palette.count],
                    seed: collection.name,
                    style: .compact
                )

                HStack(alignment: .center) {
                    Text(collection.name)
                        .font(SableTheme.Font.cardTitle)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Spacer(minLength: 10)

                    Text(collection.pageCountLabel)
                        .font(SableTheme.Font.pill)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(SableTheme.cardBlack.opacity(0.72), in: Capsule())
                        .overlay {
                            Capsule().stroke(.white.opacity(0.38), lineWidth: 1)
                        }
                }
                .padding(12)
                .background(SableTheme.cardBlack.opacity(0.94))
            }
            .frame(width: 266, height: 136)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(color: SableTheme.cardShadow, radius: 7, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(collection.name), \(collection.pageCountLabel)")
        .accessibilityIdentifier("home.collection.\(collection.name.normalizedIdentifier)")
    }

    private var palette: [Color] {
        [
            SableTheme.crimson,
            SableTheme.progressPink,
            Color(hex: "#E8611A"),
            Color(hex: "#2BBCB3")
        ]
    }
}

private struct MoodCard: View {
    let mood: MoodCategory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                PlaceholderArtwork(tint: mood.accentColor, seed: mood.title, style: .mood)
                    .frame(height: 126)

                Text(mood.title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(SableTheme.cardBlack.opacity(0.96))

                mood.accentColor
                    .frame(height: 7)
            }
            .frame(width: 228, height: 171)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(color: SableTheme.cardShadow, radius: 7, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.title)
        .accessibilityIdentifier("home.mood.\(mood.rawValue)")
    }
}

struct ProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white, SableTheme.progressPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 7)
    }
}

private struct LoadingHomeContent: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .tint(SableTheme.progressPink)
                .scaleEffect(1.3)

            Text("Loading Sable")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(SableTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }
}

private struct CircleIconButton: View {
    let systemImage: String
    let identifier: String

    var body: some View {
        Button {} label: {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(SableTheme.ink)
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.76), in: Circle())
                .overlay {
                    Circle().stroke(SableTheme.hairline, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct CrimsonBrushStroke: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(SableTheme.progressPink)
                .frame(width: 214, height: 10)
                .rotationEffect(.degrees(-2))

            Capsule()
                .fill(SableTheme.crimson.opacity(0.78))
                .frame(width: 228, height: 5)
                .offset(x: 3, y: 4)
                .rotationEffect(.degrees(1))
        }
    }
}

private struct PoppyHero: View {
    var body: some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? SableTheme.progressPink : SableTheme.cardBlack)
                    .frame(width: CGFloat(4 + (index % 5) * 3), height: CGFloat(4 + (index % 5) * 3))
                    .offset(x: CGFloat((index * 47) % 620) - 280, y: CGFloat((index * 31) % 200) - 90)
                    .opacity(index.isMultiple(of: 3) ? 0.7 : 0.9)
            }

            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .stroke(SableTheme.ink.opacity(0.92), lineWidth: 2)
                    .frame(width: 130, height: 18)
                    .rotationEffect(.degrees(Double(index) * 22 - 90))
                    .offset(x: CGFloat(index - 5) * 44, y: CGFloat(index % 4) * 14 - 46)
            }

            ZStack {
                ForEach(0..<14, id: \.self) { index in
                    Ellipse()
                        .fill(index.isMultiple(of: 2) ? SableTheme.crimson : Color(hex: "#F04425"))
                        .frame(width: 96, height: 42)
                        .overlay {
                            Ellipse().stroke(SableTheme.ink, lineWidth: 2)
                        }
                        .rotationEffect(.degrees(Double(index) * 25.7))
                        .offset(x: 74)
                }

                Circle()
                    .fill(SableTheme.cardBlack)
                    .frame(width: 86, height: 86)
                    .overlay {
                        Circle().stroke(.white.opacity(0.36), lineWidth: 2)
                    }
            }
            .offset(x: 190, y: -8)
        }
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

                tint.opacity(style == .mood ? 0.88 : 0.78)
                    .clipShape(PlaceholderArtShape(style: style))
                    .overlay {
                        PlaceholderArtShape(style: style)
                            .stroke(SableTheme.ink, lineWidth: 2)
                    }

                ForEach(0..<decorativeCount, id: \.self) { index in
                    decorativeMark(index: index, size: proxy.size)
                }
            }
        }
    }

    private var decorativeCount: Int {
        style == .wide ? 14 : 9
    }

    private func lineField(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            let rows = style == .mood ? 5 : 8
            for row in 0..<rows {
                let y = size.height * CGFloat(row + 1) / CGFloat(rows + 1)
                path.move(to: CGPoint(x: -12, y: y))
                for step in 0...8 {
                    let x = size.width * CGFloat(step) / 8
                    let wave = sin(CGFloat(step) + CGFloat(row) + CGFloat(seed.count)) * 11
                    path.addLine(to: CGPoint(x: x, y: y + wave))
                }
            }
            context.stroke(path, with: .color(SableTheme.ink.opacity(0.78)), lineWidth: 1.2)
        }
    }

    private func decorativeMark(index: Int, size: CGSize) -> some View {
        let x = CGFloat((index * 61 + seed.count * 7) % 100) / 100 * size.width
        let y = CGFloat((index * 37 + seed.count * 11) % 100) / 100 * size.height
        let markSize = CGFloat(16 + (index % 4) * 9)

        return Group {
            if index.isMultiple(of: 2) {
                Circle()
                    .stroke(SableTheme.ink, lineWidth: 1.4)
                    .frame(width: markSize, height: markSize)
            } else {
                Capsule()
                    .fill(tint.opacity(0.35))
                    .frame(width: markSize * 1.8, height: max(6, markSize * 0.28))
                    .rotationEffect(.degrees(Double(index * 21)))
            }
        }
        .position(x: x, y: y)
    }
}

private struct PlaceholderArtShape: Shape {
    let style: PlaceholderArtworkStyle

    func path(in rect: CGRect) -> Path {
        switch style {
        case .wide:
            return RoundedRectangle(cornerRadius: rect.height * 0.32).path(in: rect)
        case .compact:
            return Ellipse().path(in: rect)
        case .mood:
            return Capsule().path(in: rect)
        }
    }
}

#Preview("Home") {
    HomeView(viewModel: .previewLoaded)
}

#Preview("Loading") {
    HomeView(viewModel: .previewLoading)
}
