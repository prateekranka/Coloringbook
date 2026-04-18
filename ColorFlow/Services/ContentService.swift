import Foundation
import OSLog

/// Loads the template catalogue from a CDN-hosted manifest and caches it
/// locally so the library grows without an App Store release.
///
/// Resolution order used by `Template.loadAll()`:
///   1. `cachedTemplates()` — in-memory decoded manifest (remote or cached).
///   2. Bundled `templates.json`.
///   3. `Template.bundledTemplates` hardcoded fallback.
///
/// `refreshInBackground()` is safe to call on every app launch — it short-
/// circuits when no `ContentManifestURL` is configured, uses ETag handling to
/// avoid redundant downloads, and never blocks the caller.
@Observable
final class ContentService: @unchecked Sendable {
    static let shared = ContentService()

    /// Decoded templates in memory. Published so SwiftUI can observe refreshes.
    private(set) var templates: [Template] {
        get { lock.withLock { _templates } }
        set { lock.withLock { _templates = newValue } }
    }

    /// Manifest version string reported by the server (ETag or `version` field).
    /// Used by the library to flag "new" badges relative to `lastSeenVersion`.
    private(set) var manifestVersion: String? {
        get { lock.withLock { _manifestVersion } }
        set { lock.withLock { _manifestVersion = newValue } }
    }

    /// Version the user has already seen (UserDefaults-backed).
    var lastSeenVersion: String? {
        get { UserDefaults.standard.string(forKey: Self.lastSeenVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastSeenVersionKey) }
    }

    private var _templates: [Template] = []
    private var _manifestVersion: String?
    private let lock = NSLock()

    // MARK: - Init / cache bootstrap

    private init() {
        if let cached = loadCachedManifest() {
            lock.withLock { self._templates = cached }
            AppLog.trace(AppLog.template, "ContentService loaded \(cached.count) templates from cache")
        }
    }

    /// Returns the in-memory catalogue when it's populated, otherwise nil so
    /// `Template.loadAll()` can fall through to bundled resources. Safe to
    /// call from any thread.
    func cachedTemplates() -> [Template]? {
        let snapshot = lock.withLock { _templates }
        return snapshot.isEmpty ? nil : snapshot
    }

    // MARK: - Refresh

    /// Non-blocking manifest refresh. Spawns a detached Task; safe to call
    /// from `ColorFlowApp.init()` or app-foreground notifications.
    func refreshInBackground() {
        Task.detached(priority: .utility) {
            await ContentService.shared.fetchManifest()
        }
    }

    /// Fetches the remote manifest, honouring `If-None-Match` against the
    /// stored ETag. Writes both the decoded templates and the raw JSON cache.
    func fetchManifest() async {
        guard let url = Self.manifestURL else {
            AppLog.trace(AppLog.template, "ContentManifestURL not set — skipping remote fetch")
            return
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        if let etag = UserDefaults.standard.string(forKey: Self.etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 304 {
                AppLog.trace(AppLog.template, "Manifest unchanged (304)")
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                AppLog.error(AppLog.template, "Manifest fetch HTTP \(http.statusCode)")
                return
            }

            let decoded = try JSONDecoder.contentDecoder.decode([Template].self, from: data)
            try? writeManifestCache(data)

            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: Self.etagKey)
            }
            let etag = http.value(forHTTPHeaderField: "ETag")
            lock.withLock {
                _templates = decoded
                if let etag { _manifestVersion = etag }
            }
            AppLog.trace(AppLog.template, "Manifest refreshed — \(decoded.count) templates")
        } catch {
            AppLog.error(AppLog.template, "Manifest fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - SVG download on demand

    /// Ensures `template.svgFilename` is available on disk. When the template
    /// has a `remoteSVGURL` and the cached file is missing, downloads it to
    /// `Caches/content/svgs/<filename>`. Returns the local URL on success.
    func ensureSVGCached(_ template: Template) async -> URL? {
        if let bundled = template.svgURL { return bundled }
        guard let remote = template.remoteSVGURL else { return nil }

        let destination = Self.svgCacheDirectory.appendingPathComponent(template.svgFilename)
        if FileManager.default.fileExists(atPath: destination.path) { return destination }

        do {
            try FileManager.default.createDirectory(at: Self.svgCacheDirectory,
                                                    withIntermediateDirectories: true)
            let (data, response) = try await URLSession.shared.data(from: remote)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                AppLog.error(AppLog.template, "SVG fetch HTTP \(http.statusCode) for \(template.svgFilename)")
                return nil
            }
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            AppLog.error(AppLog.template, "SVG fetch failed for \(template.svgFilename): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Cache locations

    private static let etagKey = "ContentService.manifestETag"
    private static let lastSeenVersionKey = "ContentService.lastSeenVersion"

    private static var manifestURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ContentManifestURL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else { return nil }
        return url
    }

    private static var contentCacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("content", isDirectory: true)
    }

    private static var manifestCacheURL: URL {
        contentCacheDirectory.appendingPathComponent("templates.json")
    }

    static var svgCacheDirectory: URL {
        contentCacheDirectory.appendingPathComponent("svgs", isDirectory: true)
    }

    private func loadCachedManifest() -> [Template]? {
        let url = Self.manifestCacheURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.contentDecoder.decode([Template].self, from: data),
              !decoded.isEmpty else { return nil }
        return decoded
    }

    private func writeManifestCache(_ data: Data) throws {
        try FileManager.default.createDirectory(at: Self.contentCacheDirectory,
                                                withIntermediateDirectories: true)
        try data.write(to: Self.manifestCacheURL, options: .atomic)
    }
}
