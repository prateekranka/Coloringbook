import Foundation

enum ProjectStatus: String, Codable {
    case notStarted
    case inProgress
    case completed
}

struct Project: Identifiable, Codable {
    let id: UUID
    let templateId: UUID
    var templateName: String
    let createdAt: Date
    var modifiedAt: Date
    var drawingDataPath: String  // relative path in app Documents dir
    var fillLayerPath: String    // relative path in app Documents dir
    var thumbnailPath: String    // relative path in app Caches dir
    var status: ProjectStatus
    var completionPercentage: Double

    init(template: Template) {
        self.id = UUID()
        self.templateId = template.id
        self.templateName = template.name
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.drawingDataPath = "drawings/\(id.uuidString).pkdata"
        self.fillLayerPath = "fills/\(id.uuidString).png"
        self.thumbnailPath = "thumbnails/\(id.uuidString).png"
        self.status = .inProgress
        self.completionPercentage = 0
    }

    mutating func updateCompletion(filledRegionCount: Int, totalRegionCount: Int) {
        guard totalRegionCount > 0 else {
            completionPercentage = 0
            status = .notStarted
            return
        }

        let progress = min(max(Double(filledRegionCount) / Double(totalRegionCount), 0), 1)
        completionPercentage = progress

        if progress >= 1 {
            status = .completed
        } else if progress > 0 {
            status = .inProgress
        } else {
            status = .notStarted
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case templateId
        case templateName
        case createdAt
        case modifiedAt
        case drawingDataPath
        case fillLayerPath
        case thumbnailPath
        case status
        case completionPercentage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        templateId = try container.decode(UUID.self, forKey: .templateId)
        templateName = try container.decode(String.self, forKey: .templateName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        drawingDataPath = try container.decode(String.self, forKey: .drawingDataPath)
        fillLayerPath = try container.decode(String.self, forKey: .fillLayerPath)
        thumbnailPath = try container.decode(String.self, forKey: .thumbnailPath)
        status = try container.decodeIfPresent(ProjectStatus.self, forKey: .status) ?? .inProgress

        let decodedProgress = try container.decodeIfPresent(Double.self, forKey: .completionPercentage) ?? 0
        completionPercentage = min(max(decodedProgress, 0), 1)
    }
}
