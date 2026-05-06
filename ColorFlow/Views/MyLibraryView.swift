import SwiftUI

@MainActor
struct MyLibraryView: View {
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
            SableTheme.cream.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(SableTheme.progressPink)
                    .scaleEffect(1.25)
            } else if viewModel.pages.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.pages) { page in
                                LibraryProjectCard(page: page) {
                                    navigate(.coloringPage(page))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SableTheme.Spacing.pageInset)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Library")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(SableTheme.ink)

            Text("\(viewModel.pages.count) SAVED")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(SableTheme.cardBlack, in: Capsule())
                .accessibilityIdentifier("library.savedCount")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(SableTheme.crimson)

            Text("My Library")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(SableTheme.ink)

            Text("Saved projects appear here")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SableTheme.mutedInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }
}

private struct LibraryProjectCard: View {
    let page: ColoringPage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectArtworkThumbnail(page: page, style: .wide)
                    .aspectRatio(1.35, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(page.title)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 12)

                        Text(progressText)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    }

                    ProgressTrack(progress: page.progress)
                }
                .padding(15)
                .background(SableTheme.cardBlack)
            }
            .clipShape(RoundedRectangle(cornerRadius: SableTheme.Radius.card))
            .shadow(color: SableTheme.cardShadow, radius: 8, x: 0, y: 5)
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
