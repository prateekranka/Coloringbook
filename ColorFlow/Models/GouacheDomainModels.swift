import CoreGraphics
import Foundation
import SwiftUI

enum TemplateMood: String, CaseIterable, Identifiable, Codable {
    case calm
    case bold
    case dreamy
    case focus

    var id: Self { self }

    var title: String {
        rawValue.capitalized
    }

    var accentHex: String {
        switch self {
        case .calm:
            return "#2BBCB3"
        case .bold:
            return "#D4213D"
        case .dreamy:
            return "#7B68AE"
        case .focus:
            return "#6F8E62"
        }
    }

    var color: Color {
        Color(hex: accentHex)
    }

    func includes(template: Template) -> Bool {
        switch self {
        case .calm:
            return template.category == .botanicals || template.category == .mandalas
        case .bold:
            return template.category == .abstract || template.difficulty == .hard
        case .dreamy:
            return template.category == .lifestyle || template.name.localizedCaseInsensitiveContains("garden")
        case .focus:
            return template.category == .architecture || template.difficulty == .medium
        }
    }
}

enum ToolType: String, CaseIterable, Identifiable, Codable {
    case crayon = "Crayon"
    case coloredPencil = "Colored Pencil"
    case watercolor = "Watercolor"
    case marker = "Marker"
    case sprayPaint = "Spray Paint"
    case eraser = "Eraser"
    case fillBucket = "Fill Bucket"

    var id: Self { self }

    var systemImageName: String {
        switch self {
        case .crayon:
            return "scribble.variable"
        case .coloredPencil:
            return "pencil"
        case .watercolor:
            return "paintbrush"
        case .marker:
            return "highlighter"
        case .sprayPaint:
            return "paintbrush.pointed"
        case .eraser:
            return "eraser"
        case .fillBucket:
            return "drop.fill"
        }
    }

    var defaultSettings: ToolSettings {
        switch self {
        case .crayon:
            return ToolSettings(tool: self, size: 18, opacity: 0.78, textureAmount: 0.62)
        case .coloredPencil:
            return ToolSettings(tool: self, size: 7, opacity: 0.86, textureAmount: 0.45)
        case .watercolor:
            return ToolSettings(tool: self, size: 28, opacity: 0.38, textureAmount: 0.72)
        case .marker:
            return ToolSettings(tool: self, size: 20, opacity: 0.68, textureAmount: 0.18)
        case .sprayPaint:
            return ToolSettings(tool: self, size: 34, opacity: 0.36, textureAmount: 0.86)
        case .eraser:
            return ToolSettings(tool: self, size: 30, opacity: 1, textureAmount: 0)
        case .fillBucket:
            return ToolSettings(tool: self, size: 1, opacity: 1, textureAmount: 0)
        }
    }

    var supportsSizeControl: Bool {
        self != .fillBucket
    }

    var supportsOpacityControl: Bool {
        switch self {
        case .crayon, .coloredPencil, .watercolor, .marker, .sprayPaint:
            return true
        case .eraser, .fillBucket:
            return false
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .sprayPaint:
            return "Spray"
        default:
            return rawValue
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .sprayPaint:
            return "canvas.tool.spray"
        default:
            return "canvas.tool.\(rawValue.normalizedIdentifier)"
        }
    }
}

typealias PigmentTool = ToolType
typealias StrokeContainmentMode = CanvasColoringMode

struct ToolSettings: Codable, Equatable {
    static let sizeRange: ClosedRange<CGFloat> = 1...50
    static let opacityRange: ClosedRange<Double> = 0.1...1

    var tool: ToolType
    var size: CGFloat
    var opacity: Double
    var textureAmount: Double
}

enum CanvasColoringMode: String, CaseIterable, Identifiable, Codable {
    case clean = "Clean"
    case free = "Free"

    var id: Self { self }
}

struct GestureSettings: Codable, Equatable {
    var fingerPansCanvas = true
    var pencilColors = true
    var fingerPaints = false
    var twoFingerTapUndo = true
    var threeFingerTapRedo = true
}

struct CanvasState: Codable, Equatable {
    var zoomScale: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0
    var selectedTool: ToolType = .crayon
    var coloringMode: CanvasColoringMode = .clean
}

struct StrokeAction: Identifiable, Codable, Equatable {
    let id: UUID
    var tool: ToolType
    var colorHex: String
    var points: [CodablePoint]
    var samples: [StrokeSample]
    var highFidelitySamples: [StrokeSample]
    var seed: UInt64?
    var clippedRegionID: String?
    var size: Double
    var opacity: Double

    init(
        id: UUID = UUID(),
        tool: ToolType,
        colorHex: String,
        points: [CodablePoint],
        samples: [StrokeSample]? = nil,
        highFidelitySamples: [StrokeSample]? = nil,
        seed: UInt64? = nil,
        clippedRegionID: String?,
        size: Double,
        opacity: Double
    ) {
        self.id = id
        self.tool = tool
        self.colorHex = colorHex
        self.points = points
        self.samples = samples ?? points.map { StrokeSample(point: $0) }
        self.highFidelitySamples = highFidelitySamples ?? self.samples
        self.seed = seed
        self.clippedRegionID = clippedRegionID
        self.size = size
        self.opacity = opacity
    }

    var renderSamples: [StrokeSample] {
        if !highFidelitySamples.isEmpty {
            return highFidelitySamples
        }
        return samples.isEmpty ? points.map { StrokeSample(point: $0) } : samples
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case tool
        case colorHex
        case points
        case samples
        case highFidelitySamples
        case seed
        case clippedRegionID
        case size
        case opacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tool = try container.decode(ToolType.self, forKey: .tool)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        let decodedSamples = try container.decodeIfPresent([StrokeSample].self, forKey: .samples)
        let decodedHighFidelitySamples = try container.decodeIfPresent([StrokeSample].self, forKey: .highFidelitySamples)
        points = try container.decodeIfPresent([CodablePoint].self, forKey: .points)
            ?? decodedSamples?.map(\.point)
            ?? []
        samples = decodedSamples ?? points.map { StrokeSample(point: $0) }
        highFidelitySamples = decodedHighFidelitySamples ?? samples
        seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        clippedRegionID = try container.decodeIfPresent(String.self, forKey: .clippedRegionID)
        size = try container.decode(Double.self, forKey: .size)
        opacity = try container.decode(Double.self, forKey: .opacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tool, forKey: .tool)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(points, forKey: .points)
        if samples.contains(where: \.hasExtendedData) || samples.map(\.point) != points {
            try container.encode(samples, forKey: .samples)
        }
        if highFidelitySamples != samples {
            try container.encode(highFidelitySamples, forKey: .highFidelitySamples)
        }
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encodeIfPresent(clippedRegionID, forKey: .clippedRegionID)
        try container.encode(size, forKey: .size)
        try container.encode(opacity, forKey: .opacity)
    }
}

struct CodablePoint: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        x = Double(point.x)
        y = Double(point.y)
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

struct StrokeSample: Codable, Equatable {
    var point: CodablePoint
    var timestamp: TimeInterval?
    var force: Double?
    var altitude: Double?
    var azimuth: Double?
    var isPredicted: Bool?

    init(
        point: CodablePoint,
        timestamp: TimeInterval? = nil,
        force: Double? = nil,
        altitude: Double? = nil,
        azimuth: Double? = nil,
        isPredicted: Bool? = nil
    ) {
        self.point = point
        self.timestamp = timestamp
        self.force = force
        self.altitude = altitude
        self.azimuth = azimuth
        self.isPredicted = isPredicted
    }

    init(
        point: CGPoint,
        timestamp: TimeInterval? = nil,
        force: Double? = nil,
        altitude: Double? = nil,
        azimuth: Double? = nil,
        isPredicted: Bool? = nil
    ) {
        self.init(
            point: CodablePoint(point),
            timestamp: timestamp,
            force: force,
            altitude: altitude,
            azimuth: azimuth,
            isPredicted: isPredicted
        )
    }

    var cgPoint: CGPoint {
        point.cgPoint
    }

    var hasExtendedData: Bool {
        timestamp != nil || force != nil || altitude != nil || azimuth != nil || isPredicted != nil
    }
}

struct StrokeRenderClip {
    let path: CGPath
    let fillRule: CGPathFillRule
}

protocol TemplateMask {
    var regions: [RegionMetadata] { get }
    func region(containing point: CGPoint) -> RegionMetadata?
}

struct RegionMetadata: Identifiable, Hashable {
    let id: String
    let bounds: CGRect
    let zIndex: Int
}

struct GeometryTemplateMask: TemplateMask {
    let geometry: TemplateGeometry

    var regions: [RegionMetadata] {
        geometry.regions.map { region in
            RegionMetadata(id: region.id, bounds: region.bounds, zIndex: region.zIndex)
        }
    }

    func region(containing point: CGPoint) -> RegionMetadata? {
        geometry.region(at: point).map { region in
            RegionMetadata(id: region.id, bounds: region.bounds, zIndex: region.zIndex)
        }
    }
}
