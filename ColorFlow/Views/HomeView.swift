import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: HomeViewModel
    @State private var isSearchExpanded = false
    @State private var searchText = ""
    let navigate: (AppRoute) -> Void
    let openProfile: () -> Void
    let openMyWork: () -> Void
    let openCollections: () -> Void
    let openRecentlyAdded: () -> Void

    init(
        repository: any HomeRepositoryProtocol = SableHomeRepository(),
        navigate: @escaping (AppRoute) -> Void = { _ in },
        openProfile: @escaping () -> Void = {},
        openMyWork: @escaping () -> Void = {},
        openCollections: @escaping () -> Void = {},
        openRecentlyAdded: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: HomeViewModel(repository: repository))
        self.navigate = navigate
        self.openProfile = openProfile
        self.openMyWork = openMyWork
        self.openCollections = openCollections
        self.openRecentlyAdded = openRecentlyAdded
    }

    init(
        viewModel: HomeViewModel,
        navigate: @escaping (AppRoute) -> Void = { _ in },
        openProfile: @escaping () -> Void = {},
        openMyWork: @escaping () -> Void = {},
        openCollections: @escaping () -> Void = {},
        openRecentlyAdded: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigate = navigate
        self.openProfile = openProfile
        self.openMyWork = openMyWork
        self.openCollections = openCollections
        self.openRecentlyAdded = openRecentlyAdded
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = GouacheHomeMetrics(size: proxy.size)

            ZStack {
                GouachePaperBackground()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                        GouacheHero(
                            metrics: metrics,
                            isSearchExpanded: $isSearchExpanded,
                            searchText: $searchText,
                            openProfile: openProfile,
                            submitSearch: submitSearch
                        )

                        ContinueSection(
                            pages: displayContinuePages,
                            metrics: metrics,
                            seeAll: openMyWork,
                            navigate: { navigate(.coloringPage($0)) }
                        )

                        FeaturedCollectionsSection(
                            collections: displayCollections,
                            metrics: metrics,
                            seeAll: openCollections,
                            navigate: { navigate(.collection($0)) }
                        )

                        MoodSection(metrics: metrics) { mood in
                            navigate(.mood(mood.routeMood))
                        }

                        RecentlyAddedSection(
                            pages: displayRecentlyAddedPages,
                            metrics: metrics,
                            seeAll: openRecentlyAdded,
                            navigate: { navigate(.coloringPage($0)) }
                        )
                    }
                    .padding(.horizontal, metrics.horizontalInset)
                    .padding(.top, metrics.topContentPadding)
                    .padding(.bottom, metrics.bottomContentPadding)
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var displayContinuePages: [ColoringPage] {
        Array(viewModel.continuePages.prefix(6))
    }

    private var displayRecentlyAddedPages: [ColoringPage] {
        Array(viewModel.recentlyAddedPages.prefix(8))
    }

    private var displayCollections: [PageCollection] {
        viewModel.collections
    }

    private func submitSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        navigate(.search(query))
    }

}

private struct GouacheHomeMetrics {
    let size: CGSize

    var isLandscape: Bool {
        size.width > size.height
    }

    var horizontalInset: CGFloat {
        isLandscape ? 44 : 44
    }

    var contentWidth: CGFloat {
        max(320, size.width - (horizontalInset * 2))
    }

    var heroHeight: CGFloat {
        isLandscape ? min(340, max(300, size.height * 0.32)) : min(430, max(388, size.height * 0.31))
    }

    var titleSize: CGFloat {
        isLandscape ? 64 : 66
    }

    var titleTop: CGFloat {
        isLandscape ? 108 : 132
    }

    var searchWidth: CGFloat {
        min(isLandscape ? 505 : 470, contentWidth * 0.52)
    }

    var sectionSpacing: CGFloat {
        isLandscape ? 19 : 22
    }

    var sectionHeaderSpacing: CGFloat {
        isLandscape ? 12 : 15
    }

    var cardGap: CGFloat {
        isLandscape ? 18 : 18
    }

    var continueCardWidth: CGFloat {
        if isLandscape {
            return max(205, (contentWidth - (cardGap * 5)) / 6)
        }

        return max(212, (contentWidth - (cardGap * 3)) / 4.25)
    }

    var continueImageHeight: CGFloat {
        isLandscape ? continueCardWidth * 0.54 : continueCardWidth * 0.72
    }

    var continueFooterHeight: CGFloat {
        isLandscape ? 48 : 58
    }

    var moodCardWidth: CGFloat {
        let visibleCount: CGFloat = isLandscape ? 4 : 3.28
        return (contentWidth - (cardGap * (visibleCount - 1))) / visibleCount
    }

    var moodCardHeight: CGFloat {
        moodCardWidth
    }

    var collectionCardWidth: CGFloat {
        let visibleCount: CGFloat = isLandscape ? 4 : (contentWidth < 780 ? 2.35 : 3)
        return (contentWidth - (cardGap * (visibleCount - 1))) / visibleCount
    }

    var collectionCardHeight: CGFloat {
        isLandscape ? 108 : 126
    }

    var recentCardWidth: CGFloat {
        isLandscape ? 146 : 152
    }

    var recentCardHeight: CGFloat {
        isLandscape ? 112 : 128
    }

    var bottomContentPadding: CGFloat {
        122
    }

    var topContentPadding: CGFloat {
        isLandscape ? 10 : 14
    }
}

