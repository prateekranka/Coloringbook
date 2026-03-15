import SwiftUI

struct ColorSwatch: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let hex: String

    var color: Color { Color(hex: hex) }
    var uiColor: UIColor { UIColor(hex: hex) }
}

struct ColorPalette: Identifiable, Codable {
    let id: UUID
    let name: String
    let swatches: [ColorSwatch]

    static func loadAll() -> [ColorPalette] {
        guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let palettes = try? JSONDecoder().decode([ColorPalette].self, from: data) else {
            return ColorPalette.builtIn
        }
        return palettes
    }

    // Fallback built-in palettes if JSON is missing
    static var builtIn: [ColorPalette] {
        [
            ColorPalette(id: UUID(), name: "Pastels", swatches: [
                ColorSwatch(id: UUID(), name: "Baby Pink", hex: "#FFB3C1"),
                ColorSwatch(id: UUID(), name: "Lavender", hex: "#C8B8E8"),
                ColorSwatch(id: UUID(), name: "Mint", hex: "#B8E8C8"),
                ColorSwatch(id: UUID(), name: "Sky", hex: "#B8D8E8"),
                ColorSwatch(id: UUID(), name: "Peach", hex: "#FFD8B8"),
                ColorSwatch(id: UUID(), name: "Lemon", hex: "#FFEFB8"),
            ]),
            ColorPalette(id: UUID(), name: "Earth Tones", swatches: [
                ColorSwatch(id: UUID(), name: "Terracotta", hex: "#C4714A"),
                ColorSwatch(id: UUID(), name: "Sage", hex: "#7A9E7E"),
                ColorSwatch(id: UUID(), name: "Sand", hex: "#D4B896"),
                ColorSwatch(id: UUID(), name: "Bark", hex: "#8B6F47"),
                ColorSwatch(id: UUID(), name: "Clay", hex: "#B5714A"),
                ColorSwatch(id: UUID(), name: "Moss", hex: "#5A7A5A"),
            ]),
            ColorPalette(id: UUID(), name: "Neon", swatches: [
                ColorSwatch(id: UUID(), name: "Hot Pink", hex: "#FF006E"),
                ColorSwatch(id: UUID(), name: "Electric Blue", hex: "#00B4D8"),
                ColorSwatch(id: UUID(), name: "Lime", hex: "#80B918"),
                ColorSwatch(id: UUID(), name: "Orange", hex: "#FF7900"),
                ColorSwatch(id: UUID(), name: "Purple", hex: "#9B5DE5"),
                ColorSwatch(id: UUID(), name: "Yellow", hex: "#FEE440"),
            ]),
            ColorPalette(id: UUID(), name: "Vintage", swatches: [
                ColorSwatch(id: UUID(), name: "Dusty Rose", hex: "#C9888A"),
                ColorSwatch(id: UUID(), name: "Teal", hex: "#457B9D"),
                ColorSwatch(id: UUID(), name: "Cream", hex: "#F1DBBF"),
                ColorSwatch(id: UUID(), name: "Olive", hex: "#6B6B3A"),
                ColorSwatch(id: UUID(), name: "Burgundy", hex: "#7C2A2A"),
                ColorSwatch(id: UUID(), name: "Steel", hex: "#8A9BAE"),
            ]),
        ]
    }
}
