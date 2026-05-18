import SwiftUI
import MetalKit

struct MetalCanvasView: UIViewRepresentable {
    @Binding var strokePoints: [StrokePoint]
    var brush: BrushConfiguration
    var backgroundColor: UIColor = UIColor(red: 1.0, green: 0.992, blue: 0.973, alpha: 1.0)

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: context.coordinator.renderer.device)
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 120
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

    override init() {
        self.renderer = try! MetalBrushRenderer()
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.ensureAccumulationTexture(size: size)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        renderer.renderLiveStroke(
            points: strokePoints,
            brush: brush,
            to: drawable,
            viewportSize: view.drawableSize
        )
    }
}
