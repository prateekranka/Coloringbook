import XCTest
import SwiftUI
import UIKit
@testable import ColorFlow

final class ColorExtensionsTests: XCTestCase {

    private func components(of color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    // MARK: - UIColor.hexString

    func test_UIColor_hexString_redIsFF0000() {
        XCTAssertEqual(UIColor.red.hexString, "FF0000")
    }

    func test_UIColor_hexString_greenIs00FF00() {
        XCTAssertEqual(UIColor.green.hexString, "00FF00")
    }

    func test_UIColor_hexString_blueIs0000FF() {
        XCTAssertEqual(UIColor.blue.hexString, "0000FF")
    }

    func test_UIColor_hexString_blackIs000000() {
        XCTAssertEqual(UIColor.black.hexString, "000000")
    }

    func test_UIColor_hexString_whiteIsFFFFFF() {
        XCTAssertEqual(UIColor.white.hexString, "FFFFFF")
    }

    // MARK: - UIColor(hex:)

    func test_UIColor_initHex_6charWithHash() {
        let color = UIColor(hex: "#FF5733")
        let c = components(of: color)
        XCTAssertEqual(c.r, 255.0/255, accuracy: 0.01)
        XCTAssertEqual(c.g, 87.0/255, accuracy: 0.01)
        XCTAssertEqual(c.b, 51.0/255, accuracy: 0.01)
    }

    func test_UIColor_initHex_6charWithoutHash() {
        let withHash    = UIColor(hex: "#FF5733")
        let withoutHash = UIColor(hex: "FF5733")
        let c1 = components(of: withHash)
        let c2 = components(of: withoutHash)
        XCTAssertEqual(c1.r, c2.r, accuracy: 0.01)
        XCTAssertEqual(c1.g, c2.g, accuracy: 0.01)
        XCTAssertEqual(c1.b, c2.b, accuracy: 0.01)
    }

    func test_UIColor_initHex_roundTrip() {
        let original = UIColor.red
        let roundTripped = UIColor(hex: original.hexString)
        let c1 = components(of: original)
        let c2 = components(of: roundTripped)
        XCTAssertEqual(c1.r, c2.r, accuracy: 0.01)
        XCTAssertEqual(c1.g, c2.g, accuracy: 0.01)
        XCTAssertEqual(c1.b, c2.b, accuracy: 0.01)
    }

    // MARK: - Color(hex:)

    func test_Color_initHex_6char() {
        let color = Color(hex: "#FF5733")
        let uiColor = UIColor(color)
        let c = components(of: uiColor)
        XCTAssertEqual(c.r, 255.0/255, accuracy: 0.01)
        XCTAssertEqual(c.g, 87.0/255, accuracy: 0.01)
        XCTAssertEqual(c.b, 51.0/255, accuracy: 0.01)
    }

    func test_Color_initHex_8char_withAlpha() {
        // 8-char hex includes alpha in last 2 chars
        let color = Color(hex: "#FF573380")
        let uiColor = UIColor(color)
        let c = components(of: uiColor)
        XCTAssertEqual(c.r, 255.0/255, accuracy: 0.01)
        XCTAssertEqual(c.g, 87.0/255, accuracy: 0.01)
        XCTAssertEqual(c.b, 51.0/255, accuracy: 0.01)
        XCTAssertEqual(c.a, 128.0/255, accuracy: 0.02)
    }

    func test_Color_initHex_invalidLength_fallsBackToBlack() {
        let color = Color(hex: "abc")
        let uiColor = UIColor(color)
        let c = components(of: uiColor)
        XCTAssertEqual(c.r, 0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
    }

    func test_Color_initHex_emptyString_fallsBackToBlack() {
        let color = Color(hex: "")
        let uiColor = UIColor(color)
        let c = components(of: uiColor)
        XCTAssertEqual(c.r, 0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
    }

    func test_Color_initHex_lowercaseHex() {
        let lower = Color(hex: "ff5733")
        let upper = Color(hex: "FF5733")
        let c1 = components(of: UIColor(lower))
        let c2 = components(of: UIColor(upper))
        XCTAssertEqual(c1.r, c2.r, accuracy: 0.01)
        XCTAssertEqual(c1.g, c2.g, accuracy: 0.01)
        XCTAssertEqual(c1.b, c2.b, accuracy: 0.01)
    }
}
