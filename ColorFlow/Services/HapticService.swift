import UIKit

/// Centralized haptic feedback service. Use the semantic APIs (`strokeEnd`,
/// `fillApplied`, etc.) rather than raw `impact(...)` at call sites so the feel
/// of the app can be tuned in one place.
@MainActor
final class HapticService {
    static let shared = HapticService()
    private init() {}

    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let impactRigid  = UIImpactFeedbackGenerator(style: .rigid)
    private let impactSoft   = UIImpactFeedbackGenerator(style: .soft)
    private let selection    = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    // MARK: - Raw APIs

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        switch style {
        case .light:  impactLight.impactOccurred()
        case .medium: impactMedium.impactOccurred()
        case .heavy:  impactHeavy.impactOccurred()
        case .rigid:  impactRigid.impactOccurred()
        case .soft:   impactSoft.impactOccurred()
        @unknown default: impactLight.impactOccurred()
        }
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
    }

    // MARK: - Semantic APIs

    /// Tool changed (pencil → marker, etc.).
    func toolChanged()      { impactLight.impactOccurred() }

    /// Palette or color swatch changed.
    func paletteChanged()   { impactSoft.impactOccurred() }

    /// A region has just been flood-filled.
    func fillApplied()      { impactLight.impactOccurred() }

    /// Undo/redo action fired.
    func undoRedo()         { impactRigid.impactOccurred() }

    /// A Pencil stroke ended. Kept intentionally subtle.
    func strokeEnd()        { selection.selectionChanged() }

    /// A swipe/selection crossed a new boundary (e.g. category filter).
    func selectionMoved()   { selection.selectionChanged() }

    /// Project crossed the "mostly complete" threshold — celebration.
    func projectCompleted() { notification.notificationOccurred(.success) }

    /// An action failed or was blocked.
    func actionFailed()     { notification.notificationOccurred(.warning) }
}
