import SwiftUI

/// Horizontal scrolling category filter chips.
struct TemplateCategoryView: View {
    @Binding var selectedCategory: TemplateCategory?
    let categories: [TemplateCategory]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                CategoryChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        label: category.rawValue,
                        icon: category.systemImageName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.Surface.background.shadow(.inner(radius: 1)))
    }
}

private struct CategoryChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.Brand.accent : AppTheme.Ink.secondary.opacity(0.12))
            )
            .foregroundStyle(isSelected ? AppTheme.Brand.onAccent : AppTheme.Ink.primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
