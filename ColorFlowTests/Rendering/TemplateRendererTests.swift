import XCTest
import CoreGraphics
@testable import ColorFlow

// MARK: - Helpers

private func makeRegion(
    id: String,
    rect: CGRect,
    fillRule: CGPathFillRule = .winding,
    zIndex: Int = 0
) -> RegionGeometry {
    let path = CGMutablePath()
    path.addRect(rect)
    return RegionGeometry(
        id: id,
        path: path,
        bounds: rect,
        fillRule: fillRule,
        zIndex: zIndex
    )
}

private func makeGeometry(
    viewBox: CGRect = CGRect(x: 0, y: 0, width: 400, height: 400),
    regions: [RegionGeometry] = [],
    decorativePaths: [CGPath] = []
) -> TemplateGeometry {
    TemplateGeometry(viewBox: viewBox, regions: regions, decorativePaths: decorativePaths)
}

// MARK: - Tests

final class TemplateRendererTests: XCTestCase {

    // MARK: documentToViewTransform — scale

    func test_transform_squareViewBoxInSquareView_scaleIsOne() {
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 200, height: 200),
            viewSize: CGSize(width: 200, height: 200)
        )
        // scale = min(200/200, 200/200) = 1
        let scale = t.a  // CGAffineTransform a == x-scale when there is no rotation
        XCTAssertEqual(scale, 1.0, accuracy: 1e-6, "Scale should be 1.0 for matched dimensions")
    }

    func test_transform_wideViewBox_scaleClampedByHeight() {
        // viewBox 400×200, view 200×200 → scale limited by height = 200/200 = 1, but
        // width axis would be 200/400 = 0.5, so min is 0.5
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 400, height: 200),
            viewSize: CGSize(width: 200, height: 200)
        )
        let scale = t.a
        XCTAssertEqual(scale, 0.5, accuracy: 1e-6, "Scale should be limited by the wider axis")
    }

    func test_transform_tallViewBox_scaleClampedByWidth() {
        // viewBox 200×400, view 200×200 → scale limited by width = 200/200 = 1, but
        // height axis would be 200/400 = 0.5, so min is 0.5
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 200, height: 400),
            viewSize: CGSize(width: 200, height: 200)
        )
        let scale = t.a
        XCTAssertEqual(scale, 0.5, accuracy: 1e-6, "Scale should be limited by the taller axis")
    }

    func test_transform_uniformScale_xAndYScaleEqual() {
        let viewBox = CGRect(x: 0, y: 0, width: 300, height: 200)
        let viewSize = CGSize(width: 600, height: 600)
        let t = TemplateRenderer.documentToViewTransform(viewBox: viewBox, viewSize: viewSize)
        // CGAffineTransform: a = x-scale, d = y-scale
        XCTAssertEqual(t.a, t.d, accuracy: 1e-6, "Aspect-fit must use uniform scale on both axes")
    }

    // MARK: documentToViewTransform — translation (centering)

    func test_transform_squareViewInSquareView_translationIsZero() {
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            viewSize: CGSize(width: 100, height: 100)
        )
        XCTAssertEqual(t.tx, 0, accuracy: 1e-6)
        XCTAssertEqual(t.ty, 0, accuracy: 1e-6)
    }

    func test_transform_wideView_horizontalCenteringOffset() {
        // viewBox 100×100, view 300×100 → scale 1, tx = (300-100)/2 = 100, ty = 0
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            viewSize: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(t.tx, 100, accuracy: 1e-6, "Should center horizontally in wide view")
        XCTAssertEqual(t.ty, 0,   accuracy: 1e-6)
    }

    func test_transform_tallView_verticalCenteringOffset() {
        // viewBox 100×100, view 100×300 → scale 1, tx = 0, ty = (300-100)/2 = 100
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            viewSize: CGSize(width: 100, height: 300)
        )
        XCTAssertEqual(t.tx, 0,   accuracy: 1e-6)
        XCTAssertEqual(t.ty, 100, accuracy: 1e-6, "Should center vertically in tall view")
    }

    func test_transform_scaledDown_translationCentersCorrectly() {
        // viewBox 400×400, view 200×200 → scale 0.5, tx = (200 - 400*0.5)/2 = 0, ty = 0
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 400, height: 400),
            viewSize: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(t.a,  0.5, accuracy: 1e-6)
        XCTAssertEqual(t.tx, 0.0, accuracy: 1e-6)
        XCTAssertEqual(t.ty, 0.0, accuracy: 1e-6)
    }

    func test_transform_wideViewBoxInSquareView_centeredVertically() {
        // viewBox 400×200, view 200×200 → scale = min(200/400, 200/200) = 0.5
        // scaled height = 200*0.5 = 100, ty = (200 - 100)/2 = 50
        // scaled width  = 400*0.5 = 200, tx = (200 - 200)/2 = 0
        let t = TemplateRenderer.documentToViewTransform(
            viewBox: CGRect(x: 0, y: 0, width: 400, height: 200),
            viewSize: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(t.a,  0.5, accuracy: 1e-6)
        XCTAssertEqual(t.tx, 0.0, accuracy: 1e-6, "Wide viewBox fills width, no x offset")
        XCTAssertEqual(t.ty, 50,  accuracy: 1e-6, "Wide viewBox should center vertically")
    }

    // MARK: renderLineArt — output size

    func test_renderLineArt_returnsImageOfRequestedSize() {
        let size = CGSize(width: 300, height: 300)
        let geo = makeGeometry(
            viewBox: CGRect(x: 0, y: 0, width: 300, height: 300),
            regions: [makeRegion(id: "r1", rect: CGRect(x: 10, y: 10, width: 50, height: 50))]
        )
        let image = TemplateRenderer.renderLineArt(geometry: geo, size: size)
        XCTAssertEqual(image.size.width,  size.width,  accuracy: 1, "Width must match requested size")
        XCTAssertEqual(image.size.height, size.height, accuracy: 1, "Height must match requested size")
    }

    func test_renderLineArt_nonSquareSize_returnsCorrectDimensions() {
        let size = CGSize(width: 200, height: 400)
        let geo = makeGeometry(viewBox: CGRect(x: 0, y: 0, width: 100, height: 100))
        let image = TemplateRenderer.renderLineArt(geometry: geo, size: size)
        XCTAssertEqual(image.size.width,  200, accuracy: 1)
        XCTAssertEqual(image.size.height, 400, accuracy: 1)
    }

    func test_renderLineArt_noRegions_returnsNonNilImage() {
        let geo = makeGeometry()
        let image = TemplateRenderer.renderLineArt(geometry: geo, size: CGSize(width: 100, height: 100))
        XCTAssertNotNil(image.cgImage, "renderLineArt must produce a valid CGImage")
    }

    // MARK: renderFillLayer — output size

    func test_renderFillLayer_returnsImageOfRequestedSize() {
        let size = CGSize(width: 250, height: 250)
        let region = makeRegion(id: "petal-1", rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let geo = makeGeometry(viewBox: CGRect(x: 0, y: 0, width: 250, height: 250), regions: [region])
        let image = TemplateRenderer.renderFillLayer(
            geometry: geo,
            fills: ["petal-1": "#FF0000"],
            size: size
        )
        XCTAssertEqual(image.size.width,  size.width,  accuracy: 1)
        XCTAssertEqual(image.size.height, size.height, accuracy: 1)
    }

    func test_renderFillLayer_emptyFills_returnsNonNilImage() {
        let geo = makeGeometry(
            regions: [makeRegion(id: "r1", rect: CGRect(x: 0, y: 0, width: 50, height: 50))]
        )
        let image = TemplateRenderer.renderFillLayer(geometry: geo, fills: [:], size: CGSize(width: 100, height: 100))
        XCTAssertNotNil(image.cgImage)
    }

    func test_renderFillLayer_onlyDrawsMatchingRegionIDs() {
        // Two regions; only one is in the fills dict — should still return a valid image
        let r1 = makeRegion(id: "sky",   rect: CGRect(x: 0,  y: 0, width: 100, height: 50))
        let r2 = makeRegion(id: "grass", rect: CGRect(x: 0, y: 50, width: 100, height: 50))
        let geo = makeGeometry(
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            regions: [r1, r2]
        )
        let image = TemplateRenderer.renderFillLayer(
            geometry: geo,
            fills: ["sky": "#87CEEB"],
            size: CGSize(width: 100, height: 100)
        )
        XCTAssertNotNil(image.cgImage)
    }

    // MARK: renderThumbnail — output size and non-nil

    func test_renderThumbnail_defaultSize_is400x400() {
        let geo = makeGeometry()
        let image = TemplateRenderer.renderThumbnail(geometry: geo)
        XCTAssertEqual(image.size.width,  400, accuracy: 1, "Default thumbnail width should be 400")
        XCTAssertEqual(image.size.height, 400, accuracy: 1, "Default thumbnail height should be 400")
    }

    func test_renderThumbnail_customSize_matchesRequest() {
        let geo = makeGeometry()
        let size = CGSize(width: 128, height: 128)
        let image = TemplateRenderer.renderThumbnail(geometry: geo, size: size)
        XCTAssertEqual(image.size.width,  128, accuracy: 1)
        XCTAssertEqual(image.size.height, 128, accuracy: 1)
    }

    func test_renderThumbnail_withFills_returnsNonNilImage() {
        let region = makeRegion(id: "flower", rect: CGRect(x: 50, y: 50, width: 100, height: 100))
        let geo = makeGeometry(
            viewBox: CGRect(x: 0, y: 0, width: 200, height: 200),
            regions: [region]
        )
        let image = TemplateRenderer.renderThumbnail(
            geometry: geo,
            fills: ["flower": "#FF69B4"],
            size: CGSize(width: 200, height: 200)
        )
        XCTAssertNotNil(image.cgImage)
    }

    // MARK: renderExport — output size and non-nil

    func test_renderExport_returnsImageOfRequestedSize() {
        let size = CGSize(width: 1024, height: 1024)
        let geo = makeGeometry(viewBox: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let image = TemplateRenderer.renderExport(
            geometry: geo,
            fills: [:],
            pencilImage: nil,
            backgroundColor: .white,
            size: size
        )
        XCTAssertEqual(image.size.width,  size.width,  accuracy: 1)
        XCTAssertEqual(image.size.height, size.height, accuracy: 1)
    }

    func test_renderExport_returnsNonNilCGImage() {
        let geo = makeGeometry()
        let image = TemplateRenderer.renderExport(
            geometry: geo,
            fills: [:],
            pencilImage: nil,
            backgroundColor: .white,
            size: CGSize(width: 200, height: 200)
        )
        XCTAssertNotNil(image.cgImage)
    }

    // MARK: zIndex ordering in renderFillLayer

    func test_renderFillLayer_zOrderedRegions_producesImage() {
        // Regions with different z-indices; renderer should sort without crashing
        let r0 = makeRegion(id: "bg",   rect: CGRect(x: 0, y: 0, width: 200, height: 200), zIndex: 0)
        let r1 = makeRegion(id: "mid",  rect: CGRect(x: 25, y: 25, width: 100, height: 100), zIndex: 1)
        let r2 = makeRegion(id: "top",  rect: CGRect(x: 50, y: 50, width: 50,  height: 50),  zIndex: 2)
        let geo = makeGeometry(
            viewBox: CGRect(x: 0, y: 0, width: 200, height: 200),
            regions: [r2, r0, r1]  // intentionally scrambled order
        )
        let image = TemplateRenderer.renderFillLayer(
            geometry: geo,
            fills: ["bg": "#FFFFFF", "mid": "#FF0000", "top": "#0000FF"],
            size: CGSize(width: 200, height: 200)
        )
        XCTAssertNotNil(image.cgImage, "Rendering z-ordered regions must succeed")
    }
}
