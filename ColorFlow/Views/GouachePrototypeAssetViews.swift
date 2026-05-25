import SwiftUI
import UIKit

enum GouachePreviewContentMode {
    case fit
    case fill
}

struct GouacheTemplatePreviewImage: View {
    let template: Template
    var contentMode: GouachePreviewContentMode = .fill

    var body: some View {
        ZStack {
            Color(hex: "#F6EFE3")

            if let uiImage = loadImage(from: template.previewURL ?? template.lineArtURL) {
                renderedImage(uiImage)
            } else {
                PlaceholderArtwork(
                    tint: placeholderTint,
                    seed: template.name,
                    style: .compact
                )
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func renderedImage(_ uiImage: UIImage) -> some View {
        switch contentMode {
        case .fit:
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        case .fill:
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        }
    }

    private func loadImage(from url: URL?) -> UIImage? {
        guard let url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var placeholderTint: Color {
        switch template.category {
        case .mandalas:
            return MoodCategory.dreamy.accentColor
        case .animals:
            return MoodCategory.wild.accentColor
        case .architecture:
            return MoodCategory.noir.accentColor
        case .abstract:
            return MoodCategory.bold.accentColor
        case .botanicals:
            return MoodCategory.calm.accentColor
        case .lifestyle:
            return MoodCategory.playful.accentColor
        }
    }
}

struct GouacheProfileArtworkImage: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: artworkURL?.path ?? "") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(SableTheme.gouachePanel(for: colorScheme))
        }
    }

    private var artworkURL: URL? {
        let filename = colorScheme == .dark ? "profile-still-life-dark" : "profile-still-life-light"
        return Bundle.main.url(forResource: filename, withExtension: "jpg", subdirectory: "ProfileArtwork")
            ?? Bundle.main.resourceURL?.appendingPathComponent("ProfileArtwork/\(filename).jpg")
    }
}

struct GouacheProfileAvatarImage: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: avatarURL?.path ?? "") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(SableTheme.gouachePanel(for: colorScheme))
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(SableTheme.gouachePrimaryText(for: colorScheme).opacity(0.74))
                }
        }
    }

    private var avatarURL: URL? {
        Bundle.main.url(forResource: "profile-avatar", withExtension: "jpg", subdirectory: "ProfileArtwork")
            ?? Bundle.main.resourceURL?.appendingPathComponent("ProfileArtwork/profile-avatar.jpg")
    }
}