struct GouachePaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let palette = GouacheResolvedPalette(scheme: colorScheme)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.background))

            for index in 0..<190 {
                let x = CGFloat((index * 37) % 100) / 100 * size.width
                let y = CGFloat((index * 61) % 100) / 100 * size.height
                let w = CGFloat(18 + (index % 9) * 7)
                let opacity = colorScheme == .dark ? 0.055 : 0.08
                let rect = CGRect(x: x, y: y, width: w, height: 1)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 0.5),
                    with: .color(palette.texture.opacity(opacity))
                )
            }

            for index in 0..<65 {
                let x = CGFloat((index * 71) % 100) / 100 * size.width
                let y = CGFloat((index * 29) % 100) / 100 * size.height
                let diameter = CGFloat(1 + (index % 3))
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                    with: .color(palette.texture.opacity(colorScheme == .dark ? 0.12 : 0.14))
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct GouacheHero: View {
    @Environment(\.colorScheme) private var colorScheme
    let metrics: GouacheHomeMetrics
    @Binding var isSearchExpanded: Bool
    @Binding var searchText: String
    let openProfile: () -> Void
    let submitSearch: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            GouacheHeroImage(isLandscape: metrics.isLandscape)
                .frame(height: metrics.heroHeight)
                .accessibilityHidden(true)

            LinearGradient(
                colors: [
                    SableTheme.gouacheBackground(for: colorScheme),
                    SableTheme.gouacheBackground(for: colorScheme).opacity(metrics.isLandscape ? 0.72 : 0.46),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: metrics.isLandscape ? metrics.contentWidth * 0.42 : metrics.contentWidth * 0.56)
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)

            GouacheTopBar(
                searchWidth: metrics.searchWidth,
                isSearchExpanded: $isSearchExpanded,
                searchText: $searchText,
                openProfile: openProfile,
                submitSearch: submitSearch
            )
                .padding(.top, 12)

            Text("Color slowly.\nMake it yours.")
                .font(SableTheme.Typography.fraunces(metrics.titleSize, weight: .regular))
                .foregroundStyle(heroTitleColor)
                .lineSpacing(-5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: metrics.isLandscape ? 500 : 480, alignment: .leading)
                .offset(x: metrics.isLandscape ? 54 : 8, y: metrics.titleTop)
                .shadow(
                    color: SableTheme.Shadow.heroTitle(for: colorScheme).color,
                    radius: SableTheme.Shadow.heroTitle(for: colorScheme).radius,
                    x: SableTheme.Shadow.heroTitle(for: colorScheme).x,
                    y: SableTheme.Shadow.heroTitle(for: colorScheme).y
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.heroHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gouache, Color slowly. Make it yours.")
    }

    private var heroTitleColor: Color {
        colorScheme == .dark ? SableTheme.heroTitleDark : SableTheme.gouachePrimaryText(for: colorScheme)
    }
}

private struct GouacheTopBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let searchWidth: CGFloat
    @Binding var isSearchExpanded: Bool
    @Binding var searchText: String
    let openProfile: () -> Void
    let submitSearch: () -> Void

    var body: some View {
        ZStack {
            Text("Gouache")
                .font(SableTheme.Typography.fraunces(20, weight: .regular))
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: SableTheme.Spacing.md) {
                Spacer()

                SearchPill(
                    width: searchWidth,
                    isExpanded: $isSearchExpanded,
                    text: $searchText,
                    submit: submitSearch
                )

                ProfileAvatarButton(action: openProfile)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 48)
    }
}

private struct GouacheHeroImage: View {
    let isLandscape: Bool

    var body: some View {
        GeometryReader { proxy in
            Image(isLandscape ? "HomeHeroLandscape" : "HomeHeroPortrait")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .allowsHitTesting(false)
        }
    }
}

private struct SearchPill: View {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    let width: CGFloat
    @Binding var isExpanded: Bool
    @Binding var text: String
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(SableTheme.Motion.searchExpand) {
                    isExpanded = true
                }
                isFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            if isExpanded {
                TextField("Search templates, moods, or collections", text: $text)
                    .font(SableTheme.Typography.bodySmall)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit(submit)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
        .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
        .padding(.horizontal, isExpanded ? SableTheme.Spacing.xl : 12)
        .frame(width: isExpanded ? width : 44, height: 44, alignment: .leading)
        .background(searchFill, in: Capsule())
        .overlay {
            Capsule().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
        .shadow(
            color: SableTheme.Shadow.searchPill(for: colorScheme).color,
            radius: SableTheme.Shadow.searchPill(for: colorScheme).radius,
            x: SableTheme.Shadow.searchPill(for: colorScheme).x,
            y: SableTheme.Shadow.searchPill(for: colorScheme).y
        )
        .animation(SableTheme.Motion.searchExpand, value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                isFocused = true
            } else {
                isFocused = false
            }
        }
        .accessibilityLabel("Search templates, moods, or collections")
    }

    private var searchFill: Color {
        colorScheme == .dark ? SableTheme.searchFillDark : SableTheme.searchFillLight
    }
}

private struct ProfileAvatarButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(controlFill)
                    .overlay {
                        Circle().stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                    }

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme).opacity(0.88))
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }

    private var controlFill: Color {
        colorScheme == .dark ? SableTheme.controlFillDark : SableTheme.controlFillLight
    }
}

