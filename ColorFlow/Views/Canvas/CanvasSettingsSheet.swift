import SwiftUI

struct CanvasSettingsSheet: View {
    @Environment(CanvasSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Toggle(isOn: $settings.stayInTheLines) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stay in the Lines")
                        Text("Strokes stay inside the shape you started in.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Ink.secondary)
                    }
                }
                .tint(AppTheme.Brand.accent)
            }
            .navigationTitle("Canvas Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
