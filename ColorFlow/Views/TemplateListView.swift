import SwiftUI
import UIKit

@MainActor
struct TemplateListView: View {
    @State private var viewModel: TemplateListViewModel
    let navigate: (AppRoute) -> Void

    init(
        source: TemplateListViewModel.Source,
        repository: any ColoringFlowRepositoryProtocol = SableHomeRepository(),
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: TemplateListViewModel(source: source, repository: repository))
        self.navigate = navigate
    }

    init(
        viewModel: TemplateListViewModel,
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigate = navigate
    }

    var body: some View {
        ZStack {
            SableTheme.cream.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if viewModel.isLoading {
                        loading
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.templates) { template in
                                TemplateCard(template: template) {
                                    Task {
                                        let route = await viewModel.routeForTemplate(template)
                                        navigate(route)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, SableTheme.Spacing.pageInset)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(viewModel.source.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.source.title)
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(SableTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(viewModel.source.subtitle)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(SableTheme.cardBlack, in: Capsule())
        }
    }

    private var loading: some View {
        ProgressView()
            .tint(SableTheme.progressPink)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }
}

private struct TemplateCard: View {
    let template: Template
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                TemplateThumbnailView(template: template)
                    .aspectRatio(1.18, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 7) {
                    Text(template.name)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 8) {
                        Text(template.category.rawValue.uppercased())
                        Text(template.difficulty.rawValue.uppercased())
                    }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.76))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(SableTheme.cardBlack)
            }
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(color: SableTheme.cardShadow, radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
        .accessibilityIdentifier("template.\(template.name.normalizedIdentifier)")
    }
}

private struct TemplateThumbnailView: View {
    let template: Template
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            PlaceholderArtwork(
                tint: template.category.accentColor,
                seed: template.name,
                style: .compact
            )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .background(SableTheme.paper)
            }
        }
        .task(id: template.id) {
            image = await TemplateRenderer.thumbnail(for: template)
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

#Preview("Collection Templates") {
    NavigationStack {
        TemplateListView(
            source: .collection(MockHomeRepository.collections[1]),
            repository: MockHomeRepository()
        )
    }
}

#Preview("Mood Templates") {
    NavigationStack {
        TemplateListView(
            source: .mood(.calm),
            repository: MockHomeRepository()
        )
    }
}
