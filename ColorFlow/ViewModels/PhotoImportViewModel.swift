import SwiftUI
import PhotosUI
import Observation

// MARK: - View State

enum PhotoImportViewState {
    case idle
    case prevalidationFailed(PhotoValidationResult)
    case prevalidationWarning(PhotoValidationResult)  // user can dismiss and proceed
    case processing(stage: PhotoPipelineStage)
    case success(UserTemplate)
    case failed(PhotoPipelineError)
}

// MARK: - PhotoImportViewModel

@MainActor
@Observable
final class PhotoImportViewModel {

    // MARK: State

    var selectedPhotoItem: PhotosPickerItem?
    var selectedPreset: PhotoStylePreset = .simple
    var viewState: PhotoImportViewState = .idle
    var showCameraPermissionAlert = false
    var previewImage: UIImage?

    // MARK: Private

    private var pipeline: PhotoPipelineService
    private var pendingImage: UIImage? {
        didSet { previewImage = pendingImage }
    }

    // MARK: - Init

    init(pipeline: PhotoPipelineService = AlgorithmicPhotoPipeline()) {
        self.pipeline = pipeline
    }

    // MARK: - Photo selection

    /// Called when the user picks a photo from the Photos picker.
    func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            viewState = .failed(.processingFailed("Could not load the selected photo."))
            return
        }
        validate(image: image)
    }

    /// Called when the user takes a photo with the camera.
    func handleCameraImage(_ image: UIImage) {
        validate(image: image)
    }

    // MARK: - Pre-validation

    private func validate(image: UIImage) {
        let result = PhotoPreValidator.validate(image)
        switch result {
        case .valid:
            pendingImage = image
            viewState = .idle
        case .tooSmall:
            viewState = .prevalidationFailed(result)
        case .lowContrast, .blurry:
            pendingImage = image
            viewState = .prevalidationWarning(result)
        }
    }

    /// User dismissed the soft-warning and chose to proceed anyway.
    func proceedDespiteWarning() {
        guard case .prevalidationWarning = viewState else { return }
        viewState = .idle
    }

    // MARK: - Pipeline

    func startPipeline() async {
        guard let image = pendingImage else { return }

        // Show first stage immediately so the UI transitions before the pipeline starts.
        viewState = .processing(stage: .analyzingImage)

        // Pipeline contract: progressHandler is invoked on MainActor (the
        // implementation hops via `MainActor.run`). We hop explicitly so the
        // compiler can verify the mutation is safe.
        let result = await pipeline.run(image: image, preset: selectedPreset) { [weak self] stage in
            Task { @MainActor in self?.viewState = .processing(stage: stage) }
        }

        switch result {
        case .success(let template):
            viewState = .success(template)
        case .failure(let error):
            viewState = .failed(error)
        }
    }

    func cancel() {
        pipeline.cancel()
        viewState = .idle
        pendingImage = nil
    }

    // MARK: - Helpers

    var canStartPipeline: Bool {
        guard pendingImage != nil else { return false }
        if case .processing = viewState { return false }
        if case .prevalidationFailed = viewState { return false }
        return true
    }

    var isProcessing: Bool {
        if case .processing = viewState { return true }
        return false
    }
}
