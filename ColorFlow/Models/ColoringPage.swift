import SwiftUI

struct ColoringPage: Identifiable, Hashable {
    let id: UUID
    let projectId: UUID?
    let templateId: UUID?
    let title: String
    let progress: Double
    let thumbnailColor: Color
    let thumbnailColorHex: String
    let thumbnailPath: String?
    let fillLayerPath: String?

    init(
        id: UUID = UUID(),
        projectId: UUID? = nil,
        templateId: UUID? = nil,
        title: String,
        progress: Double,
        thumbnailColorHex: String,
        thumbnailPath: String? = nil,
        fillLayerPath: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.templateId = templateId
        self.title = title
        self.progress = min(max(progress, 0), 1)
        self.thumbnailColor = Color(hex: thumbnailColorHex)
        self.thumbnailColorHex = thumbnailColorHex
        self.thumbnailPath = thumbnailPath
        self.fillLayerPath = fillLayerPath
    }

    static func == (lhs: ColoringPage, rhs: ColoringPage) -> Bool {
        lhs.id == rhs.id
            && lhs.projectId == rhs.projectId
            && lhs.templateId == rhs.templateId
            && lhs.title == rhs.title
            && lhs.progress == rhs.progress
            && lhs.thumbnailColorHex == rhs.thumbnailColorHex
            && lhs.thumbnailPath == rhs.thumbnailPath
            && lhs.fillLayerPath == rhs.fillLayerPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(projectId)
        hasher.combine(templateId)
        hasher.combine(title)
        hasher.combine(progress)
        hasher.combine(thumbnailColorHex)
        hasher.combine(thumbnailPath)
        hasher.combine(fillLayerPath)
    }
}
