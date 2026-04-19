import SwiftUI
import PhotosUI
import AVFoundation

/// Sheet that guides the user through picking a photo and converting it to
/// a coloring template.
struct PhotoImportView: View {
    @State private var viewModel = PhotoImportViewModel()
    @Environment(\.dismiss) private var dismiss

    /// Called when the pipeline successfully produces a template.
    var onSuccess: (UserTemplate) -> Void

    // MARK: - Camera state

    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                // Progress overlay covers the entire sheet while running.
                if case .processing(let stage) = viewModel.viewState {
                    PhotoImportProgressView(stage: stage) {
                        viewModel.cancel()
                    }
                    .transition(.opacity)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Create from Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { closeButton }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isProcessing)
            .onChange(of: viewModel.selectedPhotoItem) { _, item in
                Task { await viewModel.handlePickedItem(item) }
            }
            // Camera
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    cameraImage = image
                    showCamera = false
                } onCancel: {
                    showCamera = false
                }
            }
            .onChange(of: cameraImage) { _, image in
                if let image { viewModel.handleCameraImage(image) }
            }
            // Camera permission denied
            .alert("Camera Access Required", isPresented: $viewModel.showCameraPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow ColorFlow to access your camera in Settings to take a photo.")
            }
            // Success: notify parent and dismiss
            .onChange(of: successTemplate) { _, template in
                if let template {
                    onSuccess(template)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Source buttons
                sourceSection

                // Validation feedback
                validationFeedback

                // Preview (if image is selected)
                if let image = pendingImage {
                    imagePreviewSection(image: image)
                }

                // Style picker
                if pendingImage != nil {
                    styleSection
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Source section

    @State private var photoPickerPresented = false

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a photo to turn into a coloring template")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 16)

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $viewModel.selectedPhotoItem,
                    matching: .images
                ) {
                    sourceButton(icon: "photo.on.rectangle", label: "Photo Library")
                }
                .accessibilityIdentifier("photoImport.photoLibrary")

                Button {
                    requestCameraAccess()
                } label: {
                    sourceButton(icon: "camera", label: "Take Photo")
                }
                .accessibilityIdentifier("photoImport.camera")
            }
            .padding(.horizontal, AppTheme.screenPadding)
        }
    }

    private func sourceButton(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
            Text(label)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .foregroundStyle(AppTheme.textPrimary)
    }

    // MARK: - Validation feedback

    @ViewBuilder
    private var validationFeedback: some View {
        switch viewModel.viewState {
        case .prevalidationFailed(let result):
            ValidationBanner(result: result, isBlocking: true) {}
                .padding(.horizontal, AppTheme.screenPadding)

        case .prevalidationWarning(let result):
            ValidationBanner(result: result, isBlocking: false) {
                viewModel.proceedDespiteWarning()
            }
            .padding(.horizontal, AppTheme.screenPadding)

        case .failed(let error):
            Text(error.localizedDescription ?? "An error occurred.")
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding(.horizontal, AppTheme.screenPadding)

        default:
            EmptyView()
        }
    }

    // MARK: - Image preview

    private func imagePreviewSection(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Photo")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.screenPadding)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                .padding(.horizontal, AppTheme.screenPadding)
        }
    }

    // MARK: - Style section

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a Style")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.screenPadding)

            StylePresetPickerView(selectedPreset: $viewModel.selectedPreset)

            Button {
                Task { await viewModel.startPipeline() }
            } label: {
                Text("Create Template")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                    .foregroundStyle(.white)
            }
            .disabled(!viewModel.canStartPipeline)
            .padding(.horizontal, AppTheme.screenPadding)
            .accessibilityIdentifier("photoImport.createTemplate")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityIdentifier("photoImport.close")
        }
    }

    // MARK: - Helpers

    private var pendingImage: UIImage? {
        viewModel.previewImage
    }

    private var successTemplate: UserTemplate? {
        if case .success(let t) = viewModel.viewState { return t }
        return nil
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            showCamera = true
        case .denied, .restricted:
            viewModel.showCameraPermissionAlert = true
        @unknown default:
            showCamera = true
        }
    }
}

// MARK: - Validation Banner

private struct ValidationBanner: View {
    let result: PhotoValidationResult
    let isBlocking: Bool
    let onDismiss: () -> Void

    var message: String {
        switch result {
        case .tooSmall(let actual, let minimum):
            return "Image too small (\(actual)px). Please use a photo at least \(minimum)px on the short side."
        case .lowContrast:
            return "This photo has very little contrast. Results may be minimal — you can still try."
        case .blurry:
            return "This photo looks blurry. Results may not be sharp — you can still try."
        case .valid:
            return ""
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isBlocking ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isBlocking ? .red : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)

                if !isBlocking {
                    Button("Continue anyway") { onDismiss() }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isBlocking ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
        )
    }
}
