import SwiftUI

/// Outer glowing rim that scrubs through 24 discrete hue stops.
///
/// Design: dragging around the rim snaps to the nearest 15° tick and commits
/// immediately, so flicking feels like "clicking through" colors. Each crossed
/// tick fires a selection haptic.
///
/// S/B are derived from the most recently committed flower-swatch color (not
/// clamped from the bound color's current HSB), so the ring doesn't drag the
/// selection toward desaturation when you've been using recents or brightness.
struct HueRingView: View {
    @Binding var selectedColor: Color

    private let tickCount: Int = 24
    private let lineWidth: CGFloat = 10
    private let indicatorRadius: CGFloat = 7

    /// Index of the last tick we committed, so we only fire haptics on crossings.
    @State private var lastCommittedTick: Int? = nil
    /// Cached S/B captured from `selectedColor` when the drag began.
    @State private var draftSaturation: Double = 1
    @State private var draftBrightness: Double = 1
    /// Current angle (radians) used to position the indicator dot during drag.
    @State private var currentAngle: Double = -.pi / 2

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - lineWidth / 2

            ZStack {
                // Glow behind the ring
                Circle()
                    .stroke(
                        AngularGradient(gradient: Self.hueGradient, center: .center),
                        lineWidth: lineWidth
                    )
                    .blur(radius: 14)
                    .opacity(0.7)
                    .frame(width: size, height: size)

                // The crisp ring
                Circle()
                    .stroke(
                        AngularGradient(gradient: Self.hueGradient, center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)

                // Tick marks (subtle, to communicate discreteness).
                ForEach(0..<tickCount, id: \.self) { i in
                    let angle = tickAngle(for: i)
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 2, height: lineWidth - 2)
                        .offset(y: -radius)
                        .rotationEffect(.radians(angle + .pi / 2))
                }
                .frame(width: size, height: size)

                // Indicator dot — where the current color lives on the rim.
                indicatorDot(radius: radius)
                    .position(indicatorPosition(center: center, radius: radius))
            }
            .contentShape(Circle().inset(by: -lineWidth))
            .sensoryFeedback(.selection, trigger: lastCommittedTick)
            .gesture(ringDrag(center: center))
            .onAppear {
                syncFromSelectedColor()
            }
        }
    }

    // MARK: - Subviews

    private func indicatorDot(radius: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: indicatorRadius * 2, height: indicatorRadius * 2)
            .overlay {
                Circle().stroke(Color.black.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }

    // MARK: - Gesture

    private func ringDrag(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // First change — capture S/B from whatever the bound color is today.
                if lastCommittedTick == nil {
                    syncFromSelectedColor()
                }

                let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                currentAngle = angle
                let tick = nearestTick(for: angle)
                if tick != lastCommittedTick {
                    commit(tick: tick)
                    lastCommittedTick = tick
                }
            }
            .onEnded { _ in
                lastCommittedTick = nil
            }
    }

    private func syncFromSelectedColor() {
        let current: Color = selectedColor
        let (_, s, b) = current.hsb
        draftSaturation = max(s, 0.35)
        draftBrightness = max(b, 0.5)
    }

    private func commit(tick: Int) {
        let hue = Double(tick) / Double(tickCount)
        selectedColor = Color(h: hue, s: draftSaturation, b: draftBrightness)
    }

    // MARK: - Geometry

    /// Angle for the nth tick, with tick 0 at the top (−π/2) going clockwise.
    private func tickAngle(for index: Int) -> Double {
        (Double(index) / Double(tickCount)) * 2 * .pi - .pi / 2
    }

    private func nearestTick(for angle: Double) -> Int {
        // Normalize so tick 0 is at angle −π/2 (top).
        var normalized = (angle + .pi / 2) / (2 * .pi)
        normalized = normalized.truncatingRemainder(dividingBy: 1)
        if normalized < 0 { normalized += 1 }
        return Int(round(normalized * Double(tickCount))) % tickCount
    }

    private func indicatorPosition(center: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(currentAngle)) * radius,
            y: center.y + CGFloat(sin(currentAngle)) * radius
        )
    }

    private static let hueGradient = Gradient(colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
        Color(hue: $0, saturation: 1, brightness: 1)
    })
}
