import SwiftUI

/// Simplified layer panel showing the 3-layer model:
/// Background → Color/Pencil layer → Line Art (locked)
struct LayerPanelView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Line art (always on top, locked)
                LayerRow(
                    name: "Line Art",
                    icon: "pencil.line",
                    isVisible: viewModel.showLineArt,
                    isLocked: true,
                    preview: viewModel.templateImage.map { Image(uiImage: $0) }
                ) {
                    viewModel.showLineArt.toggle()
                }

                // Color + pencil layer
                LayerRow(
                    name: "Color",
                    icon: "paintpalette",
                    isVisible: viewModel.showColorLayer,
                    isLocked: false,
                    preview: nil
                ) {
                    viewModel.showColorLayer.toggle()
                }

                // Background color
                HStack {
                    Image(systemName: "square.fill")
                        .font(.title3)
                        .foregroundStyle(viewModel.backgroundColor)
                    Text("Background")
                    Spacer()
                    ColorPicker("", selection: $viewModel.backgroundColor)
                        .labelsHidden()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LayerRow: View {
    let name: String
    let icon: String
    let isVisible: Bool
    let isLocked: Bool
    let preview: Image?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail preview
            Group {
                if let preview = preview {
                    preview
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.2)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.secondary)

            Text(name)

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Locked")
            }

            Button { onToggle() } label: {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name) layer visibility")
            .accessibilityValue(isVisible ? "Visible" : "Hidden")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .disabled(isLocked && name == "Line Art")
        }
        .padding(.vertical, 2)
    }
}