private struct GouacheHeroIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let palette = GouacheResolvedPalette(scheme: colorScheme)
            drawCoast(in: &context, size: size, palette: palette)
            drawWindow(in: &context, size: size, palette: palette)
            drawTerrace(in: &context, size: size, palette: palette)
            drawPlant(in: &context, size: size, palette: palette)
            drawStillLife(in: &context, size: size, palette: palette)
            drawBirds(in: &context, size: size, palette: palette)
            drawPaperEdge(in: &context, size: size, palette: palette)
        }
    }

    private func drawCoast(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let waterY = h * 0.58

        var sea = Path()
        sea.move(to: CGPoint(x: w * 0.34, y: waterY))
        sea.addCurve(
            to: CGPoint(x: w * 0.86, y: waterY - 14),
            control1: CGPoint(x: w * 0.48, y: waterY - 34),
            control2: CGPoint(x: w * 0.66, y: waterY + 10)
        )
        sea.addLine(to: CGPoint(x: w * 0.86, y: waterY + 60))
        sea.addCurve(
            to: CGPoint(x: w * 0.36, y: waterY + 50),
            control1: CGPoint(x: w * 0.70, y: waterY + 88),
            control2: CGPoint(x: w * 0.52, y: waterY + 64)
        )
        sea.closeSubpath()
        context.fill(sea, with: .color(palette.blueWash.opacity(palette.isDark ? 0.48 : 0.55)))

        for row in 0..<5 {
            var line = Path()
            let y = waterY - 34 + CGFloat(row * 23)
            line.move(to: CGPoint(x: w * 0.28, y: y))
            line.addCurve(
                to: CGPoint(x: w * 0.74, y: y - CGFloat(row % 2) * 7),
                control1: CGPoint(x: w * 0.42, y: y - 28),
                control2: CGPoint(x: w * 0.58, y: y + 20)
            )
            context.stroke(line, with: .color(palette.line.opacity(0.58)), lineWidth: 1)
        }

        for index in 0..<12 {
            let x = w * 0.38 + CGFloat(index % 6) * 28 + CGFloat(index / 6) * 18
            let y = waterY + 18 + CGFloat(index / 6) * 23 - CGFloat(index % 2) * 7
            let building = CGRect(x: x, y: y, width: CGFloat(18 + index % 3 * 8), height: CGFloat(16 + index % 4 * 8))
            context.stroke(Path(roundedRect: building, cornerRadius: 1), with: .color(palette.line.opacity(0.64)), lineWidth: 1)

            var roof = Path()
            roof.move(to: CGPoint(x: building.minX - 2, y: building.minY))
            roof.addLine(to: CGPoint(x: building.midX, y: building.minY - 8))
            roof.addLine(to: CGPoint(x: building.maxX + 2, y: building.minY))
            context.stroke(roof, with: .color(palette.line.opacity(0.64)), lineWidth: 1)
        }

        var railing = Path()
        railing.move(to: CGPoint(x: w * 0.29, y: h * 0.74))
        railing.addLine(to: CGPoint(x: w * 0.78, y: h * 0.61))
        railing.addLine(to: CGPoint(x: w * 0.82, y: h * 0.68))
        railing.addLine(to: CGPoint(x: w * 0.36, y: h * 0.83))
        context.stroke(railing, with: .color(palette.line.opacity(0.75)), lineWidth: 1.4)
    }

    private func drawWindow(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let wall = CGRect(x: w * 0.82, y: 0, width: w * 0.2, height: h * 0.72)
        context.stroke(Path(wall), with: .color(palette.line.opacity(0.26)), lineWidth: 1)

        let shutter = CGRect(x: w * 0.86, y: -6, width: w * 0.045, height: h * 0.48)
        context.fill(Path(shutter), with: .color(palette.shutter.opacity(palette.isDark ? 0.62 : 0.78)))
        context.stroke(Path(shutter), with: .color(palette.line.opacity(0.7)), lineWidth: 1)

        for index in 0..<6 {
            let x = shutter.minX + CGFloat(index + 1) * shutter.width / 7
            var line = Path()
            line.move(to: CGPoint(x: x, y: shutter.minY + 12))
            line.addLine(to: CGPoint(x: x + 4, y: shutter.maxY - 10))
            context.stroke(line, with: .color(palette.line.opacity(0.25)), lineWidth: 1)
        }

        let window = CGRect(x: w * 0.91, y: -14, width: w * 0.09, height: h * 0.5)
        context.stroke(Path(window), with: .color(palette.line.opacity(0.64)), lineWidth: 1.2)

        let plaster = CGRect(x: w * 0.78, y: h * 0.45, width: w * 0.24, height: h * 0.25)
        context.fill(Path(plaster), with: .color(palette.orangeWash.opacity(palette.isDark ? 0.85 : 0.78)))
        context.stroke(Path(plaster), with: .color(palette.line.opacity(0.36)), lineWidth: 1)
    }

    private func drawTerrace(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        var table = Path()
        table.move(to: CGPoint(x: w * 0.37, y: h * 0.79))
        table.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.77),
            control1: CGPoint(x: w * 0.54, y: h * 0.70),
            control2: CGPoint(x: w * 0.75, y: h * 0.73)
        )
        table.addLine(to: CGPoint(x: w, y: h * 0.96))
        table.addCurve(
            to: CGPoint(x: w * 0.31, y: h * 0.95),
            control1: CGPoint(x: w * 0.76, y: h * 1.04),
            control2: CGPoint(x: w * 0.49, y: h * 1.00)
        )
        table.closeSubpath()
        context.fill(table, with: .color(palette.paper.opacity(palette.isDark ? 0.36 : 0.48)))
        context.stroke(table, with: .color(palette.line.opacity(0.72)), lineWidth: 1.2)

        for index in 0..<7 {
            var plank = Path()
            let y = h * (0.80 + CGFloat(index) * 0.025)
            plank.move(to: CGPoint(x: w * 0.34, y: y))
            plank.addLine(to: CGPoint(x: w * 0.97, y: y - CGFloat(index) * 3))
            context.stroke(plank, with: .color(palette.line.opacity(0.22)), lineWidth: 1)
        }
    }

    private func drawPlant(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let base = CGPoint(x: w * 0.70, y: h * 0.66)

        let vase = CGRect(x: base.x - 42, y: base.y - 12, width: 84, height: 120)
        context.fill(Path(ellipseIn: CGRect(x: vase.minX + 4, y: vase.minY, width: vase.width - 8, height: 18)), with: .color(palette.paper.opacity(0.9)))
        context.stroke(Path(ellipseIn: CGRect(x: vase.minX + 4, y: vase.minY, width: vase.width - 8, height: 18)), with: .color(palette.line.opacity(0.7)), lineWidth: 1)
        context.fill(Path(roundedRect: vase, cornerRadius: 34), with: .color(palette.paper.opacity(0.64)))
        context.stroke(Path(roundedRect: vase, cornerRadius: 34), with: .color(palette.line.opacity(0.76)), lineWidth: 1.2)

        for index in 0..<20 {
            let angle = CGFloat(index) * .pi / 10 - .pi * 0.95
            let length = CGFloat(84 + (index % 5) * 19)
            let end = CGPoint(x: base.x + cos(angle) * length, y: base.y + sin(angle) * length)
            var stem = Path()
            stem.move(to: CGPoint(x: base.x, y: base.y + 6))
            stem.addQuadCurve(to: end, control: CGPoint(x: (base.x + end.x) / 2 + CGFloat(index % 3 - 1) * 18, y: base.y - length * 0.48))
            context.stroke(stem, with: .color(palette.line.opacity(0.64)), lineWidth: 1)

            let leafRect = CGRect(x: end.x - 13, y: end.y - 7, width: 26, height: 14)
            var leafContext = context
            leafContext.translateBy(x: end.x, y: end.y)
            leafContext.rotate(by: .radians(Double(angle + .pi / 2)))
            leafContext.fill(
                Path(ellipseIn: CGRect(x: -13, y: -7, width: 26, height: 14)),
                with: .color(palette.leaf.opacity(0.76))
            )
            leafContext.stroke(
                Path(ellipseIn: CGRect(x: -13, y: -7, width: 26, height: 14)),
                with: .color(palette.line.opacity(0.36)),
                lineWidth: 0.8
            )

            if index % 4 == 0 {
                context.stroke(Path(ellipseIn: leafRect), with: .color(palette.line.opacity(0.18)), lineWidth: 0.6)
            }
        }
    }

    private func drawStillLife(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height

        let plate = CGRect(x: w * 0.74, y: h * 0.72, width: w * 0.17, height: h * 0.075)
        context.fill(Path(ellipseIn: plate), with: .color(palette.paper.opacity(0.72)))
        context.stroke(Path(ellipseIn: plate), with: .color(palette.line.opacity(0.75)), lineWidth: 1.1)

        let cup = CGRect(x: w * 0.57, y: h * 0.72, width: 58, height: 48)
        context.fill(Path(roundedRect: cup, cornerRadius: 11), with: .color(palette.paper.opacity(0.74)))
        context.stroke(Path(roundedRect: cup, cornerRadius: 11), with: .color(palette.line.opacity(0.7)), lineWidth: 1)
        context.stroke(Path(ellipseIn: CGRect(x: cup.maxX - 3, y: cup.minY + 13, width: 22, height: 22)), with: .color(palette.line.opacity(0.58)), lineWidth: 1)

        let oranges = [
            CGRect(x: w * 0.765, y: h * 0.66, width: 62, height: 58),
            CGRect(x: w * 0.813, y: h * 0.675, width: 74, height: 58),
            CGRect(x: w * 0.785, y: h * 0.695, width: 62, height: 45)
        ]

        for (index, rect) in oranges.enumerated() {
            context.fill(Path(ellipseIn: rect), with: .color(palette.orange.opacity(0.95)))
            context.stroke(Path(ellipseIn: rect), with: .color(palette.line.opacity(0.65)), lineWidth: 1)

            if index > 0 {
                var slice = Path()
                let center = CGPoint(x: rect.midX, y: rect.midY)
                for spoke in 0..<8 {
                    slice.move(to: center)
                    let a = CGFloat(spoke) * .pi / 4
                    slice.addLine(to: CGPoint(x: center.x + cos(a) * rect.width * 0.38, y: center.y + sin(a) * rect.height * 0.38))
                }
                context.stroke(slice, with: .color(Color.white.opacity(0.58)), lineWidth: 1)
                context.stroke(Path(ellipseIn: rect.insetBy(dx: 8, dy: 7)), with: .color(Color.white.opacity(0.58)), lineWidth: 1)
            }
        }
    }

    private func drawBirds(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        for index in 0..<10 {
            let x = w * 0.36 + CGFloat(index % 5) * 58 + CGFloat(index / 5) * 25
            let y = h * 0.20 + CGFloat(index / 5) * 34 + CGFloat(index % 3) * 7
            var bird = Path()
            bird.move(to: CGPoint(x: x, y: y))
            bird.addQuadCurve(to: CGPoint(x: x + 12, y: y), control: CGPoint(x: x + 6, y: y - 7))
            bird.move(to: CGPoint(x: x + 12, y: y))
            bird.addQuadCurve(to: CGPoint(x: x + 24, y: y), control: CGPoint(x: x + 18, y: y - 7))
            context.stroke(bird, with: .color(palette.line.opacity(0.55)), lineWidth: 1)
        }
    }

    private func drawPaperEdge(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        var edge = Path()
        edge.move(to: CGPoint(x: -10, y: size.height * 0.72))
        for step in 0...16 {
            let x = CGFloat(step) / 16 * size.width * 0.55
            let y = size.height * (0.72 + sin(CGFloat(step) * 0.8) * 0.014)
            edge.addLine(to: CGPoint(x: x, y: y))
        }
        context.stroke(edge, with: .color(palette.line.opacity(0.18)), lineWidth: 1)
    }
}

