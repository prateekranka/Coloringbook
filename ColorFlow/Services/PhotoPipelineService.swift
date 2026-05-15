import Foundation
import UIKit

// MARK: - Style Presets

/// The four photo-to-template processing presets surfaced in the UI.
enum PhotoStylePreset: String, CaseIterable, Identifiable {
    case simple       = "Simple"
    case detailed     = "Detailed"
    case boldOutlines = "Bold Outlines"
    case artistic     = "Artistic"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .simple:       return "Clean regions, fewer details"
        case .detailed:     return "More regions, finer detail"
        case .boldOutlines: return "Thick, prominent outlines"
        case .artistic:     return "Hand-drawn style (neural)"
        }
    }

    var systemImageName: String {
        switch self {
        case .simple:       return "circle.grid.2x2"
        case .detailed:     return "circle.grid.3x3"
        case .boldOutlines: return "bold"
        case .artistic:     return "wand.and.stars"
        }
    }
}

// MARK: - Pipeline Errors

enum PhotoPipelineError: Error, LocalizedError {
    case imageTooSmall(shortEdge: Int, minimum: Int)
    case emptyContent
    case insufficientTemplateDetail(String)
    case metalUnavailable
    case modelUnavailable(fallbackPreset: PhotoStylePreset)
    case processingFailed(String)
    case svgAssemblyFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageTooSmall(let actual, let minimum):
            return "Image is too small (\(actual)px on the short edge). Please use an image at least \(minimum)px on each side."
        case .emptyContent:
            return "The image doesn't have enough contrast or detail to create a coloring template. Try a photo with clearer subjects."
        case .insufficientTemplateDetail(let detail):
            return "The photo did not produce enough clean coloring regions. \(detail) Try a clearer photo or the Simple preset."
        case .metalUnavailable:
            return "GPU processing is not available on this device. Try a simpler preset."
        case .modelUnavailable(let fallback):
            return "The Artistic style isn't available on this device. Switching to \(fallback.rawValue)."
        case .processingFailed(let detail):
            return "Something went wrong while processing the photo: \(detail)"
        case .svgAssemblyFailed(let detail):
            return "Could not create a coloring template from this photo: \(detail)"
        }
    }
}

// MARK: - Pipeline Progress

/// Ordered stages shown in the progress UI.
enum PhotoPipelineStage: Int, CaseIterable {
    case analyzingImage    = 0
    case extractingEdges   = 1
    case creatingRegions   = 2
    case buildingTemplate  = 3

    var label: String {
        switch self {
        case .analyzingImage:   return "Analyzing image…"
        case .extractingEdges:  return "Extracting edges…"
        case .creatingRegions:  return "Creating regions…"
        case .buildingTemplate: return "Building template…"
        }
    }

    var progress: Double {
        Double(rawValue + 1) / Double(PhotoPipelineStage.allCases.count)
    }
}

// MARK: - Service Protocol

/// On-device photo-to-template conversion service.
///
/// **Privacy invariant:** This protocol has no URLSession, no network-capable
/// dependency, and no data-sharing surface. All processing is on-device.
/// Implementations must not add any networking capability.
///
/// Not `@MainActor`: the pipeline body is CPU-heavy and runs off the main
/// thread. `progressHandler` is `@Sendable` and implementations must hop to
/// MainActor themselves before invoking it.
protocol PhotoPipelineService: AnyObject, Sendable {
    /// Convert a photo to a coloring template using the given preset.
    ///
    /// - Parameters:
    ///   - image: The source photo (already pre-validated by `PhotoPreValidator`).
    ///   - preset: The style preset controlling algorithm parameters.
    ///   - progressHandler: Called on the main actor as each pipeline stage completes.
    /// - Returns: A `UserTemplate` ready to open in the canvas, or a `PhotoPipelineError`.
    func run(
        image: UIImage,
        preset: PhotoStylePreset,
        progressHandler: @escaping @Sendable (PhotoPipelineStage) -> Void
    ) async -> Result<UserTemplate, PhotoPipelineError>

    /// Cancel any in-flight pipeline operation.
    func cancel()
}

