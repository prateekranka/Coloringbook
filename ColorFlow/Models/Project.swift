import Foundation

struct Project: Identifiable, Codable {
    let id: UUID
    let templateId: UUID
    var templateName: String
    let createdAt: Date
    var modifiedAt: Date
    var drawingDataPath: String  // relative path in app Documents dir
    var fillLayerPath: String    // relative path in app Documents dir
    var thumbnailPath: String    // relative path in app Caches dir
    /// Fraction of regions filled (0.0–1.0). Optional for backward-compat with older saved data.
    var completionFraction: Double? = nil

    init(template: Template) {
        self.id = UUID()
        self.templateId = template.id
        self.templateName = template.name
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.drawingDataPath = "drawings/\(id.uuidString).pkdata"
        self.fillLayerPath = "fills/\(id.uuidString).png"
        self.thumbnailPath = "thumbnails/\(id.uuidString).png"
    }
}
