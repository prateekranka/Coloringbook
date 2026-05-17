import PencilKit
import UIKit

struct CanvasSnapshotRenderer {
    static let paperColor = UIColor(hex: "#FFFDF8")

    func render(
        lineArtImage: UIImage?,
        pigmentLayer: UIImage?,
        drawing: PKDrawing = PKDrawing(),
        backgroundColor: UIColor = CanvasSnapshotRenderer.paperColor,
        size: CGSize
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            backgroundColor.setFill()
            context.fill(bounds)

            let artRect = imageRect(for: pigmentLayer ?? lineArtImage, in: bounds)
            pigmentLayer?.draw(in: artRect)

            if !drawing.bounds.isNull && !drawing.bounds.isEmpty {
                drawing.image(from: CGRect(origin: .zero, size: size), scale: 1).draw(in: bounds)
            }

            if let lineArtImage {
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.setBlendMode(.multiply)
                lineArtImage.draw(in: imageRect(for: lineArtImage, in: bounds))
                cgContext.restoreGState()
            }
        }
    }

    func thumbnail(
        lineArtImage: UIImage?,
        pigmentLayer: UIImage?,
        drawing: PKDrawing = PKDrawing(),
        size: CGSize = CGSize(width: 512, height: 512)
    ) -> UIImage? {
        let hasDrawing = !drawing.bounds.isNull && !drawing.bounds.isEmpty
        guard lineArtImage != nil || pigmentLayer != nil || hasDrawing else {
            return nil
        }

        let sourceSize = lineArtImage?.size
            ?? pigmentLayer?.size
            ?? drawing.bounds.integral.size
        let composite = render(
            lineArtImage: lineArtImage,
            pigmentLayer: pigmentLayer,
            drawing: drawing,
            size: sourceSize
        )

        return UIGraphicsImageRenderer(size: size).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            CanvasSnapshotRenderer.paperColor.setFill()
            context.fill(bounds)

            let rect = imageRect(for: composite, in: bounds)
            composite.draw(in: rect)
        }
    }

    private func imageRect(for image: UIImage?, in bounds: CGRect) -> CGRect {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
