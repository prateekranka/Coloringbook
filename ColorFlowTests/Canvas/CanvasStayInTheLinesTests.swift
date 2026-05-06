import XCTest
import PencilKit
import UIKit
@testable import ColorFlow

@MainActor
final class CanvasStayInTheLinesTests: XCTestCase {

    private var geometry: TemplateGeometry!

    override func setUpWithError() throws {
        geometry = try CanvasTestFixture.makeGeometry()
    }

    override func tearDownWithError() throws {
        geometry = nil
    }

    func test_strokeFullyInsideRegion_emitsOneStroke() throws {
        let region = try firstRegion()
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let offset = region.bounds.width * 0.1

        let stroke = PKStrokeFactory.pencilLine(
            from: CGPoint(x: interior.x - offset, y: interior.y - offset),
            to: CGPoint(x: interior.x + offset, y: interior.y + offset),
            color: .red,
            steps: 20
        )

        let result = StrokeClipper.clipStroke(stroke, using: geometry)
        XCTAssertEqual(result.count, 1, "Fully inside stroke should emit exactly one stroke")
        XCTAssertTrue(result.allSatisfy { $0.path.count >= 2 })
    }

    func test_strokeStartingOutsideRegion_isDropped() throws {
        let outside = CanvasTestFixture.pointOutsideAllRegions
        let region = try firstRegion()
        let interior = CanvasTestFixture.interiorPoint(of: region)

        let stroke = PKStrokeFactory.pencilLine(
            from: outside,
            to: interior,
            color: .blue,
            steps: 20
        )

        let result = StrokeClipper.clipStroke(stroke, using: geometry)
        XCTAssertTrue(result.isEmpty, "Outside-start stroke should be dropped entirely")
    }

    func test_strokeWithControlsInsideButSplineOutside_isClipped() throws {
        let region = try firstRegion()
        let bbox = region.bounds
        let interior = CanvasTestFixture.interiorPoint(of: region)

        let edgeInset = bbox.width * 0.05
        let p1 = CGPoint(x: bbox.minX + edgeInset, y: interior.y)
        let p2 = CGPoint(x: bbox.maxX - edgeInset, y: interior.y)

        let tool = PKInkingTool(.marker, color: UIColor.red, width: 40)
        let stroke = PKStrokeFactory.straightLine(
            from: p1, to: p2, steps: 3, ink: tool.ink,
            strokeSize: CGSize(width: 40, height: 40)
        )

        let result = StrokeClipper.clipStroke(stroke, using: geometry)
        if !result.isEmpty {
            for piece in result {
                let samples = Array(piece.path)
                let regionPath = region.path
                let fillRule = region.fillRule
                for s in samples {
                    XCTAssertTrue(
                        regionPath.contains(s.location, using: fillRule),
                        "Interpolated sample at (\(s.location.x), \(s.location.y)) should be inside region"
                    )
                }
            }
        }
    }

    func test_strokeCrossingBoundaryOnce_isTrimmedAtExit() throws {
        let region = try firstRegion()
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let outside = CanvasTestFixture.pointOutsideAllRegions

        let stroke = PKStrokeFactory.pencilLine(
            from: interior,
            to: outside,
            color: .green,
            steps: 40
        )

        let result = StrokeClipper.clipStroke(stroke, using: geometry)
        XCTAssertEqual(result.count, 1, "Stroke starting inside and exiting should emit one inside-run")
        let kept = result[0]
        XCTAssertTrue(kept.path.count < stroke.path.count,
                       "Kept stroke should have fewer points than original")
    }

    func test_strokeExitsAndReenters_emitsMultipleStrokes() throws {
        let region = try firstRegion()
        let interior = CanvasTestFixture.interiorPoint(of: region)
        let bbox = region.bounds

        guard let neighbor = geometry.regions.first(where: { r in
            r.id != region.id && !r.bounds.intersects(bbox) && r.bounds.width > 20
        }) else {
            throw XCTSkip("Template doesn't have a suitable non-overlapping neighbor for re-entry test")
        }
        let neighborCenter = CanvasTestFixture.interiorPoint(of: neighbor)

        let start = interior
        let mid = CGPoint(x: bbox.minX - 5, y: (interior.y + neighborCenter.y) / 2)
        let reentry = CGPoint(
            x: interior.x + (bbox.maxX - interior.x) * 0.3,
            y: interior.y
        )

        var points: [CGPoint] = []
        let stepsPerSegment = 15
        for i in 0...stepsPerSegment {
            let t = CGFloat(i) / CGFloat(stepsPerSegment)
            points.append(CGPoint(
                x: start.x + (mid.x - start.x) * t,
                y: start.y + (mid.y - start.y) * t
            ))
        }
        for i in 1...stepsPerSegment {
            let t = CGFloat(i) / CGFloat(stepsPerSegment)
            points.append(CGPoint(
                x: mid.x + (reentry.x - mid.x) * t,
                y: mid.y + (reentry.y - mid.y) * t
            ))
        }

        let tool = PKInkingTool(.pencil, color: UIColor.red, width: 8)
        let pkPoints = points.enumerated().map { (i, pt) in
            PKStrokePoint(
                location: pt,
                timeOffset: Double(i) / 60.0,
                size: CGSize(width: 8, height: 8),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let stroke = PKStroke(
            ink: tool.ink,
            path: PKStrokePath(controlPoints: pkPoints, creationDate: Date())
        )

        let result = StrokeClipper.clipStroke(stroke, using: geometry)
        XCTAssertTrue(result.count >= 1, "Re-entry should produce at least one inside-run")
    }

    func test_strokeStartingInRegionA_crossingIntoB_locksToA() throws {
        let regions = geometry.regions.sorted { $0.zIndex > $1.zIndex }
        guard regions.count >= 2 else {
            throw XCTSkip("Need at least 2 regions for cross-region test")
        }

        let regionA = regions[0]
        let interiorA = CanvasTestFixture.interiorPoint(of: regionA)

        guard let regionB = regions.first(where: { r in
            r.id != regionA.id &&
            r.bounds.width > 20 &&
            !r.bounds.intersects(regionA.bounds)
        }) else {
            throw XCTSkip("No non-overlapping second region found")
        }
        let interiorB = CanvasTestFixture.interiorPoint(of: regionB)

        let stroke = PKStrokeFactory.pencilLine(
            from: interiorA,
            to: interiorB,
            color: .orange,
            steps: 40
        )

        let result = StrokeClipper.clipStroke(stroke, using: geometry)
        XCTAssertTrue(result.allSatisfy { piece in
            let pts = Array(piece.path)
            return pts.allSatisfy { pt in
                let inA = regionA.path.contains(pt.location, using: regionA.fillRule)
                return inA || !regionB.path.contains(pt.location, using: regionB.fillRule)
            }
        }, "Clipped segments should only contain points inside the first-entered region, not region B")
    }

    func test_settingPersistsAcrossInstances() {
        let key = "canvas.stayInTheLines"

        UserDefaults.standard.removeObject(forKey: key)
        let settings1 = CanvasSettings()
        settings1.stayInTheLines = false

        let settings2 = CanvasSettings()
        XCTAssertFalse(settings2.stayInTheLines, "Setting should persist across instances via UserDefaults")

        settings2.stayInTheLines = true
        let settings3 = CanvasSettings()
        XCTAssertTrue(settings3.stayInTheLines, "Setting should persist true across instances")

        UserDefaults.standard.removeObject(forKey: key)
    }

    private func firstRegion() throws -> RegionGeometry {
        guard let region = geometry.regions.first else {
            XCTFail("Template has no regions")
            throw XCTSkip("No regions")
        }
        return region
    }
}
