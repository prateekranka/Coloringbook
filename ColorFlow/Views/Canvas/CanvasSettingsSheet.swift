import SwiftUI

struct CanvasSettingsSheet: View {
    @Environment(CanvasSettings.self) private var settings
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        @Bindable var appState = appState
        NavigationStack {
            Form {
                Section {
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
                Section("Appearance") {
                    Picker("Appearance", selection: $appState.appearance) {
                        Text("System").tag(AppearancePreference.system)
                        Text("Light").tag(AppearancePreference.light)
                        Text("Dark").tag(AppearancePreference.dark)
                    }
                    .pickerStyle(.segmented)
                }
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
