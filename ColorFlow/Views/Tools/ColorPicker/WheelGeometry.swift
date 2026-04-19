import SwiftUI

/// Modes the flower wheel can render in.
enum FlowerMode: Equatable {
    case spectrum
    case palette(ColorPalette)

    static func == (lhs: FlowerMode, rhs: FlowerMode) -> Bool {
        switch (lhs, rhs) {
        case (.spectrum, .spectrum): return true
        case let (.palette(a), .palette(b)): return a.id == b.id
        default: return false
        }
    }
}

/// One swatch position in the wheel.
struct SwatchSlot: Identifiable {
    let id: String
    let ring: Int           // 0 = center, 1 = inner, 2 = middle, 3 = outer
    let angleIndex: Int
    let center: CGPoint
    let radius: CGFloat
    let color: Color
}

/// Pure geometry: given a mode + canvas size, produce the layout of swatches.
/// No SwiftUI state — easy to unit test and cache.
enum WheelGeometry {
    /// Ring multipliers relative to the wheel's outer radius.
    private static let ringDistances: [CGFloat] = [0.0, 0.24, 0.50, 0.76]
    /// Swatch radius per ring, relative to outer radius.
    private static let ringSwatchRadii: [CGFloat] = [0.16, 0.14, 0.13, 0.135]
    /// Count of swatches per ring. Ring 0 = single center swatch.
    private static let ringCounts: [Int] = [1, 6, 12, 12]

    static func slots(for mode: FlowerMode, in size: CGSize) -> [SwatchSlot] {
        let outerRadius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var result: [SwatchSlot] = []

        for ring in 0..<ringCounts.count {
            let count = ringCounts[ring]
            let ringRadius = outerRadius * ringDistances[ring]
            let swatchRadius = outerRadius * ringSwatchRadii[ring]
            // Offset alternate rings by half a step so swatches interlock.
            let angleOffset = (ring % 2 == 0) ? 0.0 : (.pi / Double(count))

            for i in 0..<count {
                let angle = angleOffset + (Double(i) / Double(count)) * 2 * .pi - .pi / 2
                let cx = center.x + CGFloat(cos(angle)) * ringRadius
                let cy = center.y + CGFloat(sin(angle)) * ringRadius
                let color = colorFor(mode: mode, ring: ring, angleIndex: i, totalInRing: count)
                result.append(SwatchSlot(
                    id: "\(ring)-\(i)",
                    ring: ring,
                    angleIndex: i,
                    center: CGPoint(x: cx, y: cy),
                    radius: swatchRadius,
                    color: color
                ))
            }
        }
        return result
    }

    // MARK: - Color mapping

    private static func colorFor(mode: FlowerMode, ring: Int, angleIndex: Int, totalInRing: Int) -> Color {
        switch mode {
        case .spectrum:
            return spectrumColor(ring: ring, angleIndex: angleIndex, totalInRing: totalInRing)
        case .palette(let palette):
            return paletteColor(palette: palette, ring: ring, angleIndex: angleIndex, totalInRing: totalInRing)
        }
    }

    private static func spectrumColor(ring: Int, angleIndex: Int, totalInRing: Int) -> Color {
        if ring == 0 { return .white }
        let hue = Double(angleIndex) / Double(totalInRing)
        // Saturation increases outward, brightness decreases subtly at ring 3.
        let (s, b): (Double, Double) = {
            switch ring {
            case 1: return (0.35, 1.0)
            case 2: return (0.65, 1.0)
            case 3: return (1.00, 0.95)
            default: return (0.8, 1.0)
            }
        }()
        return Color(hue: hue, saturation: s, brightness: b)
    }

    private static func paletteColor(palette: ColorPalette, ring: Int, angleIndex: Int, totalInRing: Int) -> Color {
        guard !palette.swatches.isEmpty else { return .white }
        if ring == 0 { return .white }
        // Pick the base palette swatch for this angular slot.
        let base = palette.swatches[angleIndex % palette.swatches.count].color
        let (h, s, b) = base.hsb
        switch ring {
        case 1: return Color(h: h, s: max(0, s - 0.35), b: min(1, b + 0.12))  // lighter tint
        case 2: return base                                                    // palette truth
        case 3: return Color(h: h, s: min(1, s + 0.1),  b: max(0.35, b - 0.2)) // deeper shade
        default: return base
        }
    }
}
