import Foundation

struct CanvasRoute: Hashable {
    let projectId: UUID
    let templateId: UUID
    let title: String
}

enum AppRoute: Hashable {
    case coloringPage(ColoringPage)
    case collection(PageCollection)
    case mood(MoodCategory)
    case canvas(CanvasRoute)

    var title: String {
        switch self {
        case .coloringPage(let page):
            return page.title
        case .collection(let collection):
            return collection.name
        case .mood(let mood):
            return mood.title
        case .canvas(let route):
            return route.title
        }
    }

    var subtitle: String {
        switch self {
        case .coloringPage(let page):
            return "\(Int((page.progress * 100).rounded()))% complete"
        case .collection(let collection):
            return collection.pageCountLabel
        case .mood:
            return "Mood collection"
        case .canvas:
            return "Coloring canvas"
        }
    }
}
