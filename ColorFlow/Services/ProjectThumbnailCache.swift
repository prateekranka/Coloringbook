import UIKit

/// Loads project thumbnails from disk with an in-memory cache keyed by project id.
/// Prefers the composited thumbnail at `thumbnailPath`; falls back to the raw
/// fill-layer PNG so projects saved before the thumbnail pass still display.
final class ProjectThumbnailCache: @unchecked Sendable {
    static let shared = ProjectThumbnailCache()

    private let cache = NSCache<NSUUID, UIImage>()

    func load(id: UUID, thumbnailPath: String, fillLayerPath: String) -> UIImage? {
        let key = id as NSUUID
        if let hit = cache.object(forKey: key) { return hit }

        let docs = StorageService.documentsURL
        let thumbURL = docs.appendingPathComponent(thumbnailPath)
        if let data = try? Data(contentsOf: thumbURL), let img = UIImage(data: data) {
            cache.setObject(img, forKey: key)
            return img
        }

        let fillURL = docs.appendingPathComponent(fillLayerPath)
        if let data = try? Data(contentsOf: fillURL), let img = UIImage(data: data) {
            cache.setObject(img, forKey: key)
            return img
        }

        return nil
    }

    func loadFillLayer(path: String) -> UIImage? {
        let fillURL = StorageService.documentsURL.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: fillURL) else { return nil }
        return UIImage(data: data)
    }

    func invalidate(id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
    }
}
