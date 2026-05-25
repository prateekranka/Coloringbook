# Gouache Goal Progress

## Current checkpoint
11. Polish and validation complete for the first product-quality SwiftUI pass.

## Files changed
- `docs/gouache-goal-progress.md`
- `ColorFlow/Models/AppTheme.swift`
- `ColorFlow/Models/GouacheDomainModels.swift`
- `ColorFlow/Models/ProjectPaintState.swift`
- `ColorFlow/Navigation/SableTab.swift`
- `ColorFlow/Theme/SableTheme.swift`
- `ColorFlow/ViewModels/ColoringSessionViewModel.swift`
- `ColorFlow/ViewModels/TemplateListViewModel.swift`
- `ColorFlow/Views/GouacheComponents.swift`
- `ColorFlow/Views/HomeView.swift`
- `ColorFlow/Views/NavigationShell.swift`
- `ColorFlow/Views/ProfileView.swift`
- `ColorFlow/Views/TemplateListView.swift`
- `ColorFlow/Views/ColoringCanvasView.swift`

## What was verified
- App entry point: `ColorFlow/App/ColorFlowApp.swift` launches `NavigationShell`.
- Main SwiftUI screens: `HomeView`, `TemplateListView`, `ProfileView`, `MyLibraryView`, `ColoringCanvasView`.
- Models/view models: `Template`, `Project`, `ColoringPage`, `PageCollection`, `MoodCategory`, `ColorPalette`, `CanvasViewport`; `HomeViewModel`, `TemplateListViewModel`, `MyLibraryViewModel`, `ColoringSessionViewModel`.
- Persistence: `StorageService` serializes project index, paint state, fill layers, drawings, and thumbnails.
- Resources: bundled SVG templates in `ColorFlow/Resources/Templates`, manifest in `templates.json`, palettes, Fraunces font, and hero artwork.
- Build/test entrypoint: `./dev`; project source of truth is `project.yml`.
- Deployment/device: iPad-only, iOS 18.0, `TARGETED_DEVICE_FAMILY = 2`.
- Implemented user-selectable System / Light / Dark theme support.
- Implemented Home / Library / Profile tabs, with My Work inside Profile.
- Implemented Home search, editorial hero line, mood cards, featured collections, and recently added.
- Implemented Library search, difficulty/mood filters, and adaptive visual wall.
- Implemented Profile display name editing, theme setting, gesture/input placeholder, saved palette placeholder, My Work filters, and reset confirmation copy.
- Implemented canvas UI hiding, visible undo/redo, Clean | Free defaulting to Clean, tool dock, color tray, structured strokes, mask-backed Clean clipping, and autosave hooks.
- `./dev gen` ran cleanly after adding new Swift files.
- XcodeBuildMCP simulator build succeeded on iPad (A16) with no warnings.
- Unit tests passed on iPad (A16): 91 passed, 0 failed.
- Simulator smoke pass verified Home, Library, Profile/My Work, and Canvas are reachable; template cards open Canvas; Canvas has no tab bar; Clean is selected by default; undo/redo, Hide UI, ToolDock, and ColorTray are visible.

## Remaining work
- Implement true Pencil-only stroke routing when the app adopts PencilKit input capture for this new canvas shell.
- Wire Profile duplicate/share/export actions to real services.
- Add real precomputed mask assets if the pipeline starts producing them; current Clean mode uses parsed SVG region geometry.

## Known compromises or limitations
- Theme support is now canonical: System / Light / Dark are user-selectable, and the canvas/template paper must remain warm cream in all themes.
- Existing worktree was dirty before this goal, including SwiftUI/model/resource changes; new work will avoid reverting unrelated edits.
- Canvas stroke rendering is a v1 bitmap commit foundation using structured stroke actions; Apple Pencil-specific input discrimination is not fully wired yet, so finger drawing can also produce strokes.
- Template masks use existing SVG parsed region geometry through `TemplateMask`; no separate precomputed mask assets were present.
- Profile duplicate/share buttons are surfaced as v1 affordances; export/share plumbing is still a follow-up.
- The first test run on iPad Pro (11-inch) (M4) hit repeated XCTest simulator bootstrap kills; after checking common fixes, validation moved to another valid iPad simulator, iPad (A16), where targeted failures and the full unit suite passed.
