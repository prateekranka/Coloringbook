import SwiftUI

public struct WatercolorBrushToolIcon: View {
    @Environment(\.colorScheme) private var colorScheme

    public let selectedColor: Color
    public let isSelected: Bool

    public init(selectedColor: Color, isSelected: Bool) {
        self.selectedColor = selectedColor
        self.isSelected = isSelected
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let outlineWidth = max(0.8, size * 0.034)
            let detailWidth = max(0.35, size * 0.012)
            let graphite = colorScheme == .dark
                ? Color(red: 0.84, green: 0.78, blue: 0.69)
                : Color(red: 0.21, green: 0.20, blue: 0.18)
            let inactiveStroke = colorScheme == .dark
                ? Color(red: 0.76, green: 0.70, blue: 0.62).opacity(0.55)
                : Color(red: 0.45, green: 0.43, blue: 0.39).opacity(0.68)
            let ivory = colorScheme == .dark
                ? Color(red: 0.75, green: 0.68, blue: 0.57)
                : Color(red: 0.93, green: 0.89, blue: 0.79)
            let warmIvory = colorScheme == .dark
                ? Color(red: 0.86, green: 0.78, blue: 0.66)
                : Color(red: 0.99, green: 0.95, blue: 0.86)
            let handleGraphite = colorScheme == .dark
                ? Color(red: 0.39, green: 0.37, blue: 0.33)
                : Color(red: 0.30, green: 0.29, blue: 0.26)
            let shadow = Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
            let highlight = colorScheme == .dark
                ? Color(red: 0.97, green: 0.90, blue: 0.78).opacity(0.16)
                : Color(red: 1.00, green: 0.98, blue: 0.91).opacity(0.42)

            ZStack {
                if isSelected {
                    Ellipse()
                        .fill(shadow.opacity(0.58))
                        .frame(width: proxy.size.width * 0.28, height: proxy.size.height * 0.045)
                        .blur(radius: max(0.45, size * 0.018))
                        .offset(x: proxy.size.width * 0.015, y: proxy.size.height * 0.435)

                    WatercolorBrushHandleShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    handleGraphite.opacity(0.86),
                                    handleGraphite.opacity(0.58),
                                    handleGraphite.opacity(0.92)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay {
                            WatercolorBrushHandleShape()
                                .stroke(graphite.opacity(colorScheme == .dark ? 0.30 : 0.36), lineWidth: outlineWidth * 0.78)
                        }

                    WatercolorBrushFerruleShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ivory.opacity(0.82),
                                    warmIvory,
                                    ivory.opacity(0.78)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay {
                            WatercolorBrushFerruleShape()
                                .stroke(graphite.opacity(colorScheme == .dark ? 0.38 : 0.44), lineWidth: outlineWidth * 0.82)
                        }

                    WatercolorBrushFerruleBandShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    warmIvory.opacity(0.92),
                                    ivory.opacity(0.74),
                                    warmIvory.opacity(0.86)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            WatercolorBrushFerruleBandShape()
                                .stroke(graphite.opacity(colorScheme == .dark ? 0.34 : 0.38), lineWidth: outlineWidth * 0.70)
                        }

                    WatercolorBrushTipShape()
                        .fill(selectedColor.opacity(colorScheme == .dark ? 0.82 : 0.88))
                        .overlay {
                            WatercolorBrushTipHighlightShape()
                                .fill(highlight)
                                .mask(WatercolorBrushTipShape())
                        }
                        .overlay {
                            WatercolorBrushBristleDetailShape()
                                .stroke(
                                    Color(red: 1.0, green: 0.97, blue: 0.90).opacity(colorScheme == .dark ? 0.16 : 0.22),
                                    style: StrokeStyle(lineWidth: detailWidth, lineCap: .round, lineJoin: .round)
                                )
                                .mask(WatercolorBrushTipShape())
                        }
                        .overlay {
                            WatercolorBrushTipShape()
                                .stroke(graphite.opacity(colorScheme == .dark ? 0.48 : 0.62), lineWidth: outlineWidth)
                        }
                        .shadow(color: shadow, radius: max(0.8, size * 0.026), x: 0, y: max(0.45, size * 0.012))
                } else {
                    WatercolorBrushHandleShape()
                        .stroke(inactiveStroke, lineWidth: outlineWidth)
                    WatercolorBrushFerruleShape()
                        .stroke(inactiveStroke, lineWidth: outlineWidth)
                    WatercolorBrushFerruleBandShape()
                        .stroke(inactiveStroke.opacity(0.78), lineWidth: outlineWidth * 0.70)
                    WatercolorBrushTipShape()
                        .stroke(inactiveStroke, lineWidth: outlineWidth)
                    WatercolorBrushBristleDetailShape()
                        .stroke(
                            inactiveStroke.opacity(0.38),
                            style: StrokeStyle(lineWidth: detailWidth, lineCap: .round, lineJoin: .round)
                        )
                        .mask(WatercolorBrushTipShape())
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

private struct WatercolorBrushTipShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.52, y: h * 0.05))
        path.addCurve(
            to: CGPoint(x: w * 0.69, y: h * 0.28),
            control1: CGPoint(x: w * 0.61, y: h * 0.10),
            control2: CGPoint(x: w * 0.69, y: h * 0.20)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.60, y: h * 0.47),
            control1: CGPoint(x: w * 0.70, y: h * 0.37),
            control2: CGPoint(x: w * 0.67, y: h * 0.43)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.42, y: h * 0.48),
            control1: CGPoint(x: w * 0.54, y: h * 0.50),
            control2: CGPoint(x: w * 0.47, y: h * 0.51)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.36, y: h * 0.37),
            control1: CGPoint(x: w * 0.37, y: h * 0.45),
            control2: CGPoint(x: w * 0.35, y: h * 0.41)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.05),
            control1: CGPoint(x: w * 0.37, y: h * 0.24),
            control2: CGPoint(x: w * 0.43, y: h * 0.12)
        )
        path.closeSubpath()
        return path
    }
}

