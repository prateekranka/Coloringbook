import SwiftUI

struct PatternPickerView: View {
    @Binding var selectedPattern: FillPattern
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(FillPattern.allCases) { pattern in
                    Button {
                        selectedPattern = pattern
                        HapticService.shared.impact(.light)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: pattern.systemImageName)
                                .font(.system(size: 28))
                                .foregroundStyle(selectedPattern == pattern ? Color.accentColor : Color.primary)
                            Text(pattern.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedPattern == pattern ? Color.accentColor.opacity(0.12) : Color(UIColor.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedPattern == pattern ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Pattern Fill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
