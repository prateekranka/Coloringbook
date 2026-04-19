import SwiftUI
import PencilKit
import CoreGraphics

/// UIViewRepresentable that wraps a custom UIScrollView + PKCanvasView stack.
///
/// WHY a wrapper scroll view?
/// --------------------------
/// PKCanvasView is itself a UIScrollView.  When you call `setZoomScale` on it,
/// UIKit only scales PencilKit's *internal* canvas layer (its "zoom view").
/// Any OTHER subviews we add (background, fill image, line-art overlay) are
/// siblings of that internal layer and are NOT scaled — they stay at full
/// document size while the drawing surface shrinks, causing the visual split
/// visible in the screenshot.
///
/// The fix is to wrap everything inside ONE UIScrollView and return a single
/// content container as the `viewForZooming`.  All layers then scale together.
///
/// Layer order inside contentContainer (bottom → top):
///   1. backgroundView    – solid colour background
///   2. fillImageView     – rendered fill regions
///   3. PKCanvasView      – PencilKit strokes (scroll + zoom DISABLED; outer SV owns that)
///   4. lineArtImageView  – SVG line art with multiplyBlendMode compositing filter
///   5. selectionLayer    – CAShapeLayer marching-ants selection highlight
struct PencilCanvasRepresentable: UIViewRepresentable {
    var viewModel: CanvasViewModel

    // MARK: - makeUIView

    func makeUIView(context: Context) -> UIView {
        let coordinator = context.coordinator

        // ── Outer container (fills SwiftUI's allocated space) ───────────────
        let container = UIView()
        container.backgroundColor = .white

        // ── Scroll view (zoom + pan for ALL layers) ─────────────────────────
        let scrollView = UIScrollView()
        scrollView.delegate = coordinator
        scrollView.minimumZoomScale = 0.1
        scrollView.maximumZoomScale = 10.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .white
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.frame = container.bounds
        container.addSubview(scrollView)
        coordinator.scrollView = scrollView

        // ── Content container (the UIScrollView zoom view) ──────────────────
        // All pixel layers live here so they zoom / pan as a unit.
        let content = UIView()
        content.backgroundColor = .clear
        scrollView.addSubview(content)
        coordinator.contentContainer = content

        // ── PKCanvasView (drawing only; no scroll / zoom of its own) ────────
        let canvas = PKCanvasView()
        canvas.drawing = viewModel.drawing
        canvas.tool = viewModel.currentPKTool
        canvas.drawingPolicy = .pencilOnly   // fingers → outer scroll view
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false       // outer scroll view owns panning
        canvas.minimumZoomScale = 1.0        // disable PK's own zoom
        canvas.maximumZoomScale = 1.0
        canvas.delegate = coordinator
        content.addSubview(canvas)
        coordinator.canvas = canvas

        // ── Pixel layers ────────────────────────────────────────────────────
        coordinator.setupLayers(in: content, canvas: canvas)

        // ── Tap gesture (fill / eyedropper / region selection) ──────────────
        // Attached to the zoomable content view so the tap location is already
        // in document space (UIScrollView accounts for zoom + offset). Allows
        // both finger and pencil taps; the handler dispatches based on tool.
        let tap = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.allowedTouchTypes = [
            UITouch.TouchType.direct.rawValue as NSNumber,
            UITouch.TouchType.pencil.rawValue as NSNumber,
        ]
        tap.delegate = coordinator
        // Let the scroll-view pan win when the user is actually dragging.
        if let pan = scrollView.panGestureRecognizer as UIPanGestureRecognizer? {
            tap.require(toFail: pan)
        }
        content.addGestureRecognizer(tap)
        coordinator.tapGesture = tap

        // Expose the PKCanvasView to the view model (weak ref).
        viewModel.pencilCanvas = canvas

        return container
    }

    // MARK: - updateUIView

    func updateUIView(_ container: UIView, context: Context) {
        let coordinator = context.coordinator
        guard let canvas    = coordinator.canvas,
              let scrollView = coordinator.scrollView else { return }

        // ── PencilKit tool ──────────────────────────────────────────────────
        canvas.tool = viewModel.currentPKTool

        // ── Drawing ─────────────────────────────────────────────────────────
        if canvas.drawing != viewModel.drawing {
            canvas.drawing = viewModel.drawing
        }

        // ── Background colour ───────────────────────────────────────────────
        coordinator.backgroundView.backgroundColor = UIColor(viewModel.backgroundColor)

        // ── Fill layer ──────────────────────────────────────────────────────
        coordinator.fillImageView.image = viewModel.showColorLayer
            ? viewModel.fillLayerImage
            : nil

        // ── Line-art overlay ────────────────────────────────────────────────
        coordinator.lineArtImageView.image = viewModel.showLineArt
            ? viewModel.templateImage
            : nil

        // ── Selection highlight ─────────────────────────────────────────────
        coordinator.updateSelectionHighlight()

        // ── Content size ────────────────────────────────────────────────────
        let size = viewModel.canvasSize
        if size != .zero && coordinator.contentContainer?.frame.size != size {
            print("[Canvas] contentSize mismatch — setting \(size), zoomScale=\(scrollView.zoomScale)")
            coordinator.updateContentSize(size, in: scrollView)
        }

        // Tap recognizer stays on permanently; handleTap dispatches by tool
        // (fill / eyedropper / selection). This avoids a race where toggling
        // isEnabled mid-dispatch caused taps to silently drop.
    }

