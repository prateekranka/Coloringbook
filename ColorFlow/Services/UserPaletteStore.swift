import SwiftUI
import Observation

/// Stores the user's personal color palette — colors they've explicitly pinned
/// from the picker. Backed by UserDefaults as a JSON-encoded array of hex
/// strings. Capped so the palette stays visually manageable.
@MainActor
@Observable
final class UserPaletteStore {
    static let shared = UserPaletteStore()

    static let maxColors = 24
    private static let storageKey = "userPalette.hexColors"

    private(set) var colors: [Color] = []

    private init() {
        load()
    }

    /// Adds a color to the top of the palette (moves it to the front if already
    /// present). Drops the oldest entry past `maxColors`.
    func add(_ color: Color) {
        let hex = UIColor(color).hexString
        var hexList = colors.map { UIColor($0).hexString }
        hexList.removeAll { $0.caseInsensitiveCompare(hex) == .orderedSame }
        hexList.insert(hex, at: 0)
        if hexList.count > Self.maxColors {
            hexList = Array(hexList.prefix(Self.maxColors))
        }
        persist(hexList)
    }

    func remove(_ color: Color) {
        let hex = UIColor(color).hexString
        var hexList = colors.map { UIColor($0).hexString }
        hexList.removeAll { $0.caseInsensitiveCompare(hex) == .orderedSame }
        persist(hexList)
    }

    func contains(_ color: Color) -> Bool {
        let hex = UIColor(color).hexString
        return colors.contains {
            UIColor($0).hexString.caseInsensitiveCompare(hex) == .orderedSame
        }
    }

    // MARK: - Persistence

    private func load() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? "[]"
        guard let data = raw.data(using: .utf8),
              let hexArray = try? JSONDecoder().decode([String].self, from: data) else { return }
        colors = hexArray.map { Color(hex: $0) }
    }

    private func persist(_ hexList: [String]) {
        if let data = try? JSONEncoder().encode(hexList),
           let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: Self.storageKey)
        }
        colors = hexList.map { Color(hex: $0) }
    }
}
