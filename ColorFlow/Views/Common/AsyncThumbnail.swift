import SwiftUI

/// Async image loader with explicit loading, success, and error states.
///
/// Use inside a `ZStack` with a background shape; this view only renders the
/// image (or placeholder) itself.
struct AsyncThumbnail: View {
    let load: () async -> UIImage?
    let contentMode: ContentMode
    let placeholderSystemName: String

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if didFail {
                Image(systemName: placeholderSystemName)
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Brand.accent.opacity(0.5))
                    .accessibilityLabel("Thumbnail unavailable")
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(AppTheme.Ink.secondary)
                    .accessibilityLabel("Loading thumbnail")
            }
        }
        .task {
            didFail = false
            if let loaded = await load() {
                image = loaded
            } else {
                didFail = true
            }
        }
    }
}
