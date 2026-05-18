import CoreGraphics
import Foundation

enum BrushType: String, CaseIterable, Identifiable {
    case pencil = "Pencil"
    case marker = "Marker"
    case watercolor = "Watercolor"
    case spray = "Spray"
    case acrylic = "Acrylic"

    var id: Self { self }
}

struct BrushConfiguration: Equatable {
    var brushType: BrushType
    var size: Float
    var opacity: Float
    var color: SIMD4<Float>
    var softness: Float
    var noiseIntensity: Float
    var pressureResponse: Float
    var vertexSpacing: Float

    init(
        brushType: BrushType,
        size: Float = 1.0,
        opacity: Float = 1.0,
        color: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1),
        softness: Float = 0.5,
        noiseIntensity: Float = 0.0,
        pressureResponse: Float = 1.0,
        vertexSpacing: Float = 1.0
    ) {
        self.brushType = brushType
        self.size = max(0.1, size)
        self.opacity = max(0, min(1, opacity))
        self.color = color
        self.softness = max(0, min(1, softness))
        self.noiseIntensity = max(0, min(1, noiseIntensity))
        self.pressureResponse = max(0, min(1, pressureResponse))
        self.vertexSpacing = max(0.5, vertexSpacing)
    }

    init(from toolType: ToolType, settings: ToolSettings, colorHex: String) {
        let resolvedColor = BrushConfiguration.simdFromHex(colorHex)
        let resolvedBrushType: BrushType
        let resolvedSoftness: Float
        let resolvedNoise: Float
        let resolvedPressure: Float
        let resolvedSpacing: Float

        switch toolType {
        case .crayon:
            resolvedBrushType = .pencil
            resolvedSoftness = 0.4
            resolvedNoise = 0.35
            resolvedPressure = 0.8
            resolvedSpacing = 0.8
        case .coloredPencil:
            resolvedBrushType = .pencil
            resolvedSoftness = 0.55
            resolvedNoise = 0.2
            resolvedPressure = 0.9
            resolvedSpacing = 0.5
        case .watercolor:
            resolvedBrushType = .watercolor
            resolvedSoftness = 0.9
            resolvedNoise = 0.15
            resolvedPressure = 0.5
            resolvedSpacing = 1.2
        case .marker:
            resolvedBrushType = .marker
            resolvedSoftness = 0.3
            resolvedNoise = 0.05
            resolvedPressure = 0.3
            resolvedSpacing = 0.6
        case .sprayPaint:
            resolvedBrushType = .spray
            resolvedSoftness = 0.95
            resolvedNoise = 0.8
            resolvedPressure = 0.2
            resolvedSpacing = 1.5
        case .eraser, .fillBucket:
            resolvedBrushType = .marker
            resolvedSoftness = 0.8
            resolvedNoise = 0.0
            resolvedPressure = 0.1
            resolvedSpacing = 1.0
        }

        self.init(
            brushType: resolvedBrushType,
            size: Float(settings.size),
            opacity: Float(settings.opacity),
            color: resolvedColor,
            softness: resolvedSoftness * Float(settings.textureAmount),
            noiseIntensity: resolvedNoise * Float(settings.textureAmount),
            pressureResponse: resolvedPressure,
            vertexSpacing: resolvedSpacing
        )
    }

    static func defaultBrush(kind: BrushType) -> BrushConfiguration {
        switch kind {
        case .pencil:
            return BrushConfiguration(brushType: .pencil, size: 4, opacity: 0.9, softness: 0.4, noiseIntensity: 0.35, pressureResponse: 0.8, vertexSpacing: 0.8)
        case .marker:
            return BrushConfiguration(brushType: .marker, size: 12, opacity: 1.0, softness: 0.3, noiseIntensity: 0.05, pressureResponse: 0.3, vertexSpacing: 0.6)
        case .watercolor:
            return BrushConfiguration(brushType: .watercolor, size: 20, opacity: 0.65, softness: 0.9, noiseIntensity: 0.15, pressureResponse: 0.5, vertexSpacing: 1.2)
        case .spray:
            return BrushConfiguration(brushType: .spray, size: 16, opacity: 0.6, softness: 0.95, noiseIntensity: 0.8, pressureResponse: 0.2, vertexSpacing: 1.5)
        case .acrylic:
            return BrushConfiguration(brushType: .acrylic, size: 8, opacity: 1.0, softness: 0.25, noiseIntensity: 0.04, pressureResponse: 0.7, vertexSpacing: 0.7)
        }
    }

    static func simdFromHex(_ hex: String) -> SIMD4<Float> {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = UInt64(trimmed, radix: 16) else {
            return SIMD4<Float>(0, 0, 0, 1)
        }
        return SIMD4<Float>(
            Float((value >> 16) & 0xFF) / 255.0,
            Float((value >> 8) & 0xFF) / 255.0,
            Float(value & 0xFF) / 255.0,
            1.0
        )
    }
}
