import Foundation
import PencilKit
import UIKit

#if DEBUG
@MainActor
enum PersonaSeedLoader {
    static func seedIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-personaRun") else { return }

        var seedName: String?
        for arg in args {
            if arg.hasPrefix("-personaSeed=") {
                seedName = String(arg.dropFirst("-personaSeed=".count))
                break
            }
        }

        guard let name = seedName else {
            AppLog.error(AppLog.app, "-personaRun set but no -personaSeed= argument found")
            return
        }

        AppLog.trace(AppLog.app, "PersonaSeedLoader: seeding for \(name)")

        if name == "deep-colorist" {
            seedDeepColorist()
        }
    }

    private static func seedDeepColorist() {
        let template = Template(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Sunflower Mandala",
            category: .mandalas,
            difficulty: .easy,
            svgFilename: "sunflower_mandala.svg",
            thumbnailFilename: "thumb_sunflower_mandala.png"
        )

        let project = Project(template: template)
        let service = StorageService()

        let stroke = makePencilStroke(
            from: CGPoint(x: 200, y: 200),
            to: CGPoint(x: 600, y: 600),
            color: .systemRed
        )
        let drawing = PKDrawing(strokes: [stroke])

        var mutableProject = project
        service.save(project: &mutableProject, drawing: drawing, fillLayer: nil, templateImage: nil)
    }

    private static func makePencilStroke(from start: CGPoint, to end: CGPoint, color: UIColor) -> PKStroke {
        let tool = PKInkingTool(.pencil, color: color, width: 8)
        let steps = 20
        var points: [PKStrokePoint] = []
        for i in 0..<steps {
            let t = CGFloat(i) / CGFloat(steps - 1)
            let location = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            points.append(PKStrokePoint(
                location: location,
                timeOffset: Double(i) / 60.0,
                size: CGSize(width: 8, height: 8),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            ))
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: tool.ink, path: path)
    }
}
#endif