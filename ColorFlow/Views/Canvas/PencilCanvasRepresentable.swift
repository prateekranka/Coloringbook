import SwiftUI
import PencilKit
import CoreGraphics

/// UIViewRepresentable that wraps PKCanvasView and owns every pixel layer of
/// the coloring canvas.
///
/// Layer order inside PKCanvasView (bottom → top):
///   1. `backgroundView`    – solid UIView filled with the canvas background colour
///   2. `fillImageView`     – UIImageView showing flood-filled regions
///   3. PKCanvasView drawing surface (built-in, not a separate subview)
///   4. `lineArtImageView`  – UIImageView with the SVG line art, composited with
///                            Core Animation's "multiplyBlendMode" filter
///   5. `selectionLayer`    – CAShapeLayer drawn as a marching-ants dashed border
///                            around the currently selected region
///
/// Zoom / Pan
/// ----------
/// PKCanvasView is a UIScrollView subclass. Setting `drawingPolicy = .pencilOnly`
/// lets finger touches scroll/zoom while the Apple Pencil draws. We only
/// configure the zoom scale limits here; PKCanvasView handles the rest.
///
/// Tap handling
/// ------------
/// A UITapGestureRecognizer restricted to direct (finger) touches intercepts
/// taps and forwards them to the view model as document-space coordinates.
struct PencilCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: CanvasViewModel

    // MARK: - makeUIView

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = viewModel.drawing
        canvas.tool = viewModel.currentPKTool
        canvas.drawingPolicy = .pencilOnly   // fingers → scroll / zoom
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator

        // ProMotion 120 fps where supported
        canvas.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60, maximum: 120, preferred: 120
        )

        // Zoom limits — PKCanvasView honours these as a UIScrollView
        canvas.minimumZoomScale = 1.0
        canvas.maximumZoomScale = 5.0
        canvas.bouncesZoom = true

        // Build the layer stack
        context.coordinator.setupLayers(in: canvas)

        // Finger-only tap recogniser for fill / eyedropper / region selection
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        // Restrict to direct (finger) touch types; value 0 == UITouch.TouchType.direct
        tap.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        canvas.addGestureRecognizer(tap)

        // Hand the PKCanvasView reference back to the view model (weak)
        DispatchQueue.main.async {
            viewModel.pencilCanvas = canvas
        }

        return canvas
    }

    // MARK: - updateUIView

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let coordinator = context.coordinator

        // ── PencilKit tool ─────────────────────────────────────────────────
        // PKTool doesn't conform to Equatable, so compare by identity.
        if canvas.tool !== viewModel.currentPKTool as AnyObject {
            canvas.tool = viewModel.currentPKTool
        }

        // ── Drawing ────────────────────────────────────────────────────────
        // Only push the drawing back when it changed externally (e.g. undo).
        if canvas.drawing != viewModel.drawing {
            canvas.drawing = viewModel.drawing
        }

        // ── Background colour ──────────────────────────────────────────────
        coordinator.backgroundView.backgroundColor = UIColor(viewModel.backgroundColor)

        // ── Fill layer ─────────────────────────────────────────────────────
        coordinator.fillImageView.image = viewModel.showColorLayer
            ? viewModel.fillLayerImage
            : nil

        // ── Line-art overlay ───────────────────────────────────────────────
        coordinator.lineArtImageView.image = viewModel.showLineArt
            ? viewModel.templateImage
            : nil

        // ── Selection highlight ────────────────────────────────────────────
        coordinator.updateSelectionHighlight()

        // ── Content size ───────────────────────────────────────────────────
        // canvasSize is derived from the SVG viewBox and set after loadTemplate().
        let size = viewModel.canvasSize
        if size != .zero && canvas.contentSize != size {
            coordinator.updateContentSize(size, in: canvas)
        }
    }

    // MARK: - Coordinator factory

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasRepresentable

        // ── Subviews / sublayers ──────────────────────────────────────────
        let backgroundView  = UIView()
        let fillImageView   = UIImageView()
        let lineArtImageView = UIImageView()
        let selectionLayer  = CAShapeLayer()

        init(_ parent: PencilCanvasRepresentable) {
            self.parent = parent
        }

        // MARK: Layer setup

        func setupLayers(in canvas: PKCanvasView) {
            // 1. Background — inserted at index 0 (below PK drawing surface)
            backgroundView.backgroundColor = UIColor(parent.viewModel.backgroundColor)
            backgroundView.isUserInteractionEnabled = false
            canvas.insertSubview(backgroundView, at: 0)

            // 2. Fill image — above background, below PK drawing surface
            fillImageView.contentMode = .scaleAspectFit
            fillImageView.isUserInteractionEnabled = false
            canvas.insertSubview(fillImageView, aboveSubview: backgroundView)

            // 4. Line-art overlay — on top of the PK drawing surface.
            //    Use Core Animation's string-based compositing filter so the
            //    white areas of the line-art image become transparent.
            lineArtImageView.contentMode = .scaleAspectFit
            lineArtImageView.isUserInteractionEnabled = false
            lineArtImageView.layer.compositingFilter = "multiplyBlendMode"
            canvas.addSubview(lineArtImageView)

            // 5. Selection highlight (CAShapeLayer with marching-ants animation)
            selectionLayer.fillColor   = nil
            selectionLayer.strokeColor = UIColor.systemBlue.cgColor
            selectionLayer.lineWidth   = 2.0
            selectionLayer.lineDashPattern = [8, 4]
            selectionLayer.isHidden    = true

            // Marching-ants: animate the dash phase continuously
            let dashAnimation = CABasicAnimation(keyPath: "lineDashPhase")
            dashAnimation.fromValue  = 0
            dashAnimation.toValue    = 12          // sum of dash + gap = 8 + 4
            dashAnimation.duration   = 0.5
            dashAnimation.repeatCount = .infinity
            selectionLayer.add(dashAnimation, forKey: "marchingAnts")

            canvas.layer.addSublayer(selectionLayer)
        }

        // MARK: Content size / frame updates

        /// Called when `viewModel.canvasSize` changes (after template load).
        func updateContentSize(_ size: CGSize, in canvas: PKCanvasView) {
            canvas.contentSize = size
            let rect = CGRect(origin: .zero, size: size)
            backgroundView.frame   = rect
            fillImageView.frame    = rect
            lineArtImageView.frame = rect
        }

        // MARK: Selection highlight

        func updateSelectionHighlight() {
            guard
                let geometry   = parent.viewModel.templateGeometry,
                let selectedID = parent.viewModel.selectedRegionID,
                let region     = geometry.regions.first(where: { $0.id == selectedID })
            else {
                selectionLayer.path    = nil
                selectionLayer.isHidden = true
                return
            }

            // Build the transform that maps SVG document coords → canvas coords.
            var transform = TemplateRenderer.documentToViewTransform(
                viewBox: geometry.viewBox,
                viewSize: parent.viewModel.canvasSize
            )

            // CGPath.copy(using:) requires an UnsafePointer<CGAffineTransform>.
            // We pass &transform — the address of the local `var`.
            selectionLayer.path    = region.path.copy(using: &transform)
            selectionLayer.isHidden = false
        }

        // MARK: PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.viewModel.drawing = canvasView.drawing
            parent.viewModel.scheduleAutoSave()
        }

        // MARK: Tap gesture

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let canvas = gesture.view as? PKCanvasView else { return }

            // `location(in:)` returns a point in the scroll view's content
            // coordinate space, which equals document/canvas coordinates when
            // zoom scale is 1.  At other zoom scales PKCanvasView already
            // accounts for the scale in its coordinate system, so we pass the
            // point directly to view-model methods that expect canvas coords.
            let point    = gesture.location(in: canvas)
            let canvasSize = parent.viewModel.canvasSize
            guard canvasSize != .zero else { return }

            switch parent.viewModel.brushSettings.tool {
            case .floodFill:
                Task { @MainActor in
                    await parent.viewModel.performRegionFill(at: point, in: canvasSize)
                }

            case .eyedropper:
                parent.viewModel.pickColor(at: point, in: canvasSize)

            default:
                // For pencil / marker / eraser tools a tap can still select a
                // region for the selection-highlight overlay.
                parent.viewModel.selectRegion(at: point, in: canvasSize)
            }
        }
    }
}
