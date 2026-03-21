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

        // Zoom limits — set a generous range; updateContentSize tightens the
        // minimum and sets the initial zoom to fit the template on screen.
        canvas.minimumZoomScale = 0.1
        canvas.maximumZoomScale = 5.0
        canvas.bouncesZoom = true

        // Build the layer stack
        context.coordinator.setupLayers(in: canvas)

        // Tap recogniser for fill / eyedropper / region selection.
        // allowedTouchTypes is kept up-to-date in updateUIView so that
        // Apple Pencil taps work for non-drawing tools while still letting
        // PencilKit own pencil input when a drawing tool is active.
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        canvas.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

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
        // currentPKTool is a computed property (new instance each call),
        // so identity comparison is unreliable — always sync the tool.
        canvas.tool = viewModel.currentPKTool

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
            print("[Canvas] contentSize mismatch — setting \(size), zoomScale=\(canvas.zoomScale)")
            coordinator.updateContentSize(size, in: canvas)
        }

        // ── Tool-aware gesture configuration ───────────────────────────────
        // For non-drawing tools (flood fill, eyedropper):
        //   • Require 2 fingers to pan so a single tap cannot drift the
        //     canvas. Two-finger pinch-to-zoom keeps working normally.
        //     (Disabling panGestureRecognizer entirely breaks PKCanvasView's
        //     internal touch dispatch, which is why we use minimumNumberOfTouches
        //     instead of isEnabled.)
        //   • Also allow Apple Pencil touch type on the tap recogniser so the
        //     user can tap with the Pencil to fill or pick a colour.
        // For drawing tools restore single-finger panning and restrict the tap
        // recogniser to fingers only so PencilKit owns pencil input.
        let isNonDrawingTool = viewModel.brushSettings.tool == .floodFill
                            || viewModel.brushSettings.tool == .eyedropper
        canvas.panGestureRecognizer.minimumNumberOfTouches = isNonDrawingTool ? 2 : 1
        print("[Canvas] tool=\(viewModel.brushSettings.tool.rawValue) panMinTouches=\(canvas.panGestureRecognizer.minimumNumberOfTouches) zoomScale=\(canvas.zoomScale)")

        coordinator.tapGesture?.allowedTouchTypes = isNonDrawingTool
            ? [UITouch.TouchType.direct.rawValue as NSNumber,
               UITouch.TouchType.pencil.rawValue as NSNumber]
            : [UITouch.TouchType.direct.rawValue as NSNumber]
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

        /// Kept so updateUIView can toggle allowedTouchTypes dynamically.
        weak var tapGesture: UITapGestureRecognizer?

        /// Guards against an infinite delegate loop when we revert pencil strokes
        /// drawn while a non-drawing tool is active.
        private var isRevertingDrawing = false

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

            // Auto-fit: zoom so the full template is visible on first load.
            // canvas.bounds is valid here because SwiftUI lays out the view
            // before calling updateUIView.
            guard canvas.bounds.width > 0, canvas.bounds.height > 0 else {
                print("[Canvas] updateContentSize — bounds not ready yet, skipping zoom")
                return
            }
            let fitScale = min(
                canvas.bounds.width  / size.width,
                canvas.bounds.height / size.height
            )
            print("[Canvas] updateContentSize — docSize=\(size) bounds=\(canvas.bounds.size) fitScale=\(fitScale) currentZoom=\(canvas.zoomScale)")
            // Allow zooming out to half the fit scale for context.
            canvas.minimumZoomScale = fitScale * 0.5
            // Allow zooming in up to 10× the fit scale (two-finger pinch).
            canvas.maximumZoomScale = fitScale * 10.0
            // Only snap to fit-scale if the user hasn't already zoomed manually
            // (zoomScale == 1.0 is the PKCanvasView default before any interaction).
            if canvas.zoomScale >= 0.99 {
                canvas.setZoomScale(fitScale, animated: false)
                // Centre the content after zoom.
                let cx = max(0, (canvas.contentSize.width  * fitScale - canvas.bounds.width)  / 2)
                let cy = max(0, (canvas.contentSize.height * fitScale - canvas.bounds.height) / 2)
                canvas.contentOffset = CGPoint(x: cx, y: cy)
                print("[Canvas] updateContentSize — applied fitScale=\(fitScale) contentOffset=(\(cx),\(cy))")
            } else {
                print("[Canvas] updateContentSize — skipped zoom snap (zoomScale=\(canvas.zoomScale) already set by user)")
            }
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
            guard !isRevertingDrawing else { return }

            let tool = parent.viewModel.brushSettings.tool
            if tool == .floodFill || tool == .eyedropper {
                print("[Canvas] drawingDidChange while tool=\(tool.rawValue) — reverting ghost stroke")
                isRevertingDrawing = true
                canvasView.drawing = parent.viewModel.drawing
                isRevertingDrawing = false
                return
            }

            print("[Canvas] drawingDidChange — tool=\(tool.rawValue) strokeCount=\(canvasView.drawing.strokes.count)")
            parent.viewModel.drawing = canvasView.drawing
            parent.viewModel.scheduleAutoSave()
        }

        // MARK: Tap gesture

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let canvas = gesture.view as? PKCanvasView else { return }

            // gesture.location(in:) returns coordinates in the UIScrollView's
            // content space, which is scaled by zoomScale relative to the
            // underlying document space.  Dividing by zoomScale converts to
            // document coordinates, which is what the view model expects.
            let raw = gesture.location(in: canvas)
            let point = CGPoint(x: raw.x / canvas.zoomScale,
                                y: raw.y / canvas.zoomScale)
            let canvasSize = parent.viewModel.canvasSize
            let tool = parent.viewModel.brushSettings.tool

            print("[Canvas] handleTap — tool=\(tool.rawValue) raw=(\(Int(raw.x)),\(Int(raw.y))) zoomScale=\(canvas.zoomScale) docPoint=(\(Int(point.x)),\(Int(point.y))) canvasSize=\(canvasSize) geometryLoaded=\(parent.viewModel.templateGeometry != nil)")

            guard canvasSize != .zero else {
                print("[Canvas] handleTap — SKIPPED: canvasSize is zero")
                return
            }

            switch tool {
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
