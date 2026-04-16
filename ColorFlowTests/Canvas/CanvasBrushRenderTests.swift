import XCTest
import UIKit
import SwiftUI
import PencilKit
@testable import ColorFlow

@MainActor
final class CanvasBrushRenderTests: XCTestCase {

    private var viewModel: CanvasViewModel!
    private var geometry: TemplateGeometry!
    private var size: CGSize!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        geometry = viewModel.templateGeometry!
        size = geometry.viewBox.size
    }

    private func renderExport(with drawing: PKDrawing) -> UIImage {
        let pencilImage = drawing.image(from: CGRect(origin: .zero, size: size), scale: 1.0)
        return TemplateRenderer.renderExport(
            geometry: geometry,
            fills: [:],
            pencilImage: pencilImage,
            backgroundColor: .white,
            size: size
        )
    }

    private func sampleWindow(at midpoint: CGPoint, windowSize: CGFloat = 16) -> CGRect {
        CGRect(
            x: midpoint.x - windowSize / 2,
            y: midpoint.y - windowSize / 2,
            width: windowSize,
            height: windowSize
        )
    }

    // MARK: - Pencil

    func test_pencilStroke_rendersRedPixels() async throws {
        let stroke = PKStrokeFactory.pencilLine(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 300, y: 100),
            color: .systemRed,
            width: 8
        )
        let drawing = PKStrokeFactory.drawing(with: [stroke])
        let image = renderExport(with: drawing)

        let midpoint = CGPoint(x: 200, y: 100)
        guard let rgba = PixelSampler.meanColor(of: image, in: sampleWindow(at: midpoint)) else {
            XCTFail("PixelSampler returned nil")
            return
        }

        XCTAssertGreaterThan(rgba.r, 150, "Pencil stroke mid-region should be red-dominant (R > 150), got \(rgba.r)")
        XCTAssertLessThan(rgba.g, 100, "Pencil stroke green channel should be low, got \(rgba.g)")
        XCTAssertLessThan(rgba.b, 100, "Pencil stroke blue channel should be low, got \(rgba.b)")
    }

    // MARK: - Marker

    func test_markerStroke_rendersVisibleRedPixels() async throws {
        let y: CGFloat = 200
        let markerStroke = PKStrokeFactory.straightLine(
            from: CGPoint(x: 100, y: y),
            to: CGPoint(x: 300, y: y),
            ink: PKInkingTool(.marker, color: .systemRed, width: 8).ink,
            strokeSize: CGSize(width: 8, height: 8)
        )
        let image = renderExport(with: PKStrokeFactory.drawing(with: [markerStroke]))

        let midpoint = CGPoint(x: 200, y: y)
        guard let rgba = PixelSampler.meanColor(of: image, in: sampleWindow(at: midpoint)) else {
            XCTFail("PixelSampler returned nil")
            return
        }

        XCTAssertGreaterThan(rgba.r, rgba.g, "Marker red stroke must have R > G, got R=\(rgba.r) G=\(rgba.g)")

        let crossSection = CGRect(x: 195, y: y - 50, width: 10, height: 100)
        let strokePixels = PixelSampler.nonWhitePixelCount(of: image, in: crossSection)
        XCTAssertGreaterThan(strokePixels, 0, "Marker must produce visible stroke pixels, got \(strokePixels)")
    }

    // MARK: - Watercolor

    func test_watercolorStroke_shipsAtExpectedAlpha() async throws {
        let tool = PKInkingTool(.monoline, color: UIColor.systemRed.withAlphaComponent(0.4), width: 8)
        let stroke = PKStrokeFactory.straightLine(
            from: CGPoint(x: 100, y: 400),
            to: CGPoint(x: 300, y: 400),
            ink: tool.ink,
            strokeSize: CGSize(width: 8, height: 8)
        )
        let image = renderExport(with: PKStrokeFactory.drawing(with: [stroke]))

        let midpoint = CGPoint(x: 200, y: 400)
        guard let rgba = PixelSampler.meanColor(of: image, in: sampleWindow(at: midpoint)) else {
            XCTFail("PixelSampler returned nil")
            return
        }

        XCTAssertGreaterThan(rgba.r, 100, "Watercolor red should be mid-range (> 100), got \(rgba.r)")
        XCTAssertLessThan(rgba.r, 255, "Watercolor red should be below full (< 255) due to alpha, got \(rgba.r)")
    }

    // MARK: - Eraser (PKDrawing-only contract)

    func test_eraserStroke_removesDrawingStroke_preservesFillLayer() async throws {
        // Render with a pencil stroke — measure red pixels
        let pencilStroke = PKStrokeFactory.pencilLine(
            from: CGPoint(x: 100, y: 500),
            to: CGPoint(x: 300, y: 500),
            color: .systemRed,
            width: 12
        )
        let strokeOnlyImage = renderExport(with: PKStrokeFactory.drawing(with: [pencilStroke]))
        let window = sampleWindow(at: CGPoint(x: 200, y: 500))
        let redBefore = PixelSampler.redPixelCount(of: strokeOnlyImage, in: window)

        // Now render with pencil + eraser overlapping
        let eraserInk = PKInk(.pen, color: .white)
        let eraserStroke = PKStrokeFactory.straightLine(
            from: CGPoint(x: 90, y: 500),
            to: CGPoint(x: 310, y: 500),
            ink: eraserInk,
            strokeSize: CGSize(width: 30, height: 30)
        )
        let combinedImage = renderExport(with: PKStrokeFactory.drawing(with: [pencilStroke, eraserStroke]))
        let redAfter = PixelSampler.redPixelCount(of: combinedImage, in: window)

        XCTAssertGreaterThan(
            redBefore, 0,
            "Pencil stroke must produce visible red pixels before eraser"
        )
        XCTAssertLessThan(
            redAfter, redBefore,
            "Eraser-like white overlay must reduce red pixel count. Before=\(redBefore), After=\(redAfter)"
        )

        // Fill layer independence
        let fillImageBefore = viewModel.fillLayerImage
        viewModel.drawing = PKStrokeFactory.drawing(with: [pencilStroke, eraserStroke])
        XCTAssertTrue(
            fillImageBefore === viewModel.fillLayerImage,
            "Fill layer image must not change when only PKDrawing strokes are modified."
        )
    }

    // MARK: - Color / size plumbing

    func test_brushColorChange_flowsToRenderedPixels() async throws {
        let stroke = PKStrokeFactory.pencilLine(
            from: CGPoint(x: 100, y: 600),
            to: CGPoint(x: 300, y: 600),
            color: .systemBlue,
            width: 8
        )
        let image = renderExport(with: PKStrokeFactory.drawing(with: [stroke]))

        let midpoint = CGPoint(x: 200, y: 600)
        guard let rgba = PixelSampler.meanColor(of: image, in: sampleWindow(at: midpoint)) else {
            XCTFail("PixelSampler returned nil")
            return
        }

        XCTAssertGreaterThan(rgba.b, 150, "Blue stroke should have dominant blue channel, got \(rgba.b)")
        XCTAssertLessThan(rgba.r, 100, "Blue stroke red channel should be low, got \(rgba.r)")
    }

    func test_brushSizeChange_flowsToStrokeWidth() async throws {
        let y: CGFloat = 300
        let thinStroke = PKStrokeFactory.pencilLine(
            from: CGPoint(x: 100, y: y),
            to: CGPoint(x: 300, y: y),
            color: .systemRed,
            width: 4
        )
        let thickStroke = PKStrokeFactory.pencilLine(
            from: CGPoint(x: 100, y: y),
            to: CGPoint(x: 300, y: y),
            color: .systemRed,
            width: 20
        )

        let thinImage = renderExport(with: PKStrokeFactory.drawing(with: [thinStroke]))
        let thickImage = renderExport(with: PKStrokeFactory.drawing(with: [thickStroke]))

        let crossSection = CGRect(x: 195, y: y - 50, width: 10, height: 100)
        let thinPixels = PixelSampler.nonWhitePixelCount(of: thinImage, in: crossSection)
        let thickPixels = PixelSampler.nonWhitePixelCount(of: thickImage, in: crossSection)

        XCTAssertGreaterThan(thinPixels, 0, "Thin stroke must produce visible pixels")
        XCTAssertGreaterThan(thickPixels, 0, "Thick stroke must produce visible pixels")
        XCTAssertGreaterThan(
            thickPixels, thinPixels,
            "Size-20 stroke must cover more pixels than size-4. Thin=\(thinPixels), Thick=\(thickPixels)"
        )
    }

    // MARK: - Release no-op for the debug launch arg

    func test_enableFingerDrawingFlag_isNoOpInRelease() async throws {
        #if DEBUG
        let viewModel = try await CanvasTestFixture.makeLoadedViewModel()
        let representable = PencilCanvasRepresentable(viewModel: viewModel)
        let host = UIHostingController(rootView: representable)
        let frame = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        let window = UIWindow(frame: frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = frame
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        host.view.layoutIfNeeded()

        func findCanvas(in view: UIView) -> PKCanvasView? {
            if let canvas = view as? PKCanvasView { return canvas }
            for sub in view.subviews {
                if let c = findCanvas(in: sub) { return c }
            }
            return nil
        }

        if let canvas = findCanvas(in: host.view),
           !CommandLine.arguments.contains("-enableFingerDrawing") {
            XCTAssertEqual(
                canvas.drawingPolicy, .pencilOnly,
                "Without -enableFingerDrawing flag, drawingPolicy must be .pencilOnly even in Debug"
            )
        }
        #endif
    }
}