private struct WatercolorBrushFerruleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.36, y: h * 0.38))
        path.addCurve(
            to: CGPoint(x: w * 0.64, y: h * 0.37),
            control1: CGPoint(x: w * 0.44, y: h * 0.48),
            control2: CGPoint(x: w * 0.56, y: h * 0.47)
        )
        path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.70))
        path.addCurve(
            to: CGPoint(x: w * 0.41, y: h * 0.70),
            control1: CGPoint(x: w * 0.54, y: h * 0.72),
            control2: CGPoint(x: w * 0.46, y: h * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

private struct WatercolorBrushFerruleBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.39, y: h * 0.68))
        path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.68))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.63, y: h * 0.72),
            control: CGPoint(x: w * 0.63, y: h * 0.68)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.59, y: h * 0.75),
            control: CGPoint(x: w * 0.62, y: h * 0.75)
        )
        path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.75))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.37, y: h * 0.72),
            control: CGPoint(x: w * 0.38, y: h * 0.75)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.39, y: h * 0.68),
            control: CGPoint(x: w * 0.37, y: h * 0.68)
        )
        path.closeSubpath()
        return path
    }
}

private struct WatercolorBrushHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.40, y: h * 0.73))
        path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.73))
        path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.92))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.53, y: h * 0.96),
            control: CGPoint(x: w * 0.58, y: h * 0.96)
        )
        path.addLine(to: CGPoint(x: w * 0.47, y: h * 0.96))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.41, y: h * 0.92),
            control: CGPoint(x: w * 0.42, y: h * 0.96)
        )
        path.closeSubpath()
        return path
    }
}

private struct WatercolorBrushBristleDetailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.51, y: h * 0.11))
        path.addCurve(
            to: CGPoint(x: w * 0.47, y: h * 0.46),
            control1: CGPoint(x: w * 0.47, y: h * 0.22),
            control2: CGPoint(x: w * 0.45, y: h * 0.34)
        )
        path.move(to: CGPoint(x: w * 0.58, y: h * 0.18))
        path.addCurve(
            to: CGPoint(x: w * 0.54, y: h * 0.45),
            control1: CGPoint(x: w * 0.59, y: h * 0.27),
            control2: CGPoint(x: w * 0.58, y: h * 0.37)
        )
        path.move(to: CGPoint(x: w * 0.43, y: h * 0.27))
        path.addCurve(
            to: CGPoint(x: w * 0.43, y: h * 0.44),
            control1: CGPoint(x: w * 0.41, y: h * 0.34),
            control2: CGPoint(x: w * 0.41, y: h * 0.40)
        )
        return path
    }
}

private struct WatercolorBrushTipHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.58, y: h * 0.13))
        path.addCurve(
            to: CGPoint(x: w * 0.60, y: h * 0.36),
            control1: CGPoint(x: w * 0.64, y: h * 0.22),
            control2: CGPoint(x: w * 0.65, y: h * 0.31)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.53, y: h * 0.44),
            control1: CGPoint(x: w * 0.58, y: h * 0.40),
            control2: CGPoint(x: w * 0.56, y: h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.13),
            control1: CGPoint(x: w * 0.55, y: h * 0.31),
            control2: CGPoint(x: w * 0.57, y: h * 0.21)
        )
        path.closeSubpath()
        return path
    }
}

#Preview("Selected Pigments") {
    HStack(spacing: 18) {
        WatercolorBrushToolIcon(selectedColor: .pink, isSelected: true)
            .frame(width: 44, height: 44)
        WatercolorBrushToolIcon(selectedColor: .blue, isSelected: true)
            .frame(width: 44, height: 44)
        WatercolorBrushToolIcon(selectedColor: .orange, isSelected: true)
            .frame(width: 44, height: 44)
        WatercolorBrushToolIcon(selectedColor: .green, isSelected: true)
            .frame(width: 44, height: 44)
        WatercolorBrushToolIcon(selectedColor: .pink, isSelected: false)
            .frame(width: 44, height: 44)
    }
    .padding(24)
    .background(Color(red: 0.96, green: 0.92, blue: 0.84))
}

#Preview("Dark Mode") {
    HStack(spacing: 18) {
        WatercolorBrushToolIcon(selectedColor: .cyan, isSelected: true)
            .frame(width: 44, height: 44)
        WatercolorBrushToolIcon(selectedColor: .cyan, isSelected: false)
            .frame(width: 44, height: 44)
    }
    .padding(24)
    .background(Color(red: 0.07, green: 0.08, blue: 0.075))
    .environment(\.colorScheme, .dark)
}
