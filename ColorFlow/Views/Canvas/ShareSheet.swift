import SwiftUI
import UIKit

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export options sheet

struct ExportOptionsView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var exportedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var isRendering = true

    private let exportService = ExportService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview
                Group {
                    if isRendering {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.1))
                            .overlay(ProgressView("Rendering…"))
                            .frame(maxHeight: 320)
                    } else if let image = exportedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 6)
                            .frame(maxHeight: 320)
                    }
                }
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        if let image = exportedImage {
                            exportService.saveToPhotos(image)
                            showSaveConfirmation = true
                        }
                    } label: {
                        Label("Save to Photos", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(exportedImage == nil)

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share…", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(exportedImage == nil)
                }
                .padding(.horizontal)

                if showSaveConfirmation {
                    Label("Saved to Photos!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = exportedImage, let pngData = image.pngData() {
                    ShareSheet(activityItems: [pngData])
                }
            }
        }
        .task {
            isRendering = true
            let image = await Task.detached(priority: .userInitiated) { [viewModel] in
                exportService.compositeImage(
                    geometry: viewModel.templateGeometry,
                    fills: viewModel.regionFills,
                    drawing: viewModel.drawing,
                    background: viewModel.backgroundColor,
                    canvasSize: viewModel.canvasSize
                )
            }.value
            exportedImage = image
            isRendering = false
        }
    }
}
