import SwiftUI
import PencilKit

/// UIViewRepresentable wrapping PKCanvasView.
/// Finger gestures scroll/zoom the canvas; only Apple Pencil draws.
struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var tool: PKTool
    var onDrawingChanged: (() -> Void)?
    var onCanvasReady: ((PKCanvasView) -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.tool = tool
        canvas.drawingPolicy = .pencilOnly   // fingers → scroll/zoom
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator

        // ProMotion 120fps
        canvas.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)

        DispatchQueue.main.async {
            onCanvasReady?(canvas)
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.tool !== tool as AnyObject {
            canvas.tool = tool
        }
        // Only push drawing back if external undo changed it
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasRepresentable

        init(_ parent: PencilCanvasRepresentable) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onDrawingChanged?()
        }
    }
}
