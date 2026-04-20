import Foundation

@MainActor
@Observable
final class CanvasSettings {
    var stayInTheLines: Bool {
        didSet {
            UserDefaults.standard.set(stayInTheLines, forKey: Self.stayInTheLinesKey)
        }
    }

    init() {
        self.stayInTheLines = UserDefaults.standard.object(forKey: Self.stayInTheLinesKey) as? Bool ?? true
    }

    private static let stayInTheLinesKey = "canvas.stayInTheLines"
}
