import SwiftUI

/// The glowing radial "flower" of swatches, framed by a hue ring.
/// Selection flows up to the parent via `selectedColor` binding.
struct FlowerWheelView: View {
    @Binding var selectedColor: Color
    let mode: FlowerMode
    let onLongPressSwatch: (Color) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = CGSize(
                width: min(geo.size.width, geo.size.height),
                height: min(geo.size.width, geo.size.height)
            )
            let slots = WheelGeometry.slots(for: mode, in: size)

            let haloID = nearestSlotID(in: slots)

            ZStack {
                // Hue ring sits just outside the swatches.
                HueRingView(selectedColor: $selectedColor)
                    .frame(width: size.width, height: size.height)

                ZStack {
                    ForEach(slots) { slot in
                        SwatchNode(
                            color: slot.color,
                            radius: slot.radius,
                            isSelected: slot.id == haloID,
                            appearanceDelay: delay(for: slot),
                            onTap: { select(slot.color) },
                            onLongPress: { onLongPressSwatch(slot.color) }
                        )
                        .sensoryFeedback(.selection, trigger: slot.id == haloID)
                        .position(slot.center)
                    }
                }
                .frame(width: size.width, height: size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    /// Pick the slot whose color is closest to `selectedColor` in HSB space,
    /// so the halo always lands on a real swatch even when the bound color
    /// came from outside the wheel (e.g. recents / hue scrubber).
    private func nearestSlotID(in slots: [SwatchSlot]) -> String? {
        let selectedHex = UIColor(selectedColor).hexString
        if let exact = slots.first(where: { UIColor($0.color).hexString == selectedHex }) {
            return exact.id
        }

        let (sh, ss, sb) = selectedColor.hsb

        var bestID: String?
        var bestDistance = Double.infinity
        for slot in slots {
            let (h, s, b) = slot.color.hsb
            let dh = min(abs(h - sh), 1 - abs(h - sh))
            let distance = hypot(hypot(dh, s - ss), b - sb)
            if distance < bestDistance {
                bestDistance = distance
                bestID = slot.id
            }
        }
        return bestID
    }

    private func select(_ color: Color) {
        withAnimation(AppTheme.Motion.quickSpring) {
            selectedColor = color
        }
    }

    private func delay(for slot: SwatchSlot) -> Double {
        if reduceMotion { return 0 }
        return Double(slot.ring) * 0.06 + Double(slot.angleIndex) * AppTheme.Motion.staggerBase
    }
}
