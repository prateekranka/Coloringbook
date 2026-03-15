import UIKit
import CoreGraphics
import PencilKit

enum ImageProcessing {

    /// Composites all canvas layers into a single UIImage for export or thumbnail generation.
    static func composite(
        background: UIColor,
        fillLayer: UIImage?,
        drawing: PKDrawing,
        template: UIImage?,
        size: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 1. Background
            background.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // 2. Fill layer
            fillLayer?.draw(in: CGRect(origin: .zero, size: size))

            // 3. PencilKit strokes
            let strokeImage = drawing.image(from: CGRect(origin: .zero, size: size), scale: scale)
            strokeImage.draw(in: CGRect(origin: .zero, size: size))

            // 4. Line art (multiply blend mode)
            if let template = template {
                ctx.cgContext.setBlendMode(.multiply)
                template.draw(in: CGRect(origin: .zero, size: size))
                ctx.cgContext.setBlendMode(.normal)
            }
        }
    }

    /// Generates a thumbnail by compositing and downscaling.
    static func thumbnail(
        background: UIColor,
        fillLayer: UIImage?,
        drawing: PKDrawing,
        template: UIImage?,
        sourceSize: CGSize,
        thumbnailSize: CGSize = CGSize(width: 400, height: 400)
    ) -> UIImage {
        let full = composite(background: background, fillLayer: fillLayer,
                             drawing: drawing, template: template, size: sourceSize, scale: 1.0)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { _ in
            full.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }

    /// Renders an SVG-rendered UIImage to a pixel buffer at the given size.
    /// Use this to convert SVGKit output to the fill bitmap resolution.
    static func renderToBitmap(_ image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
