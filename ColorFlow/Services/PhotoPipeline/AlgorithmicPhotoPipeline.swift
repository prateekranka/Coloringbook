import UIKit
import Foundation

// MARK: - Preset Parameters Bundle

private struct PipelineParams {
    let preprocessor:  PreprocessorParams
    let k:             Int             // k-means cluster count
    let xdog:          XDoGParams
    let dilationRadius: Int            // morphology dilation (0 = none)
    let contour:       ContourVectorizer.Params

    static let simple = PipelineParams(
        preprocessor:   .simple,
        k:              6,
        xdog:           .simple,
        dilationRadius: 0,
        contour:        .simple
    )
    static let detailed = PipelineParams(
        preprocessor:   .detailed,
        k:              16,
        xdog:           .detailed,
        dilationRadius: 0,
        contour:        .detailed
    )
    static let boldOutlines = PipelineParams(
        preprocessor:   .boldOutlines,
        k:              6,
        xdog:           .boldOutlines,
        dilationRadius: 4,
        contour:        .boldOutlines
    )
}

// MARK: - AlgorithmicPhotoPipeline

/// Full on-device algorithmic pipeline for Simple, Detailed, and Bold Outlines presets.
/// The Artistic preset is handled by `NeuralPhotoPipeline` (C3), which delegates
/// all stages except edge detection here.
final class AlgorithmicPhotoPipeline: PhotoPipelineService, @unchecked Sendable {

    // Cancellation flag read from the background pipeline and mutated from
    // `cancel()` on the caller's actor. Guarded by a lock so it's safe across
    // isolation boundaries without forcing the whole pipeline onto MainActor.
    private let cancelLock = NSLock()
    private var _isCancelled = false
    private var isCancelled: Bool {
        cancelLock.lock(); defer { cancelLock.unlock() }
        return _isCancelled
    }
    private func setCancelled(_ value: Bool) {
        cancelLock.lock(); defer { cancelLock.unlock() }
        _isCancelled = value
    }

    private let storage = StorageService()

    func run(
        image: UIImage,
        preset: PhotoStylePreset,
        progressHandler: @escaping @Sendable (PhotoPipelineStage) -> Void
    ) async -> Result<UserTemplate, PhotoPipelineError> {
        setCancelled(false)
        let params = pipelineParams(for: preset)

        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return .failure(.processingFailed("Pipeline deallocated")) }

            // Stage 1: Analyzing image
            await MainActor.run { progressHandler(.analyzingImage) }
            guard !self.isCancelled else { return .failure(.processingFailed("Cancelled")) }

            let preprocessed = Preprocessor.preprocess(image, params: params.preprocessor)

            // Downsample to max 1024px for pipeline performance; Vision will resize internally
            let workImage = Self.downsample(preprocessed, maxEdge: 1024)

            // Stage 2: Extracting edges
            await MainActor.run { progressHandler(.extractingEdges) }
            guard !self.isCancelled else { return .failure(.processingFailed("Cancelled")) }

            let segmented = KMeansSegmenter.segment(workImage, k: params.k)

            // Edge detection: neural for Artistic, XDoG for all other presets.
            let edges: UIImage
            var modelUnavailableError: PhotoPipelineError? = nil
            if preset == .artistic {
                switch NeuralEdgeDetector.detect(segmented) {
                case .success(let img):
                    edges = img
                case .fallback(let img, let err):
                    edges = img
                    modelUnavailableError = err  // surface to caller after success
                }
            } else {
                edges = XDoGEdgeDetector.detect(segmented, params: params.xdog)
            }

            let cleaned = MorphologyCleanup.clean(edges, dilationRadius: params.dilationRadius)

            // Stage 3: Creating regions
            await MainActor.run { progressHandler(.creatingRegions) }
            guard !self.isCancelled else { return .failure(.processingFailed("Cancelled")) }

            let vectorResult: ContourVectorizer.VectorizationResult
            do {
                vectorResult = try ContourVectorizer.detect(cleaned, params: params.contour)
            } catch let error as PhotoPipelineError {
                return .failure(error)
            } catch {
                return .failure(.processingFailed(error.localizedDescription))
            }

            guard !vectorResult.regionPaths.isEmpty else {
                return .failure(.emptyContent)
            }

            // Stage 4: Building template
            await MainActor.run { progressHandler(.buildingTemplate) }
            guard !self.isCancelled else { return .failure(.processingFailed("Cancelled")) }

            let templateName = "Photo Template"
            let svgString: String
            do {
                svgString = try SVGAssembler.assemble(vectorResult, templateName: templateName)
            } catch let error as PhotoPipelineError {
                return .failure(error)
            } catch {
                return .failure(.svgAssemblyFailed(error.localizedDescription))
            }

            // Parity check: write SVG to a temp file and parse via SVGParser
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".svg")
            do {
                try svgString.write(to: tmpURL, atomically: true, encoding: .utf8)
            } catch {
                return .failure(.svgAssemblyFailed("Could not write temp SVG: \(error.localizedDescription)"))
            }
            defer { try? FileManager.default.removeItem(at: tmpURL) }

            let geometry: TemplateGeometry
            switch SVGParser.parse(url: tmpURL) {
            case .success(let g):
                geometry = g
            case .failure(let e):
                return .failure(.svgAssemblyFailed("Produced SVG failed parser parity check: \(e.localizedDescription ?? "\(e)")"))
            }

            // Persist and return the user template
            let userTemplate = UserTemplate(name: templateName, preset: preset.rawValue)
            let thumbnail = TemplateRenderer.renderThumbnail(
                geometry: geometry,
                size: CGSize(width: 400, height: 400)
            )

            do {
                try await MainActor.run {
                    try self.storage.saveUserTemplate(userTemplate, svgString: svgString, thumbnail: thumbnail)
                }
            } catch {
                return .failure(.processingFailed("Could not save template: \(error.localizedDescription)"))
            }

            return .success(userTemplate)
        }.value
    }

    func cancel() {
        setCancelled(true)
    }

    // MARK: - Helpers

    private func pipelineParams(for preset: PhotoStylePreset) -> PipelineParams {
        switch preset {
        case .simple:       return .simple
        case .detailed:     return .detailed
        case .boldOutlines: return .boldOutlines
        case .artistic:     return .detailed  // fallback; Artistic overrides edge stage in C3
        }
    }

    private static func downsample(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxEdge else { return image }
        let scale = maxEdge / longestEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
