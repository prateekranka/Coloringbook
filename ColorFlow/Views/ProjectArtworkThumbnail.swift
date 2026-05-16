import SwiftUI
import UIKit

struct ProjectArtworkThumbnail: View {
    let page: ColoringPage
    let style: PlaceholderArtworkStyle
    @Environment(RenderTuningStore.self) private var renderTuning
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PlaceholderArtwork(tint: page.thumbnailColor, seed: page.title, style: style)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .background(SableTheme.paper)
                }

                if image == nil {
                    PartialColorWash(tint: page.thumbnailColor, seed: page.title, style: style)
                        .allowsHitTesting(false)
                }
            }
            .clipped()
        }
        .task(id: taskID) {
            if let thumbnailPath = page.thumbnailPath,
               let fillLayerPath = page.fillLayerPath,
               let savedImage = ProjectThumbnailCache.shared.load(
                   id: page.id,
                   thumbnailPath: thumbnailPath,
                   fillLayerPath: fillLayerPath
               ) {
                image = savedImage
                return
            }

            if let templateId = page.templateId,
               let template = Template.loadAll().first(where: { $0.id == templateId }) {
                let renderSize = style == .wide ? CGSize(width: 520, height: 300) : CGSize(width: 280, height: 220)
                if let fillLayerPath = page.fillLayerPath {
                    let fillLayer = ProjectThumbnailCache.shared.loadFillLayer(path: fillLayerPath)
                    image = await TemplateRenderer.thumbnail(
                        for: template,
                        fillLayer: fillLayer,
                        size: renderSize,
                        strokeWidthPixels: CGFloat(renderTuning.thumbnailStrokeWidth)
                    )
                    return
                }

                image = await TemplateRenderer.thumbnail(
                    for: template,
                    size: renderSize,
                    strokeWidthPixels: CGFloat(renderTuning.thumbnailStrokeWidth)
                )
            } else if let thumbnailPath = page.thumbnailPath,
                      let fillLayerPath = page.fillLayerPath {
                image = ProjectThumbnailCache.shared.load(
                    id: page.id,
                    thumbnailPath: thumbnailPath,
                    fillLayerPath: fillLayerPath
                )
            } else {
                image = nil
            }
        }
    }

    private var taskID: TemplateThumbnailTaskID {
        TemplateThumbnailTaskID(
            templateID: page.templateId ?? page.id,
            strokeWidth: renderTuning.thumbnailStrokeWidth,
            thumbnailPath: page.thumbnailPath,
            fillLayerPath: page.fillLayerPath
        )
    }
}

private struct TemplateThumbnailTaskID: Hashable {
    let templateID: UUID
    let strokeWidth: Double
    let thumbnailPath: String?
    let fillLayerPath: String?
}

private struct PartialColorWash: View {
    let tint: Color
    let seed: String
    let style: PlaceholderArtworkStyle

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let palette = [
                    tint.opacity(0.34),
                    SableTheme.blush.opacity(0.32),
                    SableTheme.butter.opacity(0.34),
                    SableTheme.sage.opacity(0.3)
                ]
                let count = style == .wide ? 5 : 3
                for index in 0..<count {
                    var path = Path(roundedRect: blobRect(index: index, size: size), cornerRadius: size.height * 0.18)
                    path = path.applying(CGAffineTransform(rotationAngle: CGFloat(index - 2) * 0.05))
                    context.fill(path, with: .color(palette[index % palette.count]))
                }
            }
            .blendMode(.multiply)
            .opacity(0.9)
        }
    }

    private func blobRect(index: Int, size: CGSize) -> CGRect {
        let width = size.width * CGFloat(style == .wide ? 0.22 + Double(index % 2) * 0.1 : 0.34)
        let height = size.height * CGFloat(style == .wide ? 0.28 : 0.34)
        let xSeed = CGFloat((seed.count * 23 + index * 37) % 100) / 100
        let ySeed = CGFloat((seed.count * 17 + index * 29) % 100) / 100
        let x = min(max(size.width * xSeed, width * 0.3), size.width - width * 1.05)
        let y = min(max(size.height * ySeed, height * 0.25), size.height - height * 1.1)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
