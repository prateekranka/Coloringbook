import SwiftUI

/// Horizontal row of style preset chips.
struct StylePresetPickerView: View {
    @Binding var selectedPreset: PhotoStylePreset

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PhotoStylePreset.allCases) { preset in
                    PresetChip(
                        preset: preset,
                        isSelected: selectedPreset == preset
                    ) {
                        selectedPreset = preset
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preset Chip

private struct PresetChip: View {
    let preset: PhotoStylePreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: preset.systemImageName)
                    .font(.title3)
                    .frame(width: 32, height: 32)

                Text(preset.rawValue)
                    .font(.caption.weight(.medium))

                Text(preset.description)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? AppTheme.Ink.primary.opacity(0.8) : AppTheme.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 100)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 120)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(isSelected ? AppTheme.Brand.accentSubtle : AppTheme.Surface.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .strokeBorder(
                                isSelected ? AppTheme.Brand.accent : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .foregroundStyle(isSelected ? AppTheme.Brand.accent : AppTheme.Ink.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.rawValue) style: \(preset.description)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("photoImport.preset.\(preset.rawValue)")
    }
}
