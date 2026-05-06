import Foundation
import PencilKit
import UIKit

#if DEBUG
@MainActor
enum PersonaSeedLoader {
    static func seedIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-personaRun") || args.contains("-sableUITestSeed") || args.contains("-resetSableProjects") else {
            return
        }

        if args.contains("-resetSableProjects") {
            resetProjects()
        }

        if args.contains("-sableUITestSeed") {
            seedContinueProject()
        }

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
            seedContinueProject()
        }
    }

    private static func resetProjects() {
        let service = StorageService()
        for project in service.loadAllProjects() {
            service.delete(project: project)
        }
    }

    private static func seedContinueProject() {
        guard let template = Template.loadAll().first(where: { $0.svgFilename == "sunflower_mandala.svg" })
                ?? Template.loadAll().first else {
            return
        }

        let service = StorageService()
        var project = service.openOrCreateProject(for: template)

        let stroke = makePencilStroke(
            from: CGPoint(x: 200, y: 200),
            to: CGPoint(x: 600, y: 600),
            color: .systemRed
        )
        let drawing = PKDrawing(strokes: [stroke])

        var paintState = ProjectPaintState()
        var fillLayer: UIImage?
        var lineArt: UIImage?

        if let svgURL = template.svgURL,
           case .success(let geometry) = SVGParser.parse(url: svgURL),
           let firstRegion = geometry.regions.first {
            paintState.regionFills[firstRegion.id] = MoodCategory.playful.accentHex
            service.savePaintState(paintState, for: project)
            fillLayer = TemplateRenderer.renderFillLayer(
                geometry: geometry,
                fills: paintState.regionFills,
                size: geometry.viewBox.size
            )
            lineArt = TemplateRenderer.renderLineArt(geometry: geometry, size: geometry.viewBox.size)
            project.updateCompletion(
                filledRegionCount: paintState.regionFills.count,
                totalRegionCount: geometry.regions.count
            )
        } else {
            project.updateCompletion(filledRegionCount: 1, totalRegionCount: 10)
        }

        service.save(project: &project, drawing: drawing, fillLayer: fillLayer, templateImage: lineArt)
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
