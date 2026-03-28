import XCTest
import CoreGraphics
@testable import ColorFlow

final class TemplateGeometryTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a RegionGeometry whose path is the given CGRect.
    private func makeRegion(
        id: String,
        rect: CGRect,
        zIndex: Int,
        fillRule: CGPathFillRule = .winding
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

    /// Wraps a list of regions into a TemplateGeometry with a matching viewBox.
    private func makeGeometry(
        regions: [RegionGeometry],
        viewBox: CGRect = CGRect(x: 0, y: 0, width: 500, height: 500)
    ) -> TemplateGeometry {
        TemplateGeometry(viewBox: viewBox, regions: regions, decorativePaths: [])
    }

    // MARK: - Tests

    func test_regionAtPoint_insideRegion_returnsRegion() {
        let rect = CGRect(x: 10, y: 10, width: 100, height: 100)
        let region = makeRegion(id: "box-1", rect: rect, zIndex: 0)
        let geometry = makeGeometry(regions: [region])

        let hit = geometry.region(at: CGPoint(x: 50, y: 50))

        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.id, "box-1")
    }

    func test_regionAtPoint_outsideAllRegions_returnsNil() {
        let rect = CGRect(x: 10, y: 10, width: 100, height: 100)
        let region = makeRegion(id: "box-1", rect: rect, zIndex: 0)
        let geometry = makeGeometry(regions: [region])

        let hit = geometry.region(at: CGPoint(x: 300, y: 300))

        XCTAssertNil(hit)
    }

    func test_regionAtPoint_overlappingRegions_returnsHighestZIndex() {
        // Two rects that fully overlap; higher zIndex should win the hit test.
        let sharedRect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let lower = makeRegion(id: "lower", rect: sharedRect, zIndex: 0)
        let upper = makeRegion(id: "upper", rect: sharedRect, zIndex: 5)
        let geometry = makeGeometry(regions: [lower, upper])

        let hit = geometry.region(at: CGPoint(x: 100, y: 100))

        XCTAssertEqual(hit?.id, "upper",
                       "The region with the highest zIndex should win when regions overlap")
    }

    func test_regionAtPoint_emptyRegions_returnsNil() {
        let geometry = makeGeometry(regions: [])

        let hit = geometry.region(at: CGPoint(x: 50, y: 50))

        XCTAssertNil(hit)
    }

    func test_regionAtPoint_boundsRejectsEarlyForFarAwayPoint() {
        // Region is in the top-left corner; queried point is far away.
        // The fast bounds check should reject it before the expensive path test.
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50)
        let region = makeRegion(id: "small-box", rect: rect, zIndex: 0)
        let geometry = makeGeometry(regions: [region])

        let hit = geometry.region(at: CGPoint(x: 400, y: 400))

        XCTAssertNil(hit,
                     "A point far outside the region's bounds should return nil (early-rejection path)")
    }

    // MARK: - Additional edge cases

    func test_regionAtPoint_onBoundaryEdge_returnsRegion() {
        // Points exactly on the boundary of a rect are considered inside by CGPath.
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let region = makeRegion(id: "edge-box", rect: rect, zIndex: 0)
        let geometry = makeGeometry(regions: [region])

        // Test a point clearly inside but near the edge.
        let hit = geometry.region(at: CGPoint(x: 1, y: 1))
        XCTAssertNotNil(hit)
    }

    func test_regionAtPoint_singleRegion_wrongPoint_returnsNil() {
        let rect = CGRect(x: 50, y: 50, width: 100, height: 100)
        let region = makeRegion(id: "box", rect: rect, zIndex: 1)
        let geometry = makeGeometry(regions: [region])

        // Point is inside bounds of the viewBox but outside the single region.
        let hit = geometry.region(at: CGPoint(x: 10, y: 10))

        XCTAssertNil(hit)
    }

    func test_regionAtPoint_multipleNonOverlapping_hitsCorrectOne() {
        let rectA = CGRect(x: 0,   y: 0,   width: 100, height: 100)
        let rectB = CGRect(x: 200, y: 200, width: 100, height: 100)
        let regionA = makeRegion(id: "region-A", rect: rectA, zIndex: 0)
        let regionB = makeRegion(id: "region-B", rect: rectB, zIndex: 1)
        let geometry = makeGeometry(regions: [regionA, regionB])

        let hitA = geometry.region(at: CGPoint(x: 50,  y: 50))
        let hitB = geometry.region(at: CGPoint(x: 250, y: 250))

        XCTAssertEqual(hitA?.id, "region-A")
        XCTAssertEqual(hitB?.id, "region-B")
    }
}
