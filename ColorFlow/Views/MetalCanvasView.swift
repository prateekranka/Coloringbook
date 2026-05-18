import SwiftUI
import MetalKit

struct MetalCanvasView: UIViewRepresentable {
    @Bindable var viewModel: ColoringSessionViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> MetalCanvasInteractionView {
        let interactionView = MetalCanvasInteractionView()
        interactionView.coordinator = context.coordinator

        let mtkView = MTKView(frame: .zero, device: context.coordinator.renderer.device)
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 120
        mtkView.isOpaque = false
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0.996, green: 0.992, blue: 0.973, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        interactionView.mtkView = mtkView
        interactionView.insertSubview(mtkView, at: 0)

        context.coordinator.mtkView = mtkView

        return interactionView
    }

    func updateUIView(_ interactionView: MetalCanvasInteractionView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.brush = BrushConfiguration(
            from: viewModel.selectedTool,
            settings: viewModel.selectedToolSettings,
            colorHex: viewModel.selectedColorHex
        )
        interactionView.coordinator = context.coordinator
        context.coordinator.mtkView?.setNeedsDisplay()
    }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        let renderer: MetalBrushRenderer
        var viewModel: ColoringSessionViewModel
        var brush: BrushConfiguration
        weak var mtkView: MTKView?

        init(viewModel: ColoringSessionViewModel) {
            self.viewModel = viewModel
            self.renderer = MetalBrushRenderer()
            self.brush = BrushConfiguration(
                from: viewModel.selectedTool,
                settings: viewModel.selectedToolSettings,
                colorHex: viewModel.selectedColorHex
            )
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.ensureAccumulationTexture(size: size)
        }

        func draw(in view: MTKView) {
            renderer.renderAccumulated(to: view)
        }

        func addStrokePoint(_ point: StrokePoint) {
            renderer.addStrokePoint(point, brush: brush)
            mtkView?.setNeedsDisplay()
        }

        func beginStroke() {
            renderer.beginStroke()
        }

        func endStroke() {
            let smoothed = renderer.endStroke()
            let samples = smoothed.map { sample in
                StrokeSample(
                    point: CodablePoint(x: Double(sample.position.x), y: Double(sample.position.y)),
                    timestamp: sample.timestamp,
                    force: Double(sample.pressure),
                    altitude: sample.altitude.map(Double.init),
                    azimuth: sample.azimuth.map(Double.init)
                )
            }
            viewModel.endMetalStroke(samples: samples)
            renderer.commitStroke(brush: brush, viewportSize: mtkView?.drawableSize ?? .zero)
            mtkView?.setNeedsDisplay()
        }
    }
}

final class MetalCanvasInteractionView: UIView {
    weak var coordinator: MetalCanvasView.Coordinator?
    weak var mtkView: MTKView?
    private var strokeSamples: [StrokeSample] = []

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard coordinator != nil else { return }

        for touch in touches {
            if touch.type == .pencil {
                handlePencilBegan(touch: touch, event: event)
            } else if touch.type == .direct {
                handleFingerBegan(touch: touch)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard coordinator != nil else { return }

        for touch in touches {
            if touch.type == .pencil {
                handlePencilMoved(touch: touch, event: event)
            } else if touch.type == .direct {
                handleFingerMoved(touch: touch)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard coordinator != nil else { return }

        for touch in touches {
            if touch.type == .pencil {
                handlePencilEnded(touch: touch)
            } else if touch.type == .direct {
                handleFingerEnded(touch: touch)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let coordinator else { return }
        strokeSamples.removeAll()
        coordinator.viewModel.cancelMetalStroke()
        coordinator.renderer.clearLiveStroke()
        mtkView?.setNeedsDisplay()
    }

    private func handlePencilBegan(touch: UITouch, event: UIEvent?) {
        guard let coordinator else { return }
        coordinator.beginStroke()
        let point = strokePoint(from: touch)
        coordinator.addStrokePoint(point)
        strokeSamples = [strokeSample(from: touch)]
        coordinator.viewModel.beginMetalStroke(samples: strokeSamples)
    }

    private func handlePencilMoved(touch: UITouch, event: UIEvent?) {
        guard let coordinator else { return }
        let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
        for coalescedTouch in coalesced where coalescedTouch.type == .pencil {
            let point = strokePoint(from: coalescedTouch)
            coordinator.addStrokePoint(point)
            let sample = strokeSample(from: coalescedTouch)
            strokeSamples.append(sample)
        }
        coordinator.viewModel.appendMetalStroke(samples: strokeSamples)
    }

    private func handlePencilEnded(touch: UITouch) {
        guard let coordinator else { return }
        let point = strokePoint(from: touch)
        coordinator.addStrokePoint(point)
        let sample = strokeSample(from: touch)
        strokeSamples.append(sample)
        coordinator.endStroke()
        strokeSamples.removeAll()
    }

    private func handleFingerBegan(touch: UITouch) {
        guard let coordinator else { return }
        coordinator.beginStroke()
        let point = StrokePoint(
            position: touch.location(in: self),
            pressure: 1.0,
            timestamp: touch.timestamp
        )
        coordinator.addStrokePoint(point)
        strokeSamples = [StrokeSample(point: point.position, timestamp: touch.timestamp)]
        coordinator.viewModel.beginMetalStroke(samples: strokeSamples)
    }

    private func handleFingerMoved(touch: UITouch) {
        guard let coordinator else { return }
        let point = StrokePoint(
            position: touch.location(in: self),
            pressure: 1.0,
            timestamp: touch.timestamp
        )
        coordinator.addStrokePoint(point)
        let sample = StrokeSample(point: point.position, timestamp: touch.timestamp)
        strokeSamples.append(sample)
        coordinator.viewModel.appendMetalStroke(samples: [sample])
    }

    private func handleFingerEnded(touch: UITouch) {
        guard let coordinator else { return }
        let point = StrokePoint(
            position: touch.location(in: self),
            pressure: 1.0,
            timestamp: touch.timestamp
        )
        coordinator.addStrokePoint(point)
        let sample = StrokeSample(point: point.position, timestamp: touch.timestamp)
        strokeSamples.append(sample)
        coordinator.endStroke()
        strokeSamples.removeAll()
    }

    private func strokePoint(from touch: UITouch) -> StrokePoint {
        let location = touch.location(in: self)
        let normalizedForce: Float
        if touch.maximumPossibleForce > 0 {
            normalizedForce = Float(touch.force / touch.maximumPossibleForce)
        } else {
            normalizedForce = 1.0
        }
        return StrokePoint(
            position: location,
            pressure: normalizedForce,
            timestamp: touch.timestamp,
            altitude: Float(touch.altitudeAngle),
            azimuth: Float(touch.azimuthAngle(in: self))
        )
    }

    private func strokeSample(from touch: UITouch) -> StrokeSample {
        let location = touch.location(in: self)
        let normalizedForce: Double?
        if touch.maximumPossibleForce > 0 {
            normalizedForce = Double(touch.force / touch.maximumPossibleForce)
        } else {
            normalizedForce = nil
        }
        return StrokeSample(
            point: CodablePoint(x: Double(location.x), y: Double(location.y)),
            timestamp: touch.timestamp,
            force: normalizedForce,
            altitude: Double(touch.altitudeAngle),
            azimuth: Double(touch.azimuthAngle(in: self))
        )
    }
}