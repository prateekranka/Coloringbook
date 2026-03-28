import Foundation
import XCTest

/// Builds minimal SVG strings and writes them to temporary files for SVGParser tests.
enum SVGFixtures {

    static func minimalSVG(viewBox: String = "0 0 100 100", body: String) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(viewBox)">
        \(body)
        </svg>
        """
    }

    static func writeSVG(_ content: String, to directory: URL, name: String = "test") -> URL {
        let url = directory.appendingPathComponent("\(name).svg")
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // Pre-built SVG bodies
    static let rectRegion = #"<rect id="r1" x="10" y="10" width="80" height="80"/>"#
    static let circleRegion = #"<circle id="c1" cx="50" cy="50" r="40"/>"#
    static let pathWithCubicBezier = #"<path id="p1" d="M 0 0 C 10 20 30 40 50 50 Z"/>"#
    static let polygonTriangle = #"<polygon id="tri1" points="0,0 100,0 50,87"/>"#
    static let rectDecorativeNoID = #"<rect x="10" y="10" width="80" height="80"/>"#

    // Error-triggering bodies
    static let svgWithArcCommand = #"<path id="arc1" d="M0,0 A25,25 0 1,1 50,0"/>"#
    static let svgWithFilter = #"<filter id="f1"/>"#
    static let svgWithLinearGradient = #"<linearGradient id="lg1"/>"#
    static let svgWithRotateTransform = #"<g transform="rotate(45)"><rect id="r1" x="0" y="0" width="10" height="10"/></g>"#
    static let svgWithOpacityAttr = #"<rect id="r1" x="0" y="0" width="10" height="10" opacity="0.5"/>"#
    static let svgWithDasharrayAttr = #"<rect id="r1" x="0" y="0" width="10" height="10" stroke-dasharray="5,5"/>"#
    static let svgMissingViewBox = #"<svg xmlns="http://www.w3.org/2000/svg"></svg>"#
    static let svgInvalidXML = #"<svg><broken"#
}
