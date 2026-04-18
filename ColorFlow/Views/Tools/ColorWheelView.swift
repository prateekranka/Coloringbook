import SwiftUI

/// Radial HSB color wheel. Hue is encoded as the angle around the center and
/// saturation as the distance from the center. Brightness is driven externally
/// so the wheel can be darkened/lightened together with the brightness slider.
///
/// A draggable indicator dot tracks the current hue/saturation and updates
/// them live while the user drags.
struct ColorWheelView: View {
    @Binding var hue: Double        // 0...1
    @Binding var saturation: Double // 0...1
    let brightness: Double          // 0...1 — read-only; see `brightness` slider

    var onChange: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2

            ZStack {
                // Conic hue ring
                Circle()
                    .fill(AngularGradient(
                        gradient: Gradient(colors: stride(from: 0.0, through: 1.0, by: 0.05)
                            .map { Color(hue: $0, saturation: 1, brightness: 1) }),
                        center: .center))

                // Radial saturation fade (white center → transparent edge).
                // Combined with the hue ring this produces the classic HSB wheel.
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hue: 0, saturation: 0, brightness: 1),
                            Color(hue: 0, saturation: 0, brightness: 1).opacity(0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: radius))

                // Brightness overlay — darkens the wheel when brightness < 1.
                // Crucially we keep this AT MOST 60% so the wheel never disappears
                // and the user can always see the hue they are picking.
                Circle()
                    .fill(Color.black.opacity(max(0, (1 - brightness)) * 0.6))

                // Indicator dot at the current (hue, saturation).
                IndicatorDot(
                    hue: hue, saturation: saturation, brightness: brightness,
                    radius: radius
                )
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateHSB(from: value.location, radius: radius, center: CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2))
                    }
                    .onEnded { _ in onChange?() }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Color wheel")
        .accessibilityHint("Drag to pick a hue and saturation")
    }

    private func updateHSB(from point: CGPoint, radius: CGFloat, center: CGPoint) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let clampedDistance = min(distance, radius)

        // Angle: 0 at 3 o'clock, increasing counterclockwise as standard math angle.
        // We map 0° (3 o'clock) → hue 0 (red) for a familiar red-at-right layout.
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        let newHue = Double(angle / (2 * .pi))
        let newSaturation = Double(clampedDistance / radius)

        hue = newHue
        saturation = newSaturation
        onChange?()
    }
}

// MARK: - Indicator dot

private struct IndicatorDot: View {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let radius: CGFloat

    var body: some View {
        let angle = hue * 2 * .pi
        let distance = saturation * Double(radius)
        let dx = CGFloat(distance * cos(angle))
        let dy = CGFloat(distance * sin(angle))

        Circle()
            .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            .offset(x: dx, y: dy)
            .allowsHitTesting(false)
    }
}
