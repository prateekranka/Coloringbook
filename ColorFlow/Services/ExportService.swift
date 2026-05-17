import PencilKit
import SwiftUI
import UIKit

enum ExportFormat {
    case png
    case jpeg
}

final class ExportService {
    func compositeImage(
        lineArtImage: UIImage?,
        pigmentLayer: UIImage?,
        drawing: PKDrawing = PKDrawing(),
        backgroundColor: UIColor = CanvasSnapshotRenderer.paperColor,
        size: CGSize
    ) -> UIImage {
        CanvasSnapshotRenderer().render(
            lineArtImage: lineArtImage,
            pigmentLayer: pigmentLayer,
            drawing: drawing,
            backgroundColor: backgroundColor,
            size: size
        )
    }

    func compositeImage(
        geometry: TemplateGeometry,
        fills: [String: String],
        pigmentLayer: UIImage? = nil,
        drawing: PKDrawing = PKDrawing(),
        backgroundColor: UIColor = CanvasSnapshotRenderer.paperColor,
        size: CGSize
    ) -> UIImage {
        let fallbackPigment = pigmentLayer ?? TemplateRenderer.renderFillLayer(
            geometry: geometry,
            fills: fills,
            size: size
        )
        return compositeImage(
            lineArtImage: TemplateRenderer.renderLineArt(geometry: geometry, size: size),
            pigmentLayer: fallbackPigment,
            drawing: drawing,
            backgroundColor: backgroundColor,
            size: size
        )
    }

    func activityItems(for image: UIImage, format: ExportFormat = .png) -> [Any] {
        switch format {
        case .png:
            return [image.pngData() ?? image]
        case .jpeg:
            return [image.jpegData(compressionQuality: 0.92) ?? image]
        }
    }

    func shareActivityController(image: UIImage, format: ExportFormat = .png) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems(for: image, format: format), applicationActivities: nil)
    }

    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
