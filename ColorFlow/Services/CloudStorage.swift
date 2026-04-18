import Foundation
import OSLog

/// Decides where projects and user templates live: iCloud's ubiquity container
/// when available, otherwise the local Documents directory. Also surfaces a
/// `SyncStatus` that UI can observe to show a tiny "iCloud / Syncing… / off"
/// indicator.
///
/// Design rules:
///   - Path logic elsewhere keeps using `StorageService.documentsURL` — it
///     simply forwards to `CloudStorage.shared.documentsURL` so the switch is
///     transparent for callers.
///   - Switching between locations is decided once per launch. We don't try to
///     migrate files between locations mid-session; that's an explicit Settings
///     action (not implemented in this pass).
///   - `documentsURL`/`isUsingICloud` are readable from any thread via an
///     internal lock. `status` is `@MainActor` so SwiftUI can observe it.
@Observable
final class CloudStorage: @unchecked Sendable {
    static let shared = CloudStorage()

    enum SyncStatus: Equatable {
        case localOnly          // iCloud disabled or unavailable
        case upToDate           // iCloud connected, no pending downloads
        case syncing            // at least one file still downloading/uploading
        case error(String)

        var displayLabel: String {
            switch self {
            case .localOnly:       return "iCloud off"
            case .upToDate:        return "Up to date • iCloud"
            case .syncing:         return "Syncing…"
            case .error(let msg):  return msg
            }
        }

        var systemImage: String {
            switch self {
            case .localOnly:   return "icloud.slash"
            case .upToDate:    return "checkmark.icloud"
            case .syncing:     return "arrow.clockwise.icloud"
            case .error:       return "exclamationmark.icloud"
            }
        }
    }

    /// Main-thread observable state. SwiftUI should bind to this.
    @MainActor private(set) var status: SyncStatus = .localOnly

    /// The resolved Documents directory, safe to read from any thread. Either
    /// `ubiquityContainer/Documents` (iCloud) or `~/Documents` (local).
    var documentsURL: URL { lock.withLock { _documentsURL } }

    /// Whether the resolved `documentsURL` points at the iCloud container.
    var isUsingICloud: Bool { lock.withLock { _isUsingICloud } }

    private var _documentsURL: URL
    private var _isUsingICloud: Bool = false
    private let lock = NSLock()

    /// Ubiquity container identifier. Matches `com.apple.developer.icloud-container-identifiers`
    /// in `ColorFlow.entitlements`.
    private static let ubiquityContainer = "iCloud.com.prateekranka.colorflow"

    private var metadataQuery: NSMetadataQuery?
    private var metadataObservers: [NSObjectProtocol] = []

    private init() {
        _documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Called once at launch. Blocks briefly to resolve the ubiquity container
    /// so the very first `documentsURL` read returns the right location.
    func bootstrap() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: Self.ubiquityContainer)
            if let ubiquity {
                let docs = ubiquity.appendingPathComponent("Documents", isDirectory: true)
                try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
                self.lock.withLock {
                    self._documentsURL = docs
                    self._isUsingICloud = true
                }
                await MainActor.run {
                    self.status = .upToDate
                    self.startMetadataObservation()
                }
                AppLog.trace(AppLog.storage, "Using iCloud container at \(docs.path)")
            } else {
                await MainActor.run { self.status = .localOnly }
                AppLog.trace(AppLog.storage, "iCloud container unavailable — using local Documents")
            }
        }
    }

    // MARK: - Metadata query (download-on-demand)

    @MainActor
    private func startMetadataObservation() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)

        let finish = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.metadataResultsChanged(query: query)
        }
        let update = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.metadataResultsChanged(query: query)
        }

        metadataObservers = [finish, update]
        metadataQuery = query
        query.start()
    }

    @MainActor
    private func metadataResultsChanged(query: NSMetadataQuery) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var pending = 0
        for case let item as NSMetadataItem in query.results {
            let downloaded = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            let isUploading = (item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool) ?? false
            let isDownloading = (item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool) ?? false

            if downloaded == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
               let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                pending += 1
            }
            if isUploading || isDownloading { pending += 1 }
        }

        status = pending > 0 ? .syncing : .upToDate
    }
}
