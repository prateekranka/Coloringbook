import XCTest
@testable import ColorFlow

final class ColorPaletteTests: XCTestCase {

    // MARK: - ColorPalette

    func test_builtIn_returnsNonEmpty() {
        let palettes = ColorPalette.builtIn
        XCTAssertFalse(palettes.isEmpty, "builtIn must return at least one palette")
    }

    func test_builtIn_eachPaletteHasNonEmptyName() {
        for palette in ColorPalette.builtIn {
            XCTAssertFalse(palette.name.isEmpty,
                           "Palette id=\(palette.id) has an empty name")
        }
    }

    func test_builtIn_eachPaletteHasSwatches() {
        for palette in ColorPalette.builtIn {
            XCTAssertFalse(palette.swatches.isEmpty,
                           "Palette '\(palette.name)' has no swatches")
        }
    }

    func test_loadAll_returnsNonEmpty() {
        // loadAll falls back to builtIn when the JSON resource is absent (unit-test host).
        let palettes = ColorPalette.loadAll()
        XCTAssertFalse(palettes.isEmpty, "loadAll must return at least one palette")
    }

    func test_codable_paletteRoundTrip() throws {
        let original = ColorPalette(
            id: UUID(),
            name: "Test Palette",
            swatches: [
                ColorSwatch(id: UUID(), name: "Crimson", hex: "#DC143C"),
                ColorSwatch(id: UUID(), name: "Azure",   hex: "#007FFF"),
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorPalette.self, from: data)

        XCTAssertEqual(decoded.id,   original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.swatches.count, original.swatches.count)
    }

    // MARK: - ColorSwatch

    func test_colorSwatch_hexRoundTrip() throws {
        let swatch = ColorSwatch(id: UUID(), name: "Hot Pink", hex: "#FF006E")
        let data = try JSONEncoder().encode(swatch)
        let decoded = try JSONDecoder().decode(ColorSwatch.self, from: data)

        XCTAssertEqual(decoded.id,   swatch.id)
        XCTAssertEqual(decoded.name, swatch.name)
        XCTAssertEqual(decoded.hex,  swatch.hex)
    }

    func test_colorSwatch_color_isNotClear() {
        // Any valid 6-digit hex should produce a non-transparent Color.
        let swatch = ColorSwatch(id: UUID(), name: "Mint", hex: "#B8E8C8")
        // `color` is a computed var; we merely verify it does not crash and returns a value.
        _ = swatch.color
        _ = swatch.uiColor
    }

    func test_colorSwatch_hashable() {
        let id = UUID()
        let a = ColorSwatch(id: id, name: "Sky", hex: "#B8D8E8")
        let b = ColorSwatch(id: id, name: "Sky", hex: "#B8D8E8")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func test_builtIn_uniquePaletteIds() {
        let ids = ColorPalette.builtIn.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All built-in palette IDs must be unique")
    }

    func test_builtIn_swatchCountsMatchExpectation() {
        // Each built-in palette is defined with 6 swatches.
        for palette in ColorPalette.builtIn {
            XCTAssertEqual(palette.swatches.count, 6,
                           "Palette '\(palette.name)' should have 6 swatches")
        }
    }
}
