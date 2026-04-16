import SwiftUI

struct CanvasSettingsSheet: View {
    @Bindable var viewModel: CanvasViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $viewModel.stayInTheLines) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stay in the lines")
                            Text("Clip strokes to the region you first touch")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("canvas.settings.stayInTheLines.toggle")
                }
            }
            .navigationTitle("Canvas Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
