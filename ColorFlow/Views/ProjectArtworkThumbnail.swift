import SwiftUI
import UIKit

struct ProjectArtworkThumbnail: View {
    let page: ColoringPage
    let style: PlaceholderArtworkStyle
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            PlaceholderArtwork(tint: page.thumbnailColor, seed: page.title, style: style)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .background(SableTheme.paper)
            }
        }
        .clipped()
        .task(id: page.id) {
            guard let thumbnailPath = page.thumbnailPath,
                  let fillLayerPath = page.fillLayerPath else {
                image = nil
                return
            }
            image = ProjectThumbnailCache.shared.load(
                id: page.id,
                thumbnailPath: thumbnailPath,
                fillLayerPath: fillLayerPath
            )
        }
    }
}