private struct ContinueSection: View {
    let pages: [ColoringPage]
    let metrics: GouacheHomeMetrics
    let seeAll: () -> Void
    let navigate: (ColoringPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sectionHeaderSpacing) {
            HomeSectionHeader(title: "Continue Coloring", seeAll: seeAll)

            if pages.isEmpty {
                ContinueEmptyCard(width: metrics.contentWidth)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: metrics.cardGap) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { _, page in
                            ContinueCard(
                                page: page,
                                imageHeight: metrics.continueImageHeight,
                                footerHeight: metrics.continueFooterHeight,
                                width: metrics.continueCardWidth
                            ) {
                                navigate(page)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct ContinueEmptyCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let width: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "paintpalette")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                .frame(width: 42, height: 42)
                .background(SableTheme.gouachePanel(for: colorScheme), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("No saved colorings yet")
                    .font(SableTheme.Typography.fraunces(18, weight: .regular))
                    .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Choose a template below to start.")
                    .font(SableTheme.Typography.labelMedium)
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SableTheme.Spacing.xl)
        .frame(width: width, height: 82)
        .background(SableTheme.gouachePanel(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCard, style: .continuous)
                .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
        }
        .accessibilityIdentifier("home.continue.empty")
    }
}

private struct ContinueCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: ColoringPage
    let imageHeight: CGFloat
    let footerHeight: CGFloat
    let width: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HomeArtworkImage(assetName: page.homeArtworkAssetName) {
                    ProjectArtworkThumbnail(page: page, style: .wide)
                }
                    .frame(width: width, height: imageHeight)
                    .clipped()

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(page.title)
                            .font(SableTheme.Typography.fraunces(14, weight: .regular))
                            .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 8)

                        Text(progressText)
                            .font(SableTheme.Typography.labelMedium)
                            .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                    }

                    ProgressTrack(progress: page.progress)
                }
                .padding(.horizontal, SableTheme.Spacing.lg)
                .frame(height: footerHeight)
                .background(cardFooter)
            }
            .frame(width: width, height: imageHeight + footerHeight)
            .background(SableTheme.gouachePanel(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCard, style: .continuous)
                    .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(
                color: SableTheme.Shadow.card(for: colorScheme).color,
                radius: SableTheme.Shadow.card(for: colorScheme).radius,
                x: SableTheme.Shadow.card(for: colorScheme).x,
                y: SableTheme.Shadow.card(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(page.title), \(progressText) complete")
        .accessibilityIdentifier("home.continue.\(page.title.normalizedIdentifier)")
    }

    private var cardFooter: Color {
        colorScheme == .dark ? SableTheme.cardFooterDark : SableTheme.cardFooterLight
    }

    private var progressText: String {
        "\(Int((page.progress * 100).rounded()))%"
    }
}

private struct MoodSection: View {
    let metrics: GouacheHomeMetrics
    let navigate: (GouacheMoodTile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sectionHeaderSpacing) {
            HomeSectionHeader(title: "Browse by Mood")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: metrics.cardGap) {
                    ForEach(Array(GouacheMoodTile.allCases.enumerated()), id: \.element.id) { index, mood in
                        MoodCard(
                            mood: mood,
                            width: metrics.moodCardWidth,
                            height: metrics.moodCardHeight,
                            showsTitle: metrics.isLandscape || index < 3
                        ) {
                            navigate(mood)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct MoodCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let mood: GouacheMoodTile
    let width: CGFloat
    let height: CGFloat
    let showsTitle: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                Image(mood.homeMoodAssetName)
                    .resizable()
                    .scaledToFill()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(mood.title == "Bold" ? 0.34 : 0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if showsTitle {
                    VStack {
                        Spacer(minLength: 0)

                        HStack {
                            Text(mood.title)
                                .font(SableTheme.Typography.fraunces(width < 190 ? 19 : 23, weight: .regular))
                                .foregroundStyle(SableTheme.heroTitleDark)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.leading, 18)
                                .padding(.trailing, 12)
                                .padding(.vertical, 7)
                                .background(Color.black.opacity(0.42), in: Capsule())
                                .shadow(color: .black.opacity(0.34), radius: 4)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, SableTheme.Spacing.xl)
                        .padding(.bottom, 10)
                    }
                    .frame(width: width, height: height, alignment: .bottomLeading)
                }
            }
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCard, style: .continuous)
                    .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(
                color: SableTheme.Shadow.cardSmall(for: colorScheme).color,
                radius: SableTheme.Shadow.cardSmall(for: colorScheme).radius,
                x: SableTheme.Shadow.cardSmall(for: colorScheme).x,
                y: SableTheme.Shadow.cardSmall(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.title)
        .accessibilityIdentifier("home.mood.\(mood.title.normalizedIdentifier)")
    }
}

private struct MoodArtworkCanvas: View {
    let mood: GouacheMoodTile

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#F1E7D4")))

            switch mood.title {
            case "Calm":
                drawCalm(in: &context, size: size)
            case "Bold":
                drawBold(in: &context, size: size)
            case "Dreamy":
                drawDreamy(in: &context, size: size)
            default:
                drawFocus(in: &context, size: size)
            }

            drawPaperGrain(in: &context, size: size)
        }
    }

    private func drawCalm(in context: inout GraphicsContext, size: CGSize) {
        drawBrush(
            CGRect(x: -size.width * 0.04, y: size.height * 0.02, width: size.width * 0.58, height: size.height * 1.08),
            color: SableTheme.MoodWashes.calm[0].opacity(0.46),
            angle: -2,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.30, y: -size.height * 0.12, width: size.width * 0.48, height: size.height * 0.92),
            color: SableTheme.MoodWashes.calm[1].opacity(0.48),
            angle: 14,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.52, y: size.height * 0.02, width: size.width * 0.52, height: size.height * 1.02),
            color: SableTheme.MoodWashes.calm[2].opacity(0.64),
            angle: -8,
            in: &context
        )
    }

    private func drawBold(in context: inout GraphicsContext, size: CGSize) {
        drawBrush(
            CGRect(x: -size.width * 0.08, y: -size.height * 0.12, width: size.width * 0.46, height: size.height * 1.34),
            color: SableTheme.MoodWashes.bold[0].opacity(0.94),
            angle: -7,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.14, y: size.height * 0.04, width: size.width * 0.52, height: size.height * 0.98),
            color: SableTheme.MoodWashes.bold[1].opacity(0.88),
            angle: 13,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.34, y: size.height * 0.48, width: size.width * 0.58, height: size.height * 0.36),
            color: SableTheme.MoodWashes.bold[2].opacity(0.84),
            angle: -2,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.74, y: -size.height * 0.08, width: size.width * 0.24, height: size.height * 1.15),
            color: SableTheme.MoodWashes.bold[3].opacity(0.62),
            angle: 5,
            in: &context
        )
    }

    private func drawDreamy(in context: inout GraphicsContext, size: CGSize) {
        drawWash(center: CGPoint(x: size.width * 0.18, y: size.height * 0.44), radius: size.width * 0.43, color: SableTheme.MoodWashes.dreamy[0].opacity(0.56), in: &context)
        drawWash(center: CGPoint(x: size.width * 0.58, y: size.height * 0.24), radius: size.width * 0.42, color: SableTheme.MoodWashes.dreamy[1].opacity(0.42), in: &context)
        drawWash(center: CGPoint(x: size.width * 0.72, y: size.height * 0.62), radius: size.width * 0.40, color: SableTheme.MoodWashes.dreamy[2].opacity(0.42), in: &context)
        drawWash(center: CGPoint(x: size.width * 0.44, y: size.height * 0.52), radius: size.width * 0.46, color: SableTheme.MoodWashes.dreamy[3].opacity(0.38), in: &context)
    }

    private func drawFocus(in context: inout GraphicsContext, size: CGSize) {
        drawBrush(
            CGRect(x: -size.width * 0.05, y: -size.height * 0.12, width: size.width * 0.45, height: size.height * 1.24),
            color: SableTheme.MoodWashes.focus[0].opacity(0.70),
            angle: -7,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.26, y: size.height * 0.04, width: size.width * 0.40, height: size.height * 0.96),
            color: SableTheme.MoodWashes.focus[1].opacity(0.76),
            angle: 13,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.60, y: -size.height * 0.10, width: size.width * 0.48, height: size.height * 1.24),
            color: SableTheme.MoodWashes.focus[2].opacity(0.78),
            angle: -9,
            in: &context
        )
        drawBrush(
            CGRect(x: size.width * 0.68, y: size.height * 0.55, width: size.width * 0.42, height: size.height * 0.40),
            color: SableTheme.MoodWashes.focus[3].opacity(0.55),
            angle: 5,
            in: &context
        )
    }

    private func drawBrush(
        _ rect: CGRect,
        color: Color,
        angle: Double,
        in context: inout GraphicsContext
    ) {
        var local = context
        local.rotate(by: .degrees(angle))
        local.fill(Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.18), with: .color(color))

        for index in 0..<8 {
            let y = rect.minY + rect.height * CGFloat(index + 1) / 9
            var streak = Path()
            streak.move(to: CGPoint(x: rect.minX + rect.width * 0.05, y: y))
            streak.addLine(to: CGPoint(x: rect.maxX - rect.width * CGFloat(index % 3) * 0.08, y: y + sin(CGFloat(index)) * 4))
            local.stroke(streak, with: .color(Color.white.opacity(0.12)), lineWidth: CGFloat(1 + index % 3))
        }
    }

    private func drawWash(
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        in context: inout GraphicsContext
    ) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius * 0.62, width: radius * 2, height: radius * 1.24)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func drawPaperGrain(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<42 {
            let x = CGFloat((index * 43) % 100) / 100 * size.width
            let y = CGFloat((index * 67) % 100) / 100 * size.height
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: CGFloat(1 + index % 3), height: CGFloat(1 + index % 2))),
                with: .color(Color.black.opacity(0.045))
            )
        }

        for index in 0..<5 {
            var line = Path()
            let y = size.height * CGFloat(index + 1) / 6
            line.move(to: CGPoint(x: size.width * 0.08, y: y))
            for step in 0...5 {
                line.addLine(
                    to: CGPoint(
                        x: size.width * CGFloat(step) / 5,
                        y: y + sin(CGFloat(index + step) * 1.2) * 9
                    )
                )
            }
            context.stroke(line, with: .color(Color.black.opacity(0.18)), lineWidth: 0.8)
        }
    }
}

