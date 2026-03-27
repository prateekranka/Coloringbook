import UIKit
import SwiftUI
import PencilKit

enum ExportFormat { case png, jpeg }

class ExportService {

    /// Composites all layers using TemplateRenderer and returns the final UIImage.
    func compositeImage(
        geometry: TemplateGeometry?,
        fills: [String: String],
        drawing: PKDrawing,
        background: Color,
        canvasSize: CGSize
    ) -> UIImage {
        guard let geometry = geometry else {
            // Fallback: render just the drawing on a solid background
            return ImageProcessing.composite(
                background: UIColor(background),
                fillLayer: nil,
                drawing: drawing,
                template: nil,
                size: canvasSize
            )
        }

        // Render pencil strokes to an image
        let pencilImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 1.0)

        return TemplateRenderer.renderExport(
            geometry: geometry,
            fills: fills,
            pencilImage: pencilImage,
            backgroundColor: UIColor(background),
            size: canvasSize
        )
    }

    /// Returns a UIActivityViewController ready to present for sharing.
    func shareActivityController(image: UIImage, format: ExportFormat) -> UIActivityViewController {
        let item: Any
        switch format {
        case .png:
            item = image.pngData() ?? image
        case .jpeg:
            item = image.jpegData(compressionQuality: 0.92) ?? image
        }
        return UIActivityViewController(activityItems: [item], applicationActivities: nil)
    }

    /// Saves an image directly to the user's photo library.
    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
