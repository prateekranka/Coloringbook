import XCTest
import CoreGraphics
@testable import ColorFlow

final class SVGParserTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = TestHelpers.makeTempDirectory()
    }

    override func tearDown() {
        TestHelpers.cleanupTempDirectory(tempDir)
        super.tearDown()
    }

    // MARK: - Error cases

    func test_parse_fileNotFound_returnsFailure() {
        let url = tempDir.appendingPathComponent("nonexistent.svg")
        let result = SVGParser.parse(url: url)
        if case .failure(.fileNotFound) = result { } else {
            XCTFail("Expected .fileNotFound, got \(result)")
        }
    }

    func test_parse_invalidXML_returnsFailure() {
        let url = SVGFixtures.writeSVG("<svg><broken", to: tempDir)
        let result = SVGParser.parse(url: url)
        if case .failure(.invalidXML) = result { } else {
            XCTFail("Expected .invalidXML, got \(result)")
        }
    }

    func test_parse_missingViewBox_returnsFailure() {
        let content = #"<svg xmlns="http://www.w3.org/2000/svg"></svg>"#
        let url = SVGFixtures.writeSVG(content, to: tempDir)
        let result = SVGParser.parse(url: url)
        if case .failure(.missingViewBox) = result { } else {
            XCTFail("Expected .missingViewBox, got \(result)")
        }
    }

    func test_parse_minimalValidSVG_returnsSuccess() {
        let content = SVGFixtures.minimalSVG(viewBox: "0 0 100 100", body: "")
        let url = SVGFixtures.writeSVG(content, to: tempDir)
        let result = SVGParser.parse(url: url)
        if case .success(let geo) = result {
            XCTAssertEqual(geo.viewBox, CGRect(x: 0, y: 0, width: 100, height: 100))
            XCTAssertTrue(geo.regions.isEmpty)
        } else {
            XCTFail("Expected success, got \(result)")
        }
    }

    func test_parse_viewBoxParsesCorrectly() {
        let content = SVGFixtures.minimalSVG(viewBox: "10 20 300 400", body: "")
        let url = SVGFixtures.writeSVG(content, to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.viewBox.origin.x, 10)
        XCTAssertEqual(geo.viewBox.origin.y, 20)
        XCTAssertEqual(geo.viewBox.width, 300)
        XCTAssertEqual(geo.viewBox.height, 400)
    }

    // MARK: - Rect

    func test_parse_rectWithID_becomesRegion() {
        let body = #"<rect id="r1" x="10" y="10" width="80" height="80"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 1)
        XCTAssertEqual(geo.regions[0].id, "r1")
        XCTAssertTrue(geo.decorativePaths.isEmpty)
    }

    func test_parse_rectWithoutID_becomesDecorativePath() {
        let body = #"<rect x="10" y="10" width="80" height="80"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.decorativePaths.count, 1)
        XCTAssertTrue(geo.regions.isEmpty)
    }

    func test_parse_rectZeroWidthIgnored() {
        let body = #"<rect id="r1" x="0" y="0" width="0" height="10"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(geo.regions.isEmpty)
        XCTAssertTrue(geo.decorativePaths.isEmpty)
    }

    func test_parse_rectRoundedCorners() {
        let body = #"<rect id="r1" x="0" y="0" width="100" height="100" rx="10"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    // MARK: - Circle / Ellipse

    func test_parse_circleWithID_becomesRegion() {
        let body = #"<circle id="c1" cx="50" cy="50" r="40"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 1)
        XCTAssertEqual(geo.regions[0].id, "c1")
    }

    func test_parse_circleZeroRadiusIgnored() {
        let body = #"<circle id="c1" cx="50" cy="50" r="0"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(geo.regions.isEmpty)
    }

    func test_parse_ellipseWithID_becomesRegion() {
        let body = #"<ellipse id="e1" cx="50" cy="50" rx="30" ry="20"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 1)
        XCTAssertEqual(geo.regions[0].id, "e1")
    }

    func test_parse_ellipseZeroRxIgnored() {
        let body = #"<ellipse id="e1" cx="50" cy="50" rx="0" ry="20"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(geo.regions.isEmpty)
    }

    // MARK: - Polygon

    func test_parse_polygonTriangle() {
        let body = #"<polygon id="tri1" points="0,0 100,0 50,87"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 1)
        XCTAssertEqual(geo.regions[0].id, "tri1")
    }

    func test_parse_polygonOddPointCount_returnsFailure() {
        let body = #"<polygon id="p1" points="1,2,3"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.invalidPathData) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .invalidPathData for odd point count")
        }
    }

    func test_parse_polygonTooFewPoints_returnsFailure() {
        let body = #"<polygon id="p1" points="1,2"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.invalidPathData) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .invalidPathData for too few points")
        }
    }

    // MARK: - Path commands

    func test_parse_pathMoveTo_LineTo() {
        let body = #"<path id="p1" d="M 0 0 L 100 0 L 100 100 Z"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 1)
    }

    func test_parse_pathRelativeCommands() {
        let body = #"<path id="p1" d="m 0 0 l 100 0 l 0 100 z"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    func test_parse_pathHorizontalVertical() {
        let body = #"<path id="p1" d="M0,0 H100 V100 H0 Z"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    func test_parse_pathCubicBezier() {
        let body = #"<path id="p1" d="M0,0 C10,20 30,40 50,50"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    func test_parse_pathSmoothCubic() {
        let body = #"<path id="p1" d="M0,0 C10,10 20,20 30,30 S50,50 60,60"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    func test_parse_pathQuadraticBezier() {
        let body = #"<path id="p1" d="M0,0 Q50,100 100,0"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    func test_parse_pathSmoothQuadratic() {
        let body = #"<path id="p1" d="M0,0 Q50,50 100,0 T200,0"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    func test_parse_pathArcCommand_returnsFailure() {
        let body = #"<path id="p1" d="M0,0 A25,25 0 1,1 50,0"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.unsupportedArcCommand) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedArcCommand")
        }
    }

    func test_parse_pathArcLowercase_returnsFailure() {
        let body = #"<path id="p1" d="M0,0 a25,25 0 1,1 50,0"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.unsupportedArcCommand) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedArcCommand for lowercase arc")
        }
    }

    func test_parse_pathScientificNotation() {
        let body = #"<path id="p1" d="M1.5e1,2E1 L5e1,5e1 Z"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success (scientific notation), got \(err)")
        }
    }

    func test_parse_pathImplicitLineTo() {
        // After M, additional coordinate pairs are implicit L commands (SVG spec 8.3.2)
        let body = #"<path id="p1" d="M0,0 10,10 20,20"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success for implicit lineto, got \(err)")
        }
    }

    // MARK: - Groups / Transforms

    func test_parse_groupTranslate() {
        let body = #"<g transform="translate(10,20)"><rect id="r1" x="0" y="0" width="50" height="50"/></g>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 1)
        // The bounds should be offset by the translate
        XCTAssertEqual(geo.regions[0].bounds.origin.x, 10, accuracy: 0.01)
        XCTAssertEqual(geo.regions[0].bounds.origin.y, 20, accuracy: 0.01)
    }

    func test_parse_groupTranslateOneParam() {
        let body = #"<g transform="translate(15)"><rect id="r1" x="0" y="0" width="50" height="50"/></g>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success, got \(err)")
        }
    }

    func test_parse_nestedGroups() {
        let body = #"<g transform="translate(10,0)"><g transform="translate(0,10)"><rect id="r1" x="0" y="0" width="50" height="50"/></g></g>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions[0].bounds.origin.x, 10, accuracy: 0.01)
        XCTAssertEqual(geo.regions[0].bounds.origin.y, 10, accuracy: 0.01)
    }

    func test_parse_groupRotate_returnsFailure() {
        let body = #"<g transform="rotate(45)"><rect id="r1" x="0" y="0" width="10" height="10"/></g>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.unsupportedTransform) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedTransform for rotate")
        }
    }

    func test_parse_groupScale_returnsFailure() {
        let body = #"<g transform="scale(2)"><rect id="r1" x="0" y="0" width="10" height="10"/></g>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.unsupportedTransform) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedTransform for scale")
        }
    }

    func test_parse_groupMatrix_returnsFailure() {
        let body = #"<g transform="matrix(1,0,0,1,0,0)"><rect id="r1" x="0" y="0" width="10" height="10"/></g>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.unsupportedTransform) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedTransform for matrix")
        }
    }

    // MARK: - Rejected elements

    func test_parse_rejectedElement_filter() {
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: SVGFixtures.svgWithFilter), to: tempDir)
        if case .failure(.unsupportedElement) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedElement for filter")
        }
    }

    func test_parse_rejectedElement_linearGradient() {
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: SVGFixtures.svgWithLinearGradient), to: tempDir)
        if case .failure(.unsupportedElement) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedElement for linearGradient")
        }
    }

    func test_parse_rejectedAttribute_opacity() {
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: SVGFixtures.svgWithOpacityAttr), to: tempDir)
        if case .failure(.unsupportedElement) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedElement for opacity attribute")
        }
    }

    func test_parse_rejectedAttribute_strokeDasharray() {
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: SVGFixtures.svgWithDasharrayAttr), to: tempDir)
        if case .failure(.unsupportedElement) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedElement for stroke-dasharray attribute")
        }
    }

    func test_parse_allowedElements_skipped() {
        let body = #"<defs/><title>Test</title><desc>Description</desc>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(let err) = SVGParser.parse(url: url) {
            XCTFail("Expected success for defs/title/desc, got \(err)")
        }
    }

    func test_parse_unknownElement_returnsFailure() {
        let body = #"<text>Hello</text>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        if case .failure(.unsupportedElement) = SVGParser.parse(url: url) { } else {
            XCTFail("Expected .unsupportedElement for <text>")
        }
    }

    // MARK: - Fill rule

    func test_parse_fillRuleEvenOdd() {
        let body = #"<path id="p1" fill-rule="evenodd" d="M0,0 L100,0 L100,100 Z"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions[0].fillRule, .evenOdd)
    }

    func test_parse_fillRuleDefaultWinding() {
        let body = #"<path id="p1" d="M0,0 L100,0 L100,100 Z"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions[0].fillRule, .winding)
    }

    // MARK: - zIndex ordering

    func test_parse_zIndexMatchesDocumentOrder() {
        let body = """
        <rect id="r1" x="0" y="0" width="30" height="30"/>
        <circle id="c1" cx="50" cy="50" r="20"/>
        <path id="p1" d="M70,0 L100,0 L100,30 Z"/>
        """
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 3)
        let sorted = geo.regions.sorted { $0.zIndex < $1.zIndex }
        XCTAssertEqual(sorted[0].id, "r1")
        XCTAssertEqual(sorted[1].id, "c1")
        XCTAssertEqual(sorted[2].id, "p1")
    }

    func test_parse_regionBoundsMatchPathBounds() {
        let body = #"<rect id="r1" x="10" y="20" width="80" height="60"/>"#
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        let region = geo.regions[0]
        XCTAssertEqual(region.bounds.origin.x, region.path.boundingBoxOfPath.origin.x, accuracy: 0.01)
        XCTAssertEqual(region.bounds.origin.y, region.path.boundingBoxOfPath.origin.y, accuracy: 0.01)
    }

    func test_parse_multipleRegionsAndDecorativePaths() {
        let body = """
        <rect id="r1" x="0" y="0" width="30" height="30"/>
        <rect x="40" y="0" width="30" height="30"/>
        <circle id="c1" cx="50" cy="50" r="20"/>
        """
        let url = SVGFixtures.writeSVG(SVGFixtures.minimalSVG(body: body), to: tempDir)
        guard case .success(let geo) = SVGParser.parse(url: url) else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(geo.regions.count, 2)
        XCTAssertEqual(geo.decorativePaths.count, 1)
    }
}