    // MARK: - Coordinator factory

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: PencilCanvasRepresentable

        // ── Stored UIKit references ───────────────────────────────────────
        weak var scrollView: UIScrollView?
        weak var canvas: PKCanvasView?
        weak var contentContainer: UIView?

        // ── Pixel-layer subviews ──────────────────────────────────────────
        let backgroundView   = UIView()
        let fillImageView    = UIImageView()
        let lineArtImageView = UIImageView()
        let selectionLayer   = CAShapeLayer()

        /// Kept so updateUIView can toggle allowedTouchTypes dynamically.
        weak var tapGesture: UITapGestureRecognizer?

        /// Guards against infinite delegate loop when reverting ghost strokes.
        private var isRevertingDrawing = false

        init(_ parent: PencilCanvasRepresentable) {
            self.parent = parent
        }

        // MARK: UIScrollViewDelegate — zoom view

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return contentContainer
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Keep the content container centred when smaller than the scroll view.
            guard let content = contentContainer else { return }
            let offsetX = max(0, (scrollView.bounds.width  - content.frame.width)  / 2)
            let offsetY = max(0, (scrollView.bounds.height - content.frame.height) / 2)
            content.frame.origin = CGPoint(x: offsetX, y: offsetY)
        }

        // MARK: Layer setup

        func setupLayers(in container: UIView, canvas: PKCanvasView) {
            // 1. Background — behind the PKCanvasView
            backgroundView.backgroundColor = UIColor(parent.viewModel.backgroundColor)
            backgroundView.isUserInteractionEnabled = false
            container.insertSubview(backgroundView, at: 0)

            // 2. Fill image — above background, below PKCanvasView strokes
            fillImageView.contentMode = .scaleToFill
            fillImageView.isUserInteractionEnabled = false
            container.insertSubview(fillImageView, aboveSubview: backgroundView)

            // canvas was inserted at index 2 by the representable

            // 3. Line-art overlay — above PKCanvasView strokes
            lineArtImageView.contentMode = .scaleToFill
            lineArtImageView.isUserInteractionEnabled = false
            lineArtImageView.layer.compositingFilter = "multiplyBlendMode"
            container.addSubview(lineArtImageView)

            // 4. Selection highlight (marching-ants)
            selectionLayer.fillColor   = nil
            selectionLayer.strokeColor = UIColor.systemBlue.cgColor
            selectionLayer.lineWidth   = 2.0
            selectionLayer.lineDashPattern = [8, 4]
            selectionLayer.isHidden    = true

            let dashAnim = CABasicAnimation(keyPath: "lineDashPhase")
            dashAnim.fromValue   = 0
            dashAnim.toValue     = 12
            dashAnim.duration    = 0.5
            dashAnim.repeatCount = .infinity
            selectionLayer.add(dashAnim, forKey: "marchingAnts")

            container.layer.addSublayer(selectionLayer)
        }

        // MARK: Content size / layout

        func updateContentSize(_ size: CGSize, in scrollView: UIScrollView) {
            let rect = CGRect(origin: .zero, size: size)

            // Size all layers to the document dimensions.
            contentContainer?.frame = rect
            canvas?.frame           = rect
            canvas?.contentSize     = size
            backgroundView.frame    = rect
            fillImageView.frame     = rect
            lineArtImageView.frame  = rect

            // The scroll view's contentSize matches the document too; UIKit
            // will expand it as needed when zoom applies the scale transform.
            scrollView.contentSize = size

            guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else {
                print("[Canvas] updateContentSize — bounds not ready, skipping fit-zoom")
                return
            }

            let fitScale = min(
                scrollView.bounds.width  / size.width,
                scrollView.bounds.height / size.height
            )
            print("[Canvas] updateContentSize — docSize=\(size) bounds=\(scrollView.bounds.size) fitScale=\(fitScale) currentZoom=\(scrollView.zoomScale)")

            scrollView.minimumZoomScale = fitScale * 0.5
            scrollView.maximumZoomScale = fitScale * 10.0

            if scrollView.zoomScale >= 0.99 {
                scrollView.setZoomScale(fitScale, animated: false)
                scrollViewDidZoom(scrollView)
                print("[Canvas] updateContentSize — applied fitScale=\(fitScale)")
            } else {
                print("[Canvas] updateContentSize — skipped zoom snap (user already zoomed to \(scrollView.zoomScale))")
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

            var transform = TemplateRenderer.documentToViewTransform(
                viewBox: geometry.viewBox,
                viewSize: parent.viewModel.canvasSize
            )
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

        // MARK: UIGestureRecognizerDelegate

        /// Let the tap recognizer coexist with the scroll view's pan and pinch.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // MARK: Tap gesture

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Location in the zoom content view is already in document space —
            // UIScrollView has accounted for zoomScale and contentOffset.
            guard let content = contentContainer else { return }

            let docPoint = gesture.location(in: content)
            let tool     = parent.viewModel.brushSettings.tool

            guard parent.viewModel.canvasSize != .zero else { return }

            switch tool {
            case .floodFill:
                Task {
                    await parent.viewModel.performRegionFill(atDocumentPoint: docPoint)
                }

            case .eyedropper:
                parent.viewModel.pickColor(atDocumentPoint: docPoint)

            default:
                // For drawing tools a tap is a no-op (selection scaffolding
                // exists but isn't user-facing today).
                parent.viewModel.selectRegion(atDocumentPoint: docPoint)
            }
        }
    }
}