private struct FeaturedCollectionsSection: View {
    let collections: [PageCollection]
    let metrics: GouacheHomeMetrics
    let seeAll: () -> Void
    let navigate: (PageCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sectionHeaderSpacing) {
            HomeSectionHeader(title: "Featured Collections", seeAll: seeAll)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: metrics.cardGap) {
                    ForEach(Array(collections.prefix(4).enumerated()), id: \.element.id) { index, collection in
                        CollectionCard(
                            collection: collection,
                            index: index,
                            width: metrics.collectionCardWidth,
                            height: metrics.collectionCardHeight
                        ) {
                            navigate(collection)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct CollectionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let collection: PageCollection
    let index: Int
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                HomeArtworkImage(assetName: collection.homeArtworkAssetName) {
                    PlaceholderArtwork(tint: tint, seed: collection.name, style: .compact)
                }

                LinearGradient(
                    colors: overlayColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )

                collectionLabelPanel
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCollection, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SableTheme.Radius.continuousCollection, style: .continuous)
                    .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
            }
            .shadow(
                color: SableTheme.Shadow.cardMedium(for: colorScheme).color,
                radius: SableTheme.Shadow.cardMedium(for: colorScheme).radius,
                x: SableTheme.Shadow.cardMedium(for: colorScheme).x,
                y: SableTheme.Shadow.cardMedium(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(collection.name), \(displayDifficulty)")
        .accessibilityIdentifier("home.collection.\(collection.name.normalizedIdentifier)")
    }

    private var collectionLabelPanel: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(collection.name)
                    .font(SableTheme.Typography.fraunces(width < 260 ? 17 : 21, weight: .regular))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.64)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 10)

