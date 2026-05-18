import SwiftUI
import MetalKit

struct MetalCanvasView: UIViewRepresentable {
    var brush: BrushConfiguration
    var backgroundColor: UIColor = UIColor(red: 1.0, green: 0.992, blue: 0.973, alpha: 1.0)
    var externalRenderer: MetalBrushRenderer?

    func makeCoordinator() -> Coordinator {
        Coordinator(externalRenderer: externalRenderer)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MetalStrokeInputView(frame: .zero, device: context.coordinator.renderer.device)
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 120
        mtkView.isOpaque = false
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0.996, green: 0.992, blue: 0.973, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.enableSetNeedsDisplay = true
        mtkView.coordinator = context.coordinator
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.brush = brush
    }
}

final class MetalStrokeInputView: MTKView {
    weak var coordinator: MetalCanvasView.Coordinator?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first(where: { $0.type == .pencil }) ?? touches.first
        guard let touch else { return }
        coordinator?.beginStroke(with: touch, in: self)
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first(where: { $0.type == .pencil }) ?? touches.first
        guard let touch else { return }
        let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
        for ct in coalescedTouches {
            coordinator?.appendStroke(with: ct, in: self)
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first(where: { $0.type == .pencil }) ?? touches.first
        guard let touch else { return }
        coordinator?.endStroke(with: touch, in: self)
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.contains(where: { $0.type == .pencil }) || !touches.isEmpty else { return }
        coordinator?.cancelStroke()
        setNeedsDisplay()
    }
}

@MainActor
final class Coordinator: NSObject, MTKViewDelegate {
    let renderer: MetalBrushRenderer
    var brush: BrushConfiguration = BrushConfiguration(brushType: .pencil)

    override init() {
        self.renderer = (try? MetalBrushRenderer())!
        super.init()
    }

    init(externalRenderer: MetalBrushRenderer?) {
        self.renderer = externalRenderer ?? (try! MetalBrushRenderer())
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.mtkView(view, drawableSizeWillChange: size)
    }

    func draw(in view: MTKView) {
        renderer.draw(in: view)
    }

    func beginStroke(with touch: UITouch, in view: MetalStrokeInputView) {
        renderer.beginStroke()
        let point = strokePoint(from: touch, in: view)
        renderer.addStrokePoint(point, brush: brush)
    }

    func appendStroke(with touch: UITouch, in view: MetalStrokeInputView) {
        let point = strokePoint(from: touch, in: view)
        renderer.addStrokePoint(point, brush: brush)
    }

    func endStroke(with touch: UITouch, in view: MetalStrokeInputView) {
        let viewportSize = view.drawableSize
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }

        let point = strokePoint(from: touch, in: view)
        renderer.addStrokePoint(point, brush: brush)
        _ = renderer.endStroke()
        renderer.commitStroke(brush: brush, viewportSize: viewportSize)
    }

    func cancelStroke() {
        renderer.beginStroke()
    }

    private func strokePoint(from touch: UITouch, in view: UIView) -> StrokePoint {
        let force: Float
        if touch.maximumPossibleForce > 0 {
            force = Float(touch.force / touch.maximumPossibleForce)
        } else {
            force = 1.0
        }
        return StrokePoint(
            position: touch.location(in: view),
            pressure: force,
            timestamp: touch.timestamp,
            altitude: Float(touch.altitudeAngle),
            azimuth: Float(touch.azimuthAngle(in: view)),
            predicted: false
        )
    }
}
