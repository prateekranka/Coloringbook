import SwiftUI

enum StampShape: String, CaseIterable, Identifiable, Codable {
    case star = "Star"
    case heart = "Heart"
    case circle = "Circle"
    case diamond = "Diamond"
    case flower = "Flower"

    var id: String { rawValue }
    var systemImageName: String {
        switch self {
        case .star: return "star.fill"
        case .heart: return "heart.fill"
        case .circle: return "circle.fill"
        case .diamond: return "diamond.fill"
        case .flower: return "camera.macro"
        }
    }

    /// Returns a CGPath centered at origin with the given radius.
    func path(radius: CGFloat) -> CGPath {
        switch self {
        case .star: return starPath(radius: radius)
        case .heart: return heartPath(radius: radius)
        case .circle:
            return CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        case .diamond: return diamondPath(radius: radius)
        case .flower: return flowerPath(radius: radius)
        }
    }

    private func starPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = 5
        let innerRadius = radius * 0.4
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let r = i % 2 == 0 ? radius : innerRadius
            let pt = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func heartPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let s = radius
        path.move(to: CGPoint(x: 0, y: s * 0.4))
        path.addCurve(to: CGPoint(x: 0, y: -s * 0.6),
                      control1: CGPoint(x: -s * 1.2, y: s * 0.0),
                      control2: CGPoint(x: -s * 1.2, y: -s * 0.8))
        path.addCurve(to: CGPoint(x: 0, y: -s * 0.2),
                      control1: CGPoint(x: 0, y: -s * 1.0),
                      control2: CGPoint(x: 0, y: -s * 0.6))
        path.addCurve(to: CGPoint(x: 0, y: -s * 0.6),
                      control1: CGPoint(x: s * 1.2, y: -s * 1.0),
                      control2: CGPoint(x: s * 1.2, y: -s * 0.8))
        path.addCurve(to: CGPoint(x: 0, y: s * 0.4),
                      control1: CGPoint(x: s * 1.2, y: s * 0.0),
                      control2: CGPoint(x: s * 0.0, y: s * 0.4))
        path.closeSubpath()
        return path
    }

    private func diamondPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: radius * 0.6, y: 0))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: -radius * 0.6, y: 0))
        path.closeSubpath()
        return path
    }

    private func flowerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let petals = 6
        for i in 0..<petals {
            let angle = CGFloat(i) * 2 * .pi / CGFloat(petals)
            let cx = cos(angle) * radius * 0.5
            let cy = sin(angle) * radius * 0.5
            path.addEllipse(in: CGRect(x: cx - radius * 0.35, y: cy - radius * 0.35,
                                       width: radius * 0.7, height: radius * 0.7))
        }
        path.addEllipse(in: CGRect(x: -radius * 0.3, y: -radius * 0.3,
                                   width: radius * 0.6, height: radius * 0.6))
        return path
    }
}