                HStack(spacing: 9) {
                    chip(displayDifficulty)
                }
            }
            .padding(.leading, SableTheme.Spacing.lg)
            .padding(.trailing, 8)
            .padding(.vertical, 15)
            .frame(width: width < 260 ? width * 0.72 : width * 0.58, height: height, alignment: .leading)
            .background(collectionPanelFill)

            Spacer(minLength: 0)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(SableTheme.Typography.chip)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(chipForeground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(chipFill, in: Capsule())
    }

    private var tint: Color {
        SableTheme.CollectionTints.forIndex(index)
    }

    private var overlayColors: [Color] {
        let leading = colorScheme == .dark ? Color.black.opacity(0.48) : tint.opacity(0.62)
        return [leading, leading.opacity(0.62), .clear]
    }

    private var collectionPanelFill: Color {
        if colorScheme == .dark {
            return SableTheme.collectionPanelDark.opacity(index == 2 ? 0.30 : 0.72)
        }

        switch index {
        case 0:
            return SableTheme.collectionPanelSageLight
        case 1:
            return SableTheme.collectionPanelBlushLight
        case 2:
            return SableTheme.collectionPanelGoldLight
        default:
            return SableTheme.collectionPanelTealLight
        }
    }

    private var titleColor: Color {
        index == 2 && colorScheme == .light ? Color(hex: "#2D261E") : SableTheme.gouachePrimaryText(for: colorScheme)
    }

    private var chipFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.72)
    }

    private var chipForeground: Color {
        colorScheme == .dark ? SableTheme.chipForegroundDark : SableTheme.chipForegroundLight
    }

    private var displayDifficulty: String {
        switch collection.name {
        case "Sunlit Places", "Quiet Rooms":
            return "Medium"
        default:
            return "Easy"
        }
    }
}

private struct RecentlyAddedSection: View {
    let pages: [ColoringPage]
    let metrics: GouacheHomeMetrics
    let seeAll: () -> Void
    let navigate: (ColoringPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sectionHeaderSpacing) {
            HomeSectionHeader(title: "Recently Added", seeAll: seeAll)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: metrics.cardGap) {
                    ForEach(pages) { page in
                        RecentlyAddedCard(
                            page: page,
                            width: metrics.recentCardWidth,
                            height: metrics.recentCardHeight
                        ) {
                            navigate(page)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct RecentlyAddedCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: ColoringPage
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HomeArtworkImage(assetName: page.homeArtworkAssetName) {
                ProjectArtworkThumbnail(page: page, style: .compact)
            }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SableTheme.Radius.card, style: .continuous)
                        .stroke(SableTheme.gouacheHairline(for: colorScheme), lineWidth: SableTheme.Border.hairlineWidth)
                }
                .shadow(
                    color: SableTheme.Shadow.cardSmall(for: colorScheme).color,
                    radius: SableTheme.Shadow.cardSmall(for: colorScheme).radius,
                    x: SableTheme.Shadow.cardSmall(for: colorScheme).x,
                    y: SableTheme.Shadow.cardSmall(for: colorScheme).y
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.title)
        .accessibilityIdentifier("home.recent.\(page.title.normalizedIdentifier)")
    }
}

private struct HomeArtworkImage<Fallback: View>: View {
    let assetName: String?
    let fallback: Fallback

    init(
        assetName: String?,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.assetName = assetName
        self.fallback = fallback()
    }

    var body: some View {
        ZStack {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .clipped()
    }
}

private struct HomeSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var seeAll: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(SableTheme.Typography.sectionHeader)
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

            Spacer()

            if let seeAll {
                Button(action: seeAll) {
                    HStack(spacing: SableTheme.Spacing.xxs) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                            .font(SableTheme.Typography.labelLarge)
                    }
                    .font(SableTheme.Typography.bodyMedium)
                    .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct ProgressTrack: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackFill)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [SableTheme.progressGradientStart, SableTheme.progressGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
    }

