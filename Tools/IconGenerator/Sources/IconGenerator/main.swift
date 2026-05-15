import SwiftUI
import AppKit

// MARK: - Icon View
struct IconView: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        ZStack {
            // Cream watercolor paper background
            Color(red: 0.98, green: 0.96, blue: 0.94)
                .overlay(
                    Color.white.opacity(0.3)
                        .blendMode(.overlay)
                )
            
            // "G" monogram brushstroke
            Text("G")
                .font(.system(size: size * 0.55, weight: .light, design: .serif))
                .foregroundColor(Color(red: 0.35, green: 0.55, blue: 0.65))
                .offset(x: size * 0.02, y: size * 0.02)
                .shadow(
                    color: Color(red: 0.35, green: 0.55, blue: 0.65).opacity(0.3),
                    radius: size * 0.02,
                    x: size * 0.01,
                    y: size * 0.01
                )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Icon Spec
struct IconSpec: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let size: CGSize
    let scale: Int
    let idiom: IconIdiom
    
    var filename: String {
        let scaleSuffix = scale > 1 ? "@\(scale)x" : ""
        return "AppIcon-\(name)\(scaleSuffix).png"
    }
    
    var pixelSize: CGSize {
        CGSize(width: size.width * CGFloat(scale), height: size.height * CGFloat(scale))
    }
}

enum IconIdiom: String {
    case iPad = "ipad"
    case marketing = "ios-marketing"
}

let allSpecs: [IconSpec] = [
    IconSpec(name: "20", size: CGSize(width: 20, height: 20), scale: 1, idiom: .iPad),
    IconSpec(name: "20x20", size: CGSize(width: 20, height: 20), scale: 2, idiom: .iPad),
    IconSpec(name: "29", size: CGSize(width: 29, height: 29), scale: 1, idiom: .iPad),
    IconSpec(name: "29x29", size: CGSize(width: 29, height: 29), scale: 2, idiom: .iPad),
    IconSpec(name: "40", size: CGSize(width: 40, height: 40), scale: 1, idiom: .iPad),
    IconSpec(name: "40x40", size: CGSize(width: 40, height: 40), scale: 2, idiom: .iPad),
    IconSpec(name: "76", size: CGSize(width: 76, height: 76), scale: 1, idiom: .iPad),
    IconSpec(name: "76x76", size: CGSize(width: 76, height: 76), scale: 2, idiom: .iPad),
    IconSpec(name: "83.5x83.5", size: CGSize(width: 83.5, height: 83.5), scale: 2, idiom: .iPad),
    IconSpec(name: "1024", size: CGSize(width: 1024, height: 1024), scale: 1, idiom: .marketing),
]

struct ContentsJSON: Codable {
    struct Image: Codable {
        let filename: String
        let idiom: String
        let scale: String
        let size: String
    }
    struct Info: Codable {
        let author: String
        let version: Int
    }
    let images: [Image]
    let info: Info
}

// MARK: - Generation
@MainActor
func generateIcons(outputDirectory: URL) async throws {
    let fileManager = FileManager.default
    try? fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    
    print("🎨 Generating \(allSpecs.count) icon sizes...")
    
    for spec in allSpecs {
        let pixelSize = spec.pixelSize
        let cornerRadius: CGFloat = spec.idiom == .marketing 
            ? pixelSize.width * 0.224
            : pixelSize.width * 0.225
        
        let iconView = IconView(size: pixelSize.width, cornerRadius: cornerRadius)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0
        
        guard let nsImage = renderer.nsImage else {
            print("❌ Failed to render: \(spec.filename)")
            continue
        }
        
        let fileURL = outputDirectory.appendingPathComponent(spec.filename)
        
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("❌ Failed to encode PNG: \(spec.filename)")
            continue
        }
        
        try pngData.write(to: fileURL)
        print("✓ \(spec.filename) (\(Int(pixelSize.width))×\(Int(pixelSize.height))px)")
    }
    
    // Generate Contents.json
    let images = allSpecs.map { spec in
        ContentsJSON.Image(
            filename: spec.filename,
            idiom: spec.idiom.rawValue,
            scale: "\(spec.scale)x",
            size: "\(Int(spec.size.width))x\(Int(spec.size.height))"
        )
    }
    
    let contentsJSON = ContentsJSON(
        images: images,
        info: ContentsJSON.Info(author: "gouache-icon-generator", version: 1)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(contentsJSON)
    let contentsURL = outputDirectory.appendingPathComponent("Contents.json")
    try jsonData.write(to: contentsURL)
    print("✓ Contents.json")
    
    print("\n✅ Icons generated in: \(outputDirectory.path)")
}

// MARK: - Main
@main
struct IconGeneratorCLI {
    static func main() async {
        // Default output to the project's asset catalog
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let outputDir = repoRoot
            .appendingPathComponent("ColorFlow")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("AppIcon.appiconset")
        
        print("Icon Generator for Gouache")
        print("Output directory: \(outputDir.path)")
        
        // Check if directory exists
        if !FileManager.default.fileExists(atPath: outputDir.path) {
            print("⚠️  AppIcon.appiconset not found at expected location.")
            print("Creating directory...")
        }
        
        do {
            try await generateIcons(outputDirectory: outputDir)
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }
}
