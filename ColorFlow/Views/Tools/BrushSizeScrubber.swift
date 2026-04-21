import SwiftUI

/// A vertical, Pigment-style brush-size scrubber.
///
/// Design:
/// - Drag the thumb up for larger brushes, down for smaller. A quadratic
///   response curve gives more resolution at small sizes (where the visual
///   difference between 1pt and 3pt matters more than between 40pt and 50pt).
/// - The thumb diameter is the live preview of the brush tip, clamped for
///   display so very large sizes don't blow out the rail.
/// - A floating "Npt" bubble appears next to the thumb while dragging.
/// - Per-integer selection haptics on a physical device.
struct BrushSizeScrubber: View {
    @Binding var size: CGFloat

    private let trackHeight: CGFloat = 140
    private let trackWidth: CGFloat = 16
    private let thumbDisplayRange: ClosedRange<CGFloat> = 2...24

    @State private var isDragging = false
    @State private var lastHapticTick: Int = 0

    var body: some View {
        let range = BrushSettings.sizeRange
        let fraction = normalize(size, in: range)

        ZStack(alignment: .bottom) {
            // Track
            Capsule()
                .fill(.regularMaterial)
                .frame(width: trackWidth, height: trackHeight)
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

            // Filled portion bottom-up
            Capsule()
                .fill(AppTheme.Brand.accent.opacity(0.65))
                .frame(width: trackWidth, height: max(trackWidth, trackHeight * fraction))

            // Thumb
            thumb
                .offset(y: -trackHeight * fraction + trackWidth / 2)
                .overlay(alignment: .trailing) {
                    if isDragging {
                        Text("\(Int(size))pt")
                            .font(Font.cfCaption)
                            .foregroundStyle(AppTheme.Ink.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.Surface.elevated))
                            .offset(x: 42)
                            .transition(.opacity)
                    }
                }
        }
        .frame(width: trackWidth, height: trackHeight)
        .contentShape(Rectangle().inset(by: -12))
        .gesture(drag(range: range))
        .sensoryFeedback(.selection, trigger: Int(size))
        .accessibilityIdentifier("brush.scrubber")
        .accessibilityLabel("Brush size")
        .accessibilityValue("\(Int(size)) points")
    }

    // MARK: - Thumb

    private var thumb: some View {
        let diameter = displayDiameter(for: size)
        return Circle()
            .fill(Color.white)
            .frame(width: diameter, height: diameter)
            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    // MARK: - Gesture

    private func drag(range: ClosedRange<CGFloat>) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let clampedY = min(max(0, trackHeight - value.location.y), trackHeight)
                let f = Double(clampedY / trackHeight)  // 0 at bottom, 1 at top
                let sized = apply(fraction: f, to: range)
                withAnimation(isDragging ? nil : AppTheme.Motion.quickSpring) {
                    isDragging = true
                    size = sized
                }
                let tick = Int(sized)
                if tick != lastHapticTick {
                    lastHapticTick = tick
                }
            }
            .onEnded { _ in
                withAnimation(AppTheme.Motion.quickSpring) {
                    isDragging = false
                }
            }
    }

    // MARK: - Math

    /// Apply a quadratic response curve so small sizes have more resolution.
    private func apply(fraction f: Double, to range: ClosedRange<CGFloat>) -> CGFloat {
        let shaped = f * f  // concave, favors small values
        let lower = Double(range.lowerBound)
        let upper = Double(range.upperBound)
        return CGFloat(lower + (upper - lower) * shaped)
    }

    private func normalize(_ value: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper > lower else { return 0 }
        let linear = (value - lower) / (upper - lower)
        // Invert of the quadratic above: sqrt to read current fraction back.
        return CGFloat(sqrt(max(0, Double(linear))))
    }

    private func displayDiameter(for size: CGFloat) -> CGFloat {
        let range = BrushSettings.sizeRange
        let f = (size - range.lowerBound) / (range.upperBound - range.lowerBound)
        let lower = thumbDisplayRange.lowerBound
        let upper = thumbDisplayRange.upperBound
        return lower + (upper - lower) * f
    }
}
