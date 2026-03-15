import UIKit
import SwiftUI
import PencilKit

enum ExportFormat { case png, jpeg }

class ExportService {

    /// Composites all layers and returns the final UIImage.
    func compositeImage(
        background: Color,
        fillLayer: UIImage?,
        drawing: PKDrawing,
        template: UIImage?,
        canvasSize: CGSize,
        includeLineArt: Bool = true
    ) -> UIImage {
        ImageProcessing.composite(
            background: UIColor(background),
            fillLayer: fillLayer,
            drawing: drawing,
            template: includeLineArt ? template : nil,
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
