import SwiftUI

@MainActor
struct MyLibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: MyLibraryViewModel
    let navigate: (AppRoute) -> Void

    init(
        repository: any HomeRepositoryProtocol = SableHomeRepository(),
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: MyLibraryViewModel(repository: repository))
        self.navigate = navigate
    }

    init(
        viewModel: MyLibraryViewModel,
        navigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigate = navigate
    }

    var body: some View {
        ZStack {
            SableTheme.appBackground(for: colorScheme).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(SableTheme.progressPink)
                    .scaleEffect(1.25)
            } else if viewModel.pages.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SableTheme.Spacing.xxxl) {
                        header

                        LazyVGrid(columns: columns, spacing: SableTheme.Spacing.xl) {
                            ForEach(viewModel.pages) { page in
                                LibraryProjectCard(page: page) {
                                    navigate(.coloringPage(page))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SableTheme.Spacing.pageInset)
                    .padding(.top, SableTheme.Spacing.xxxl)
                    .padding(.bottom, 24)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SableTheme.Spacing.xs) {
            Text("My Library")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

            Text("\(viewModel.pages.count) SAVED")
                .font(SableTheme.Typography.bodySmall.weight(.black))
                .foregroundStyle(.white)
                .padding(.horizontal, SableTheme.Spacing.lg)
                .padding(.vertical, SableTheme.Spacing.xxs)
                .background(SableTheme.cardBlack, in: Capsule())
                .accessibilityIdentifier("library.savedCount")
        }
    }

    private var emptyState: some View {
        VStack(spacing: SableTheme.Spacing.xxl) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(SableTheme.crimson)

            Text("My Library")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))

            Text("Saved projects appear here")
                .font(SableTheme.Typography.bodyMedium.weight(.semibold))
                .foregroundStyle(SableTheme.gouacheSecondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: SableTheme.Spacing.xl),
            GridItem(.flexible(), spacing: SableTheme.Spacing.xl)
        ]
    }
}

private struct LibraryProjectCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: ColoringPage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .aspectRatio(1.35, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: SableTheme.Spacing.sm) {
                    HStack {
                        Text(page.title)
                            .font(SableTheme.Typography.fraunces(22, weight: .black))
                            .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: SableTheme.Spacing.md)

                        Text(progressText)
                            .font(SableTheme.Typography.bodyMedium.weight(.black))
                            .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme))
                    }

                    ProgressTrack(progress: page.progress)
                }
                .padding(SableTheme.Spacing.lg)
                .background(SableTheme.cardSurface(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(
                color: SableTheme.Shadow.card(for: colorScheme).color,
                radius: SableTheme.Shadow.card(for: colorScheme).radius,
                x: SableTheme.Shadow.card(for: colorScheme).x,
                y: SableTheme.Shadow.card(for: colorScheme).y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(page.title), \(progressText) complete")
        .accessibilityIdentifier("library.project.\(page.title.normalizedIdentifier)")
    }

    private var progressText: String {
        "\(Int((page.progress * 100).rounded()))%"
    }
}

#Preview("My Library") {
    MyLibraryView(viewModel: .previewLoaded)
}
