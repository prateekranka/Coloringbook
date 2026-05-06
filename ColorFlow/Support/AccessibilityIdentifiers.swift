import Foundation

public enum A11y {
    public enum Tab {
        public static let home = "tab.home"
        public static let explore = "tab.explore"
        public static let library = "tab.library"
    }

    public enum Home {
        public static func continuePage(_ slug: String) -> String { "home.continue.\(slug)" }
        public static func collection(_ slug: String) -> String { "home.collection.\(slug)" }
        public static func mood(_ rawValue: String) -> String { "home.mood.\(rawValue)" }
    }

    public enum TemplateList {
        public static func template(_ slug: String) -> String { "template.\(slug)" }
    }

    public enum Canvas {
        public static let surface = "canvas.surface"
        public static let save = "canvas.save"
        public static let progress = "canvas.progress"
    }
}

extension String {
    var normalizedIdentifier: String {
        lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
