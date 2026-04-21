import XCTest
@testable import ColorFlow

final class SVGAssemblerTests: XCTestCase {

    // MARK: - Path data generation

    func test_pathData_closedSquare_endsWithZ() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        path.addLine(to: CGPoint(x: 0, y: 10))
        path.closeSubpath()

        let d = SVGAssembler.pathData(from: path)
        XCTAssertTrue(d.hasSuffix("Z"), "Path data must end with Z: \(d)")
        XCTAssertTrue(d.hasPrefix("M"), "Path data must start with M: \(d)")
        XCTAssertFalse(d.contains("A"), "Path data must not contain arc commands: \(d)")
    }

    func test_pathData_openPath_getsClosedByAssembler() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        // No closeSubpath()

        let d = SVGAssembler.pathData(from: path)
        XCTAssertTrue(d.hasSuffix("Z"), "Assembler must close unclosed paths: \(d)")
    }

    // MARK: - SVG structure

    func test_assemble_producesValidXML() throws {
        let result = makeFakeVectorizationResult(regionCount: 3, decorativeCount: 1)
        let svg = try SVGAssembler.assemble(result, templateName: "Test Template")

        XCTAssertTrue(svg.contains("viewBox=\"0 0 100 100\""), "SVG must have viewBox")
        XCTAssertTrue(svg.contains("id=\"region-1\""), "First region must have id=region-1")
        XCTAssertTrue(svg.contains("id=\"region-3\""), "Third region must have id=region-3")
        XCTAssertFalse(svg.contains("id=\"region-4\""), "Should not have region-4 (only 3 regions)")
        XCTAssertTrue(svg.contains("<svg"), "Must start with <svg element")
        XCTAssertTrue(svg.contains("</svg>"), "Must end with </svg>")
    }

    func test_assemble_svgParsesSuccessfully() throws {
        let result = makeFakeVectorizationResult(regionCount: 5, decorativeCount: 0)
        let svg = try SVGAssembler.assemble(result, templateName: "Parity Test")

        // Write to temp file and parse
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".svg")
        try svg.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        switch SVGParser.parse(url: tmpURL) {
        case .success(let geo):
            XCTAssertGreaterThanOrEqual(geo.regions.count, 1,
                "At least one fillable region should be detected")
            XCTAssertGreaterThan(geo.viewBox.width, 0)
            XCTAssertGreaterThan(geo.viewBox.height, 0)
        case .failure(let error):
            XCTFail("SVGParser rejected assembler output: \(error.localizedDescription)")
        }
    }

    func test_assemble_hardLimitExceeded_throws() {
        let result = makeFakeVectorizationResult(
            regionCount: SVGAssembler.pathCountHardLimit + 1,
            decorativeCount: 0
        )
        XCTAssertThrowsError(try SVGAssembler.assemble(result, templateName: "Overflow")) { error in
            guard let pipelineError = error as? PhotoPipelineError,
                  case .svgAssemblyFailed = pipelineError else {
                XCTFail("Expected PhotoPipelineError.svgAssemblyFailed, got \(error)")
                return
            }
        }
    }

    func test_assemble_escapesTitleXML() throws {
        let result = makeFakeVectorizationResult(regionCount: 1, decorativeCount: 0)
        let svg = try SVGAssembler.assemble(result, templateName: "A & B <test>")
        XCTAssertTrue(svg.contains("A &amp; B &lt;test&gt;"),
                      "Template name must be XML-escaped in the SVG title")
    }

    // MARK: - Helpers

    private func makeFakeVectorizationResult(
        regionCount: Int,
        decorativeCount: Int
    ) -> ContourVectorizer.VectorizationResult {
        func makeSquarePath(x: CGFloat, y: CGFloat, size: CGFloat) -> CGPath {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x + size, y: y))
            p.addLine(to: CGPoint(x: x + size, y: y + size))
            p.addLine(to: CGPoint(x: x, y: y + size))
            p.closeSubpath()
            return p
        }

        let regions: [CGPath] = (0..<regionCount).map { i in
            makeSquarePath(x: CGFloat(i) * 10, y: 0, size: 9)
        }
        let decorative: [CGPath] = (0..<decorativeCount).map { i in
            makeSquarePath(x: CGFloat(i) * 5, y: 50, size: 4)
        }

        return ContourVectorizer.VectorizationResult(
            regionPaths:    regions,
            decorativePaths: decorative,
            imageSize: CGSize(width: 100, height: 100)
        )
    }
}
