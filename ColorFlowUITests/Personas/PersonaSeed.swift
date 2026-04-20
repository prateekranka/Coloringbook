import Foundation

enum PersonaSeed: String, CaseIterable {
    case dailyDoodler = "daily-doodler"
    case deepColorist = "deep-colorist"
    case tabSwitcher = "tab-switcher"

    static func from(arguments: [String]) -> PersonaSeed? {
        for arg in arguments {
            if arg.hasPrefix("-personaSeed=") {
                let raw = String(arg.dropFirst("-personaSeed=".count))
                return PersonaSeed(rawValue: raw)
            }
        }
        return nil
    }
}