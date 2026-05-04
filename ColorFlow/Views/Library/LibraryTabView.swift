import SwiftUI

/// Library tab — full-screen template browser replacing the former modal sheet.
/// Phase 3 will add the underline-pill category redesign; for now it reuses the
/// existing TemplateLibraryView layout inside the dark-themed navigation stack.
struct LibraryTabView: View {
    @State private var viewModel = TemplateLibraryViewModel()
    @State private var searchText = ""
    @Environment(GalleryViewModel.self) var galleryViewModel

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Surface.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Category pills
                    LibraryCategoryBar(
                        selectedCategory: $viewModel.selectedCategory,
                        categories: TemplateCategory.allCases
                    )

                    Divider().background(Color.white.opacity(0.08))

                    if filteredTemplates.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            searchText.isEmpty ? "No Templates" : "No Results",
                            systemImage: "square.dashed",
                            description: Text(searchText.isEmpty
                                ? "Templates will appear here."
                                : "Try a different search term.")
                        )
                        .foregroundStyle(AppTheme.Ink.secondary)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(filteredTemplates) { template in
                                    LibraryTemplateCard(template: template) {
                                        galleryViewModel.startProject(from: template)
                                    }
                                }
                            }
                            .padding(AppTheme.Spacing.xl)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search templates")
        }
    }

    private var filteredTemplates: [Template] {
        let base = viewModel.filteredTemplates
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

}

// MARK: - Category Bar (underline-style)

struct LibraryCategoryBar: View {
    @Binding var selectedCategory: TemplateCategory?
    let categories: [TemplateCategory]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                CategoryTab(label: "All", isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = nil }
                }
                ForEach(categories, id: \.self) { cat in
                    CategoryTab(label: cat.rawValue, isSelected: selectedCategory == cat) {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = cat }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.Surface.background)
        .frame(height: 46)
    }
}

private struct CategoryTab: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(label)
                    .font(isSelected ? .subheadline.bold() : .subheadline)
                    .foregroundStyle(isSelected ? AppTheme.Brand.accent : AppTheme.Ink.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                // Underline indicator
                Rectangle()
                    .fill(isSelected ? AppTheme.Brand.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("library.category.\(label)")
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Template Card (white card on dark bg)

struct LibraryTemplateCard: View {
    let template: Template
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // White card face (accessibility lives on the outer Button)
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(Color.white)
                        .aspectRatio(1, contentMode: .fit)

                    AsyncThumbnail(
                        load: {
                            await TemplateRenderer.thumbnail(for: template, size: CGSize(width: 400, height: 400))
                        },
                        contentMode: .fit,
                        placeholderSystemName: template.category.systemImageName
                    )
                    .padding(10)
                }
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                // Name + difficulty
                Text(template.name)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.Ink.primary)
                    .lineLimit(1)

                DifficultyPill(difficulty: template.difficulty)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.name), \(template.category.rawValue), difficulty \(template.difficulty.rawValue)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("library.template.\(template.id.uuidString)")
    }
}

// MARK: - Difficulty Pill

struct DifficultyPill: View {
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
            .background(
                Capsule().fill(color.opacity(0.18))
            )
    }
}

// MARK: - Preview

#Preview {
    LibraryTabView()
        .environment(GalleryViewModel())
        .environment(AppState.shared)
}