    private var trackFill: Color {
        SableTheme.gouacheHairline(for: colorScheme).opacity(0.3)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let palette = GouacheResolvedPalette(scheme: colorScheme)
            drawPaper(in: &context, size: size, palette: palette)
            drawArtwork(in: &context, size: size, palette: palette)
        }
    }

    private func drawPaper(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let base = style == .mood ? tint.opacity(0.24) : palette.paper
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))

        for index in 0..<55 {
            let x = CGFloat((index * 47 + seed.count * 13) % 100) / 100 * size.width
            let y = CGFloat((index * 29 + seed.count * 17) % 100) / 100 * size.height
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: CGFloat(1 + index % 3), height: CGFloat(1 + index % 2))),
                with: .color(palette.line.opacity(palette.isDark ? 0.09 : 0.06))
            )
        }
    }

    private func drawArtwork(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        switch subject {
        case .wildflowers:
            drawWildflowers(in: &context, size: size, palette: palette)
        case .coast:
            drawCoastalTown(in: &context, size: size, palette: palette)
        case .interior:
            drawInterior(in: &context, size: size, palette: palette)
        case .lemons:
            drawLemons(in: &context, size: size, palette: palette)
        case .window:
            drawWindowCard(in: &context, size: size, palette: palette)
        case .abstract:
            drawAbstract(in: &context, size: size, palette: palette)
        case .stillLife:
            drawStillLifeCard(in: &context, size: size, palette: palette)
        case .door:
            drawDoor(in: &context, size: size, palette: palette)
        }
    }

    private var subject: GouacheArtworkSubject {
        let key = seed.lowercased()
        if key.contains("wildflower") || key.contains("florist") {
            return .wildflowers
        }
        if key.contains("sunday") || key.contains("quiet") || key.contains("library") || key.contains("kitchen") {
            return .interior
        }
        if key.contains("lemon") {
            return .lemons
        }
        if key.contains("amalfi") || key.contains("mediterranean") || key.contains("balcony") {
            return .coast
        }
        if key.contains("window") {
            return .door
        }
        if key.contains("toucan") || key.contains("canopy") {
            return .stillLife
        }
        if style == .mood || key.contains("calm") || key.contains("bold") || key.contains("dreamy") || key.contains("focus") {
            return .abstract
        }
        return .wildflowers
    }

    private func drawWildflowers(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let vase = CGRect(x: w * 0.30, y: h * 0.52, width: w * 0.24, height: h * 0.38)
        context.stroke(Path(roundedRect: vase, cornerRadius: min(w, h) * 0.08), with: .color(palette.line.opacity(0.74)), lineWidth: 1.2)

        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 7 - .pi * 0.92
            let start = CGPoint(x: vase.midX, y: vase.minY + 12)
            let end = CGPoint(x: start.x + cos(angle) * w * CGFloat(0.16 + Double(index % 3) * 0.035), y: start.y + sin(angle) * h * CGFloat(0.42 + Double(index % 2) * 0.08))
            var stem = Path()
            stem.move(to: start)
            stem.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: end.y + h * 0.22))
            context.stroke(stem, with: .color(palette.line.opacity(0.62)), lineWidth: 1)

            if index.isMultiple(of: 2) {
                drawFlower(center: end, radius: min(w, h) * 0.035, in: &context, palette: palette)
            } else {
                let leaf = CGRect(x: end.x - 10, y: end.y - 5, width: 20, height: 10)
                context.fill(Path(ellipseIn: leaf), with: .color(palette.leaf.opacity(0.68)))
                context.stroke(Path(ellipseIn: leaf), with: .color(palette.line.opacity(0.36)), lineWidth: 0.8)
            }
        }
    }

    private func drawFlower(center: CGPoint, radius: CGFloat, in context: inout GraphicsContext, palette: GouacheResolvedPalette) {
        for index in 0..<6 {
            var flowerContext = context
            flowerContext.translateBy(x: center.x, y: center.y)
            flowerContext.rotate(by: .degrees(Double(index) * 60))
            flowerContext.fill(
                Path(ellipseIn: CGRect(x: radius * 0.4, y: -radius * 0.52, width: radius * 1.65, height: radius)),
                with: .color(Color(hex: "#EFA28F").opacity(0.72))
            )
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.32, y: center.y - radius * 0.32, width: radius * 0.64, height: radius * 0.64)), with: .color(Color(hex: "#D58D58")))
    }

    private func drawCoastalTown(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height

        var sea = Path()
        sea.move(to: CGPoint(x: w * 0.30, y: h * 0.52))
        sea.addCurve(to: CGPoint(x: w, y: h * 0.45), control1: CGPoint(x: w * 0.46, y: h * 0.38), control2: CGPoint(x: w * 0.75, y: h * 0.58))
        sea.addLine(to: CGPoint(x: w, y: h))
        sea.addLine(to: CGPoint(x: w * 0.56, y: h))
        sea.closeSubpath()
        context.fill(sea, with: .color(palette.blueWash.opacity(0.62)))

        for index in 0..<12 {
            let row = index / 4
            let col = index % 4
            let rect = CGRect(
                x: w * 0.07 + CGFloat(col) * w * 0.11 + CGFloat(row) * w * 0.04,
                y: h * 0.30 + CGFloat(row) * h * 0.13 - CGFloat(col % 2) * 6,
                width: w * 0.10,
                height: h * 0.14
            )
            let fill = index.isMultiple(of: 3) ? Color(hex: "#E8A23D").opacity(0.45) : palette.paper.opacity(0.62)
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(fill))
            context.stroke(Path(roundedRect: rect, cornerRadius: 2), with: .color(palette.line.opacity(0.62)), lineWidth: 0.9)
        }

        drawSketchLines(in: &context, size: size, palette: palette)
    }

    private func drawInterior(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        context.stroke(Path(CGRect(x: w * 0.35, y: h * 0.10, width: w * 0.28, height: h * 0.28)), with: .color(palette.line.opacity(0.42)), lineWidth: 1)

        let chair = CGRect(x: w * 0.43, y: h * 0.46, width: w * 0.28, height: h * 0.32)
        context.fill(Path(roundedRect: chair, cornerRadius: h * 0.05), with: .color(palette.leaf.opacity(0.74)))
        context.stroke(Path(roundedRect: chair, cornerRadius: h * 0.05), with: .color(palette.line.opacity(0.7)), lineWidth: 1)

        let cushion = CGRect(x: chair.minX + w * 0.08, y: chair.minY + h * 0.04, width: w * 0.17, height: h * 0.16)
        context.fill(Path(roundedRect: cushion, cornerRadius: h * 0.03), with: .color(palette.paper.opacity(0.76)))
        context.stroke(Path(roundedRect: cushion, cornerRadius: h * 0.03), with: .color(palette.line.opacity(0.38)), lineWidth: 0.8)

        let pot = CGRect(x: w * 0.16, y: h * 0.55, width: w * 0.10, height: h * 0.20)
        context.fill(Path(roundedRect: pot, cornerRadius: 4), with: .color(Color(hex: "#C78E63").opacity(0.45)))
        context.stroke(Path(roundedRect: pot, cornerRadius: 4), with: .color(palette.line.opacity(0.58)), lineWidth: 0.8)

        for index in 0..<6 {
            var leaf = Path()
            leaf.move(to: CGPoint(x: pot.midX, y: pot.minY))
            leaf.addLine(to: CGPoint(x: pot.midX + CGFloat(index - 3) * w * 0.035, y: h * CGFloat(0.18 + Double(index % 2) * 0.08)))
            context.stroke(leaf, with: .color(palette.leaf.opacity(0.82)), lineWidth: 2)
        }
    }

    private func drawLemons(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        for index in 0..<9 {
            let start = CGPoint(x: w * 0.10 + CGFloat(index % 3) * w * 0.12, y: h * 0.08)
            let end = CGPoint(x: w * 0.42 + CGFloat(index) * w * 0.055, y: h * CGFloat(0.25 + Double(index % 4) * 0.12))
            var branch = Path()
            branch.move(to: start)
            branch.addQuadCurve(to: end, control: CGPoint(x: w * 0.48, y: h * 0.08 + CGFloat(index % 2) * 22))
            context.stroke(branch, with: .color(palette.line.opacity(0.58)), lineWidth: 1)

            let lemonRect = CGRect(x: end.x - w * 0.05, y: end.y - h * 0.045, width: w * 0.10, height: h * 0.09)
            if index.isMultiple(of: 2) {
                context.fill(Path(ellipseIn: lemonRect), with: .color(Color(hex: "#E2B64A").opacity(0.78)))
                context.stroke(Path(ellipseIn: lemonRect), with: .color(palette.line.opacity(0.58)), lineWidth: 1)
            } else {
                context.fill(Path(ellipseIn: lemonRect.insetBy(dx: 5, dy: 2)), with: .color(palette.leaf.opacity(0.64)))
            }
        }
    }

    private func drawWindowCard(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let window = CGRect(x: w * 0.55, y: h * 0.10, width: w * 0.24, height: h * 0.46)
        context.fill(Path(window), with: .color(palette.blueWash.opacity(0.38)))
        context.stroke(Path(window), with: .color(palette.line.opacity(0.7)), lineWidth: 1)
        context.stroke(Path(CGRect(x: window.midX, y: window.minY, width: 1, height: window.height)), with: .color(palette.line.opacity(0.42)), lineWidth: 1)

        var vine = Path()
        vine.move(to: CGPoint(x: w * 0.18, y: h * 0.88))
        vine.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.58), control1: CGPoint(x: w * 0.32, y: h * 0.48), control2: CGPoint(x: w * 0.68, y: h * 0.86))
        context.stroke(vine, with: .color(palette.line.opacity(0.5)), lineWidth: 1)

        for index in 0..<10 {
            let p = CGPoint(x: w * CGFloat(0.18 + Double(index) * 0.07), y: h * CGFloat(0.78 - Double(index % 3) * 0.08))
            context.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: w * 0.05, height: h * 0.045)), with: .color(index.isMultiple(of: 2) ? palette.orange.opacity(0.64) : palette.leaf.opacity(0.64)))
        }
    }

    private func drawStillLifeCard(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let perch = CGRect(x: w * 0.32, y: h * 0.18, width: w * 0.16, height: h * 0.58)
        context.fill(Path(roundedRect: perch, cornerRadius: w * 0.05), with: .color(palette.leaf.opacity(0.52)))
        context.stroke(Path(roundedRect: perch, cornerRadius: w * 0.05), with: .color(palette.line.opacity(0.62)), lineWidth: 1)

        for index in 0..<4 {
            let rect = CGRect(x: w * CGFloat(0.46 + Double(index) * 0.08), y: h * CGFloat(0.62 + Double(index % 2) * 0.06), width: w * 0.12, height: h * 0.12)
            context.fill(Path(ellipseIn: rect), with: .color(palette.orange.opacity(0.78)))
            context.stroke(Path(ellipseIn: rect), with: .color(palette.line.opacity(0.5)), lineWidth: 1)
        }

        drawSketchLines(in: &context, size: size, palette: palette)
    }

    private func drawDoor(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let door = CGRect(x: w * 0.42, y: h * 0.17, width: w * 0.28, height: h * 0.72)
        context.fill(Path(roundedRect: door, cornerRadius: w * 0.09), with: .color(palette.leaf.opacity(0.58)))
        context.stroke(Path(roundedRect: door, cornerRadius: w * 0.09), with: .color(palette.line.opacity(0.64)), lineWidth: 1.2)

        for index in 0..<9 {
            let p = CGPoint(x: w * CGFloat(0.12 + Double(index % 3) * 0.10), y: h * CGFloat(0.58 + Double(index / 3) * 0.10))
            drawFlower(center: p, radius: min(w, h) * 0.035, in: &context, palette: palette)
        }
    }

    private func drawAbstract(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        let w = size.width
        let h = size.height
        let swatches: [(Color, CGRect, Double)] = [
            (tint.opacity(0.62), CGRect(x: -w * 0.04, y: h * 0.04, width: w * 0.52, height: h * 0.95), -8),
            (palette.blueWash.opacity(0.54), CGRect(x: w * 0.38, y: -h * 0.08, width: w * 0.55, height: h * 0.78), 12),
            (palette.orange.opacity(0.48), CGRect(x: w * 0.18, y: h * 0.46, width: w * 0.70, height: h * 0.42), -2),
            (palette.leaf.opacity(0.44), CGRect(x: w * 0.66, y: h * 0.18, width: w * 0.34, height: h * 0.88), 16)
        ]

        for (color, rect, angle) in swatches {
            var local = context
            local.rotate(by: .degrees(angle))
            local.fill(Path(roundedRect: rect, cornerRadius: 18), with: .color(color))
        }

        drawSketchLines(in: &context, size: size, palette: palette)
    }

    private func drawSketchLines(in context: inout GraphicsContext, size: CGSize, palette: GouacheResolvedPalette) {
        for index in 0..<7 {
            var path = Path()
            let y = size.height * CGFloat(index + 1) / 8
            path.move(to: CGPoint(x: -10, y: y))
            for step in 0...7 {
                let x = size.width * CGFloat(step) / 7
                path.addLine(to: CGPoint(x: x, y: y + sin(CGFloat(step + index) * 1.3) * 9))
            }
            context.stroke(path, with: .color(palette.line.opacity(0.27)), lineWidth: 0.9)
        }
    }
}

