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
    @ObservedObject var viewModel: CanvasViewModel

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
        // Placed on the scroll view so it fires before scroll gestures.
        let tap = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        scrollView.addGestureRecognizer(tap)
        coordinator.tapGesture = tap

        // Expose the PKCanvasView to the view model (weak ref).
        DispatchQueue.main.async {
            viewModel.pencilCanvas = canvas
        }

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

        // ── Fit to screen trigger ────────────────────────────────────────────
        if viewModel.fitToScreenTrigger != coordinator.lastFitTrigger {
            coordinator.lastFitTrigger = viewModel.fitToScreenTrigger
            coordinator.fitToScreen()
        }

        // ── Tool-aware tap / gesture config ─────────────────────────────────
        let isNonDrawingTool = viewModel.brushSettings.tool == .floodFill
                            || viewModel.brushSettings.tool == .eyedropper
                            || viewModel.brushSettings.tool == .stamp
        print("[Canvas] updateUIView tool=\(viewModel.brushSettings.tool.rawValue) isNonDrawing=\(isNonDrawingTool) zoomScale=\(scrollView.zoomScale)")

        // ── Symmetry guide visibility ────────────────────────────────────────
        coordinator.symmetryGuideLayer.isHidden = !viewModel.symmetryEnabled

        // Enable tap recogniser only for non-drawing tools.
        coordinator.tapGesture?.isEnabled = isNonDrawingTool
        coordinator.tapGesture?.allowedTouchTypes = isNonDrawingTool
            ? [UITouch.TouchType.direct.rawValue as NSNumber,
               UITouch.TouchType.pencil.rawValue as NSNumber]
            : [UITouch.TouchType.direct.rawValue as NSNumber]
    }

    // MARK: - Coordinator factory

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        var parent: PencilCanvasRepresentable

        // ── Stored UIKit references ───────────────────────────────────────
        weak var scrollView: UIScrollView?
        weak var canvas: PKCanvasView?
        var contentContainer: UIView?

        // ── Pixel-layer subviews ──────────────────────────────────────────
        let backgroundView   = UIView()
        let fillImageView    = UIImageView()
        let lineArtImageView = UIImageView()
        let selectionLayer   = CAShapeLayer()

        /// Kept so updateUIView can toggle allowedTouchTypes dynamically.
        weak var tapGesture: UITapGestureRecognizer?

        /// Guards against infinite delegate loop when reverting ghost strokes.
        private var isRevertingDrawing = false

        /// Guards against infinite delegate loop when appending mirrored strokes.
        private var isAddingMirroredStroke = false

        // ── Symmetry guide overlay ────────────────────────────────────────
        let symmetryGuideLayer = CAShapeLayer()

        /// Tracks last seen fitToScreenTrigger value to detect changes.
        var lastFitTrigger: Bool = false

        init(_ parent: PencilCanvasRepresentable) {
            self.parent = parent
        }

        // MARK: Fit to Screen

        func fitToScreen() {
            guard let sv = scrollView else { return }
            let size = parent.viewModel.canvasSize
            guard size.width > 0, size.height > 0 else { return }
            guard sv.bounds.width > 0, sv.bounds.height > 0 else { return }
            let fitScale = min(sv.bounds.width / size.width, sv.bounds.height / size.height)
            sv.setZoomScale(fitScale, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.scrollViewDidZoom(sv)
            }
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
            if !UIAccessibility.isReduceMotionEnabled {
                selectionLayer.add(dashAnim, forKey: "marchingAnts")
            }

            container.layer.addSublayer(selectionLayer)

            // 5. Symmetry guide — vertical dashed line at the canvas centre
            symmetryGuideLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.4).cgColor
            symmetryGuideLayer.lineWidth = 1.0
            symmetryGuideLayer.lineDashPattern = [8, 4]
            symmetryGuideLayer.fillColor = nil
            symmetryGuideLayer.isHidden = true
            container.layer.addSublayer(symmetryGuideLayer)
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

            // Update symmetry guide line to bisect the canvas vertically.
            let midX = size.width / 2
            let guidePath = CGMutablePath()
            guidePath.move(to: CGPoint(x: midX, y: 0))
            guidePath.addLine(to: CGPoint(x: midX, y: size.height))
            symmetryGuideLayer.path = guidePath

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

        // MARK: Tap gesture

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // gesture.location(in: contentContainer) gives coordinates directly
            // in the document / content space — no zoomScale division needed.
            guard let content = contentContainer else { return }

            let point    = gesture.location(in: content)
            let docSize  = parent.viewModel.canvasSize
            let tool     = parent.viewModel.brushSettings.tool

            print("[Canvas] handleTap — tool=\(tool.rawValue) docPoint=(\(Int(point.x)),\(Int(point.y))) docSize=\(docSize) geometryLoaded=\(parent.viewModel.templateGeometry != nil)")

            guard docSize != .zero else {
                print("[Canvas] handleTap — SKIPPED: canvasSize is zero")
                return
            }

            switch tool {
            case .floodFill:
                Task { @MainActor in
                    await parent.viewModel.performRegionFill(at: point, in: docSize)
                }

            case .eyedropper:
                parent.viewModel.pickColor(at: point, in: docSize)

            default:
                parent.viewModel.selectRegion(at: point, in: docSize)
            }
        }
    }
}
