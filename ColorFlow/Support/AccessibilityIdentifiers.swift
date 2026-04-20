import Foundation

public enum A11y {
    public enum Canvas {
        public static let back = "canvas.back"
        public static let toolbarToggle = "canvas.toolbar.toggle"
        public static let toolbarRestore = "canvas.toolbar.restore"
        public static let undo = "canvas.undo"
        public static let redo = "canvas.redo"
        public static let layers = "canvas.layers"
        public static let settings = "canvas.settings"
        public static let colorWell = "canvas.colorWell"
        public static let opacity = "canvas.opacity"
        public static let root = "canvas.root"
        public static func tool(_ name: String) -> String { "canvas.tool.\(name.lowercased())" }
        public static let pencil = "canvas.tool.pencil"
        public static let marker = "canvas.tool.marker"
        public static let watercolor = "canvas.tool.watercolor"
        public static let eraser = "canvas.tool.eraser"
        public static let floodFill = "canvas.tool.fill"
        public static let eyedropper = "canvas.tool.eyedropper"
        public static let export = "canvas.export"
    }

    public enum Picker {
        public static let floating = "picker.floating"
        public static let close = "picker.close"
        public static let modePalette = "picker.mode.palette"
        public static let paletteDefault = "picker.palette.default"
        public static func palette(name: String) -> String { "picker.palette.\(name.lowercased().replacingOccurrences(of: " ", with: "_"))" }
        public static func recent(index: Int) -> String { "picker.recent.\(index)" }
    }

    public enum Home {
        public static let plus = "home.plus"
        public static let browseTemplates = "home.browseTemplates"
        public static let createFromPhoto = "home.createFromPhoto"
        public static func recent(projectID: UUID) -> String { "home.recent.\(projectID.uuidString)" }
        public static func suggested(templateID: UUID) -> String { "home.suggested.\(templateID.uuidString)" }
    }

    public enum Library {
        public static let createFromPhoto = "library.createFromPhoto"
        public static func category(_ label: String) -> String { "library.category.\(label)" }
        public static func template(_ id: UUID) -> String { "library.template.\(id.uuidString)" }
        public static func userTemplate(_ id: UUID) -> String { "library.userTemplate.\(id.uuidString)" }
    }

    public enum MyWork {
        public static let share = "mywork.share"
        public static let filter = "mywork.filter"
        public static func artwork(projectID: UUID) -> String { "mywork.artwork.\(projectID.uuidString)" }
    }

    public enum Layers {
        public static let backgroundPicker = "layers.background.picker"
        public static let backgroundRow = "layers.background.row"
        public static let done = "layers.done"
        public static func toggle(name: String) -> String { "layers.toggle.\(name.lowercased().replacingOccurrences(of: " ", with: "_"))" }
    }

    public enum Onboarding {
        public static let skip = "onboarding.skip"
        public static let cta = "onboarding.cta"
    }

    public enum Splash {
        public static let view = "splash.view"
    }

    public enum PhotoImport {
        public static let photoLibrary = "photoImport.photoLibrary"
        public static let camera = "photoImport.camera"
        public static let createTemplate = "photoImport.createTemplate"
        public static let close = "photoImport.close"
        public static let cancel = "photoImport.cancel"
        public static func preset(_ rawValue: String) -> String { "photoImport.preset.\(rawValue)" }
    }

    public enum Brush {
        public static let scrubber = "brush.scrubber"
    }
}