private enum GouacheArtworkSubject {
    case wildflowers
    case coast
    case interior
    case lemons
    case window
    case abstract
    case stillLife
    case door
}

private struct GouacheMoodTile: Identifiable, CaseIterable {
    let title: String
    let tint: Color
    let routeMood: MoodCategory

    var id: String { title }

    static let allCases: [GouacheMoodTile] = [
        GouacheMoodTile(title: "Calm", tint: Color(hex: "#E9D2A6"), routeMood: .calm),
        GouacheMoodTile(title: "Bold", tint: Color(hex: "#122439"), routeMood: .bold),
        GouacheMoodTile(title: "Dreamy", tint: Color(hex: "#E9A1A0"), routeMood: .dreamy),
        GouacheMoodTile(title: "Focus", tint: Color(hex: "#6E7B58"), routeMood: .noir)
    ]

    var homeMoodAssetName: String {
        switch title {
        case "Calm":
            return "HomeMoodCalm"
        case "Bold":
            return "HomeMoodBold"
        case "Dreamy":
            return "HomeMoodDreamy"
        default:
            return "HomeMoodFocus"
        }
    }

    var titleColor: Color {
        switch title {
        case "Bold":
            return Color(hex: "#FFF4E4")
        default:
            return Color(hex: "#2C2926")
        }
    }
}

private struct GouacheResolvedPalette {
    let scheme: ColorScheme

    var isDark: Bool {
        scheme == .dark
    }

    var background: Color {
        SableTheme.gouacheBackground(for: scheme)
    }

    var paper: Color {
        isDark ? Color(hex: "#EADCC7") : Color(hex: "#FFF7EA")
    }

    var line: Color {
        isDark ? Color(hex: "#D8C9B5") : Color(hex: "#393734")
    }

    var texture: Color {
        isDark ? Color(hex: "#E1D4BF") : Color(hex: "#7D746A")
    }

    var blueWash: Color {
        isDark ? Color(hex: "#6F8790") : Color(hex: "#AFC5C8")
    }

    var shutter: Color {
        Color(hex: "#426578")
    }

    var orangeWash: Color {
        Color(hex: "#D96C2C")
    }

    var orange: Color {
        Color(hex: "#E8812F")
    }

    var leaf: Color {
        isDark ? Color(hex: "#8A8C61") : Color(hex: "#777B54")
    }
}

private extension ColoringPage {
    var homeArtworkAssetName: String? {
        switch title {
        case "Wildflowers":
            return "HomeWildflowersColored"
        case "Florist Window":
            return "HomeWildflowersLine"
        case "Amalfi Afternoon", "Lemon Balcony":
            return "HomeAmalfiColored"
        case "Rainy Library":
            return "HomeAmalfiLine"
        case "Sunday Light", "Quiet Balcony Room", "Mediterranean Kitchen Window":
            return "HomeInteriorColored"
        case "Toucan Canopy":
            return "HomeInteriorLine"
        case "Lemon Branch":
            return "HomeLemonColored"
        default:
            return nil
        }
    }
}

private extension PageCollection {
    var homeArtworkAssetName: String? {
        switch name {
        case "Fresh Botanicals":
            return "HomeWildflowersColored"
        case "Sunlit Places":
            return "HomeAmalfiColored"
        case "Quiet Rooms":
            return "HomeInteriorColored"
        case "Canopy Color":
            return "HomeAmalfiLine"
        default:
            return nil
        }
    }
}

#Preview("Home Light") {
    HomeView(viewModel: .previewLoaded)
        .preferredColorScheme(.light)
}

#Preview("Home Dark") {
    HomeView(viewModel: .previewLoaded)
        .preferredColorScheme(.dark)
}
