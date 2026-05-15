import PencilKit
import SwiftUI
import UIKit

enum ExportFormat {
    case png
    case jpeg
}

final class ExportService {
    func compositeImage(
        geometry: TemplateGeometry,
        fills: [String: String],
        drawing: PKDrawing = PKDrawing(),
        backgroundColor: UIColor = .white,
        size: CGSize
    ) -> UIImage {
        let pencilImage = drawing.bounds.isNull || drawing.bounds.isEmpty
            ? nil
            : drawing.image(from: CGRect(origin: .zero, size: size), scale: 1)

        return TemplateRenderer.renderExport(
            geometry: geometry,
            fills: fills,
            pencilImage: pencilImage,
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
