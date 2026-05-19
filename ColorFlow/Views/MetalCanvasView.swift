import SwiftUI
import MetalKit

struct MetalCanvasView: UIViewRepresentable {
    var strokePoints: [StrokePoint]
    var brush: BrushConfiguration
    var backgroundColor: UIColor = UIColor(red: 1.0, green: 0.992, blue: 0.973, alpha: 1.0)

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.isOpaque = false
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(
            red: Double(backgroundColor.cgColor.components?[0] ?? 1.0),
            green: Double(backgroundColor.cgColor.components?[1] ?? 0.992),
            blue: Double(backgroundColor.cgColor.components?[2] ?? 0.973),
            alpha: Double(backgroundColor.cgColor.alpha)
        )
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.device = context.coordinator.renderer.device
        mtkView.delegate = context.coordinator
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.strokePoints = strokePoints
        context.coordinator.brush = brush
        uiView.setNeedsDisplay()
    }
}

@MainActor
final class Coordinator: NSObject, MTKViewDelegate {
    let renderer: MetalBrushRenderer
    var strokePoints: [StrokePoint] = []
    var brush: BrushConfiguration = BrushConfiguration(brushType: .pencil)
    private var wasDrawingStroke = false

    override init() {
        self.renderer = try! MetalBrushRenderer()
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.mtkView(view, drawableSizeWillChange: size)
    }

    func draw(in view: MTKView) {
        let scale = Double(view.contentScaleFactor)

        // If stroke just ended, commit it to accumulation texture first
        if wasDrawingStroke && strokePoints.isEmpty {
            renderer.commitStroke(brush: brush, viewportSize: view.drawableSize)
        }
        wasDrawingStroke = !strokePoints.isEmpty

        renderer.beginStroke()
        for point in strokePoints {
            var scaledPoint = point
            scaledPoint.position.x *= scale
            scaledPoint.position.y *= scale
            renderer.addStrokePoint(scaledPoint, brush: brush)
        }
        renderer.draw(in: view)
    }
}
