import SwiftUI
import PencilKit
import Combine

@MainActor
class CanvasViewModel: ObservableObject {
    // MARK: - Published State

    @Published var drawing = PKDrawing()
    @Published var brushSettings = BrushSettings()
    @Published var backgroundColor: Color = .white
    @Published var templateImage: UIImage?
    @Published var fillLayerImage: UIImage?
    @Published var recentColors: [Color] = []
    @Published var palettes: [ColorPalette] = []
    @Published var isFilling = false
    @Published var showLineArt = true
    @Published var showColorLayer = true

    // MARK: - Layer visibility

    var effectiveTemplateImage: UIImage? { showLineArt ? templateImage : nil }

    // MARK: - Internal

    private(set) var project: Project
    private(set) var template: Template
    weak var pencilCanvas: PKCanvasView?
    private var autoSaveTask: Task<Void, Never>?
    private let storageService = StorageService()

    // Flood fill operates on this off-screen bitmap
    private var fillBitmap: FillBitmap?

    // MARK: - Init

    init(project: Project, template: Template) {
        self.project = project
        self.template = template
        self.palettes = ColorPalette.loadAll()
        loadRecentColors()
    }

    // MARK: - Current PK Tool

    var currentPKTool: PKTool {
        brushSettings.tool.pkTool(
            color: UIColor(brushSettings.color).withAlphaComponent(brushSettings.opacity),
            width: brushSettings.size
        )
    }

    // MARK: - Template Loading (SVG via SVGKit)

    func loadTemplate() async {
        guard let svgURL = template.svgURL else { return }

        let image = await Task.detached(priority: .userInitiated) {
            // SVGKit rendering — runs off main thread
            // Replace with: SVGKImage(contentsOf: svgURL)?.uiImage
            // Requires SVGKit SPM dependency. Stub for compilation:
            return UIImage() // TODO: replace with SVGKImage rendering
        }.value

        self.templateImage = image
        setupFillBitmap(size: CGSize(width: 2732, height: 2048))

        // Load saved drawing and fill layer if project exists
        if let savedDrawing = storageService.loadDrawing(for: project) {
            self.drawing = savedDrawing
        }
        if let savedFill = storageService.loadFillLayer(for: project) {
            self.fillLayerImage = savedFill
            fillBitmap = FillBitmap(image: savedFill)
        }
    }

    private func setupFillBitmap(size: CGSize) {
        fillBitmap = FillBitmap(size: size)
    }

    // MARK: - Flood Fill

    func performFloodFill(at point: CGPoint, in viewSize: CGSize) async {
        guard var bitmap = fillBitmap else { return }
        isFilling = true

        let fillColor = UIColor(brushSettings.color)
        let templateBitmap = templateImage.map { FillBitmap(image: $0) }

        let updatedBitmap = await Task.detached(priority: .userInitiated) {
            // Convert view-space point to bitmap-space
            let scaleX = bitmap.width / Int(viewSize.width)
            let scaleY = bitmap.height / Int(viewSize.height)
            let bitmapPoint = CGPoint(x: point.x * CGFloat(scaleX), y: point.y * CGFloat(scaleY))

            FloodFillEngine.fill(
                bitmap: &bitmap,
                at: bitmapPoint,
                with: fillColor,
                boundaryBitmap: templateBitmap,
                tolerance: 40
            )
            return bitmap
        }.value

        fillBitmap = updatedBitmap
        fillLayerImage = updatedBitmap.toUIImage()
        isFilling = false
        scheduleAutoSave()
        addRecentColor(brushSettings.color)
    }

    // MARK: - Eyedropper

    func pickColor(at point: CGPoint, in viewSize: CGSize) {
        guard let bitmap = fillBitmap else { return }
        let scaleX = CGFloat(bitmap.width) / viewSize.width
        let scaleY = CGFloat(bitmap.height) / viewSize.height
        let bx = Int(point.x * scaleX)
        let by = Int(point.y * scaleY)

        if let sampledColor = bitmap.color(at: CGPoint(x: bx, y: by)) {
            brushSettings.color = Color(sampledColor)
            brushSettings.tool = .floodFill  // switch back to fill after picking
            addRecentColor(brushSettings.color)
        }
    }

    // MARK: - Undo / Redo

    func undo() { pencilCanvas?.undoManager?.undo() }
    func redo() { pencilCanvas?.undoManager?.redo() }

    // MARK: - Auto-save

    func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func save() {
        storageService.save(project: &project, drawing: drawing, fillLayer: fillLayerImage)
    }

    // MARK: - Recent Colors

    @AppStorage("recentColors") private var recentColorsRaw: String = "[]"

    private func loadRecentColors() {
        guard let data = recentColorsRaw.data(using: .utf8),
              let hexArray = try? JSONDecoder().decode([String].self, from: data) else { return }
        recentColors = hexArray.map { Color(hex: $0) }
    }

    func addRecentColor(_ color: Color) {
        var updated = recentColors.filter { $0 != color }
        updated.insert(color, at: 0)
        recentColors = Array(updated.prefix(12))

        let hexArray = recentColors.map { UIColor($0).hexString }
        if let data = try? JSONEncoder().encode(hexArray),
           let str = String(data: data, encoding: .utf8) {
            recentColorsRaw = str
        }
    }
}
