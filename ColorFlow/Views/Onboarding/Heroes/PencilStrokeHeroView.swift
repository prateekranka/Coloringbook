import SwiftUI

/// Step 2 hero: a bezier stroke draws itself along a path, holds, then erases.
/// Uses PhaseAnimator (iOS 17+) for a clean draw-hold-erase loop.
struct PencilStrokeHeroView: View {
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background reference squiggle (faint)
            SquigglePath()
                .stroke(AppTheme.textPrimary.opacity(0.12), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: 260, height: 160)

            if reduceMotion {
                SquigglePath()
                    .trim(from: 0, to: 1)
                    .stroke(
                        LinearGradient(colors: [accent, accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 260, height: 160)
                    .glow(color: accent.opacity(0.55), radius: 16)
            } else {
                PhaseAnimator([0.0, 1.0, 1.0, 0.0]) { progress in
                    SquigglePath()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [accent, accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 260, height: 160)
                        .glow(color: accent.opacity(0.55), radius: 16)
                } animation: { phase in
                    switch phase {
                    case 0.0: return .easeInOut(duration: 1.6)
                    case 1.0: return .easeInOut(duration: 0.8)
                    default:  return .easeInOut(duration: 1.2)
                    }
                }
            }

            // Tiny tip highlight that "follows" the stroke end for flavor
            if !reduceMotion {
                PhaseAnimator([CGFloat(0.02), 1.0, 1.0, 0.02]) { progress in
                    TipDot(progress: progress)
                        .frame(width: 260, height: 160)
                } animation: { phase in
                    switch phase {
                    case 0.02: return .easeInOut(duration: 1.6)
                    default:   return .easeInOut(duration: 1.2)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// A friendly wave/squiggle centered in its frame.
private struct SquigglePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0.05 * w, y: 0.55 * h))
        p.addCurve(
            to: CGPoint(x: 0.40 * w, y: 0.55 * h),
            control1: CGPoint(x: 0.15 * w, y: 0.05 * h),
            control2: CGPoint(x: 0.30 * w, y: 1.05 * h)
        )
        p.addCurve(
            to: CGPoint(x: 0.95 * w, y: 0.45 * h),
            control1: CGPoint(x: 0.55 * w, y: 0.10 * h),
            control2: CGPoint(x: 0.80 * w, y: 0.95 * h)
        )
        return p
    }
}

/// A small glowing dot at the current end of the stroke, so the line feels alive.
private struct TipDot: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let point = pointOnSquiggle(progress: progress, in: geo.size)
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .position(point)
                .glow(color: .white.opacity(0.85), radius: 10)
                .opacity(progress > 0.02 && progress < 1 ? 1 : 0)
        }
    }

    private func pointOnSquiggle(progress: CGFloat, in size: CGSize) -> CGPoint {
        // Sample the parametric curve (matches SquigglePath roughly)
        let t = progress
        let w = size.width, h = size.height
        // Linear interpolation along the two cubic segments isn't exact, but
        // close enough for a decorative dot.
        if t < 0.5 {
            let u = t * 2
            let x = bezier(u, 0.05 * w, 0.15 * w, 0.30 * w, 0.40 * w)
            let y = bezier(u, 0.55 * h, 0.05 * h, 1.05 * h, 0.55 * h)
            return CGPoint(x: x, y: y)
        } else {
            let u = (t - 0.5) * 2
            let x = bezier(u, 0.40 * w, 0.55 * w, 0.80 * w, 0.95 * w)
            let y = bezier(u, 0.55 * h, 0.10 * h, 0.95 * h, 0.45 * h)
            return CGPoint(x: x, y: y)
        }
    }

    private func bezier(_ t: CGFloat, _ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat) -> CGFloat {
        let u = 1 - t
        return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
    }
}
