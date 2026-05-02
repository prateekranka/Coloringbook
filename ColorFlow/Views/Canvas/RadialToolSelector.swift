import SwiftUI
import UIKit

/// Press-to-summon radial tool selector.
///
/// Triggered by long-press on the canvas: an iOS-style magnifier loupe shows
/// the area under the press, and a radial fan of drawing tools blooms around
/// the touch point. Drag to a tool to select; release anywhere to commit.
///
/// Replaces the prior two-row liquid-glass dock — keeps the liquid-glass feel
/// (translucent capsules, hairline strokes) but moves the chrome out of the
/// way until the user reaches for it.
struct RadialToolSelector: View {
    @Binding var isPresented: Bool
    let center: CGPoint
    let canvasSnapshot: UIImage?
    let canvasSize: CGSize
    let tools: [DrawingTool]
    let activeTool: DrawingTool
    let onSelect: (DrawingTool) -> Void

    @State private var bloom: CGFloat = 0
    @State private var hoveredTool: DrawingTool? = nil

    private let radius: CGFloat = 120
    private let buttonSize: CGFloat = 56
    private let loupeRadius: CGFloat = 52
    private let loupeOffset: CGFloat = 96   // loupe rises above the fingertip
    private let loupeMagnification: CGFloat = 1.6

    var body: some View {
        ZStack {
            // Dimmed scrim so the radial fan reads against any canvas content.
            // Tap outside to dismiss; any selection commits via the tool buttons.
            Color.black.opacity(0.18 * Double(bloom))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            // iOS-style magnifier loupe above the touch point.
            loupe
                .position(x: center.x, y: max(loupeRadius + 8, center.y - loupeOffset))
                .opacity(Double(bloom))
                .scaleEffect(0.6 + 0.4 * bloom, anchor: .bottom)

            // Radial fan of tool buttons.
            ForEach(Array(tools.enumerated()), id: \.element) { index, tool in
                toolButton(tool: tool, at: position(for: index, total: tools.count))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                bloom = 1
            }
        }
    }

    // MARK: - Loupe

    private var loupe: some View {
        ZStack {
            // Magnified slice of the canvas, masked to a circle.
            Group {
                if let canvasSnapshot {
                    Image(uiImage: canvasSnapshot)
                        .resizable()
                        .frame(width: canvasSize.width * loupeMagnification,
                               height: canvasSize.height * loupeMagnification)
                        .offset(
                            x: -center.x * loupeMagnification + loupeRadius,
                            y: -center.y * loupeMagnification + loupeRadius
                        )
                        .frame(width: loupeRadius * 2, height: loupeRadius * 2, alignment: .topLeading)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(.regularMaterial)
                }
            }
            // Crosshair to anchor the eye on the press point.
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                .frame(width: 8, height: 8)

            // Glassy rim — matches the liquid-glass language of the canvas chrome.
            Circle()
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
            Circle()
                .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
        }
        .frame(width: loupeRadius * 2, height: loupeRadius * 2)
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    // MARK: - Tool buttons

    @ViewBuilder
    private func toolButton(tool: DrawingTool, at point: CGPoint) -> some View {
        let isActive = tool == activeTool
        let isHovered = tool == hoveredTool

        Button {
            onSelect(tool)
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                Circle()
                    .strokeBorder(AppTheme.Stroke.hairline, lineWidth: 0.5)
                if isActive || isHovered {
                    Circle()
                        .fill(AppTheme.Brand.accent.opacity(isHovered ? 1.0 : 0.18))
                }
                Image(systemName: tool.systemImageName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        (isActive || isHovered) ? AppTheme.Brand.onAccent : AppTheme.Ink.primary
                    )
            }
            .frame(width: buttonSize, height: buttonSize)
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .scaleEffect(isHovered ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .position(
            x: center.x + (point.x - center.x) * bloom,
            y: center.y + (point.y - center.y) * bloom
        )
        .opacity(Double(bloom))
        .accessibilityLabel(tool.rawValue)
    }

    // MARK: - Geometry

    /// Evenly fan tools across the upper hemisphere (270° arc, biased upward
    /// so the user's hand doesn't occlude the choices).
    private func position(for index: Int, total: Int) -> CGPoint {
        let arc: Double = .pi * 1.4   // 252°
        let start: Double = -.pi / 2 - arc / 2
        let step = total > 1 ? arc / Double(total - 1) : 0
        let angle = start + step * Double(index)
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            bloom = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPresented = false
        }
    }
}
