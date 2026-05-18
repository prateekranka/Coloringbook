# CLAUDE.md

Fast orientation for Claude Code / Codex in this repo. `AGENTS.md` is the
workflow manual; this file is the current architecture map for the committed
codebase.

## Snapshot

- Product: native SwiftUI iPad coloring studio. The internal project/module is
  still `ColorFlow`, the bundle display name is `Gouache`, and newer UI code
  uses `Sable` names. Do not do broad brand renames unless asked.
- Platform: iOS/iPadOS 18.0, Swift 5.9, iPad only
  (`TARGETED_DEVICE_FAMILY: "2"`). Mac Catalyst and iPhone are out of scope.
- Build source of truth: `project.yml` via XcodeGen. `ColorFlow.xcodeproj` is
  generated. Do not hand-edit it.
- App entry: `ColorFlow/App/ColorFlowApp.swift` -> `NavigationShell`.
- Main shell: `NavigationStack` plus custom bottom tabs from `SableTab`
  (`home`, `library`, `profile`). Route pushes use `AppRoute`.
- State pattern: SwiftUI Observation. View models/stores are
  `@MainActor @Observable`; views own them with `@State` and inject stores with
  `.environment(...)`. Avoid `ObservableObject`, `@Published`, `@StateObject`,
  and `@EnvironmentObject`.
- Theme: `SableTheme` owns colors, fonts, spacing, and radii. `AppThemeStore`
  persists System / Light / Dark. Canvas paper stays warm cream.

## Commands

Use `./dev` instead of raw `xcodebuild`:

```sh
./dev gen       # regenerate ColorFlow.xcodeproj from project.yml
./dev build     # simulator build
./dev test      # unit tests only; this is the default ./dev action
./dev uitest    # UI tests only
./dev all       # unit + UI tests
./dev simlist   # available iPad simulators
./dev open      # open generated Xcode project
```

Simulator selection is automatic. Override with `COLORFLOW_SIM="iPad (A16)"`
or `COLORFLOW_SIM_UDID=...` when needed; do not commit hardcoded UDIDs.

If `project.yml` changes, run `./dev gen`. Current signing settings in
`project.yml` are `PRODUCT_BUNDLE_IDENTIFIER: com.duckuwucky.sable` and
`DEVELOPMENT_TEAM: 4JRB53LG5C`; override locally, not in commits.

## Directory Map

- `ColorFlow/App`: SwiftUI app entry and debug persona seeding.
- `ColorFlow/Navigation`: `AppRoute`, `CanvasRoute`, `SableTab`.
- `ColorFlow/Views`: Home, Library, Profile, Canvas, and shared components.
- `ColorFlow/ViewModels`: `HomeViewModel`, `TemplateListViewModel`,
  `MyLibraryViewModel`, `ColoringSessionViewModel`.
- `ColorFlow/Repositories`: repository protocols and `SableHomeRepository`.
- `ColorFlow/Models`: templates, projects, canvas state, tools, palettes.
- `ColorFlow/Services`: persistence, rendering, export, SVG parsing, pigment
  engine, haptics, photo pipeline facade.
- `ColorFlow/Services/PhotoPipeline`: on-device photo-to-template pieces.
- `ColorFlow/Resources`: manifest JSON, palettes, Fraunces font, artwork,
  template SVGs, and pre-rendered line-art PNGs.
- `ColorFlowTests` / `ColorFlowUITests`: XCTest, XCUITest, persona flows.
- `Scripts/pipeline`: host-side template catalog pipeline.

## Data Flow

`SableHomeRepository` is the shared app data facade. It loads bundled templates
through `Template.loadAll()` and projects through `StorageService`, then feeds:

- `HomeViewModel`: continue pages, recently added pages, collections, moods.
- `TemplateListViewModel`: explore, collections, recently added, collection,
  mood, and search sources. `routeForTemplate` opens or creates a project.
- `ProfileView` / `MyLibraryViewModel`: saved work from local projects.
- `ColoringSessionViewModel`: resolves `(project, template)` before canvas
  load.

## Canvas

`ColoringCanvasView` owns `ColoringSessionViewModel` unless a test injects one.
On load the view model resolves the project/template, parses the SVG on a
detached task, loads `ProjectPaintState`, existing pigment PNG, optional
`PKDrawing`, and renders line art.

The rendering stack is:

1. `SVGParser` -> `TemplateGeometry` (`viewBox`, fillable `RegionGeometry`,
   decorative paths).
2. `TemplateRenderer` renders line art, fill layers, thumbnails, and exports.
3. `RegionPigmentEngine` owns a `PigmentBitmap` plus `RegionMaskCache` for
   clean clipped strokes and region fills.
4. `BrushRenderers` replays structured `StrokeAction`s for legacy/committed
   stroke state.
5. `NotebookCanvasRepresentable` draws pigment, line art, and saved drawing.
6. `FreehandCanvasRepresentable` wraps `PKCanvasView` in Free mode.

Modes:

- Clean mode clips drawing to the first touched SVG region and shows line art
  through the notebook renderer.
- Free mode overlays `PKCanvasView` and line art, with optional finger painting.
- Fill Bucket hit-tests vector geometry with `TemplateGeometry.region(at:)`.
- `CanvasViewport` stores 1x-4x zoom and pan offset; values persist in
  `ProjectPaintState.canvasState`.

Undo/redo is image-patch based (`CanvasEditAction`) for fills, pigment strokes,
eraser strokes, and clears. Autosave runs after dirty edits, and the canvas
saves on disappear/background.

## Persistence

Use `StorageService`; do not bypass it. It serializes all file I/O and index
mutation through a private queue.

Documents layout:

- `projects.json`: project index.
- `drawings/<project-id>.pkdata`: PencilKit data.
- `fills/<project-id>.png`: canonical pigment layer.
- `fills/<project-id>.json`: `ProjectPaintState`.
- `thumbnails/<project-id>.png`: project thumbnail.
- `user_templates.json` and `UserTemplates/<id>/`: user-generated templates.

`Project` stores relative paths plus template ID, status, and completion.
`ProjectPaintState` version 2 stores region fills, structured strokes, optional
freehand data, pigment filename, selected tool/mode, and viewport. After saves,
invalidate `ProjectThumbnailCache`.

## Templates

Bundled catalog is currently 10 templates. `Template.loadAll()` prefers
`ColorFlow/Resources/templates.json`, validates the expected slug set, and
falls back to `Template.bundledTemplates`.

Template resources:

- SVGs live in `ColorFlow/Resources/Templates/*.svg`.
- Pre-rendered line art PNGs live in `ColorFlow/Resources/TemplateLineArt`.
- `project.yml` excludes `Resources/**` from sources and adds resources
  explicitly. Its pre-build script copies SVGs to the bundle root and copies
  `TemplateLineArt`, `templates.json`, palettes, Fraunces, and hero artwork.
- `Template.svgURL` checks user-template Documents first, then bundle
  `Templates/`, then flat bundle root.

When changing templates, run the pipeline or validator and keep
`templates.json`, `Template.expectedCatalogSlugs`, and `Template.bundledTemplates`
in sync. Never change existing template UUIDs; saved projects reference them.

SVG parser contract: root `viewBox` required; fillable paths need IDs and closed
contours; rejected elements include filters, masks, clip paths, images, styles,
gradients, and `<use>`; rejected attributes include `stroke-dasharray` and
`opacity`; arc commands `A/a` fail; only group `translate(...)` transforms are
supported. `SVGParser.swift` is the source of truth, with
`docs/svg-template-spec.md` and `Scripts/validate_template_svg.py` as helpers.

## Photo Pipeline

Photo-to-template code exists but is not the primary visible UI surface. The
pipeline is on-device only: pre-validation, preprocessing, XDoG/neural edges,
k-means segmentation, morphology cleanup, contour vectorization, SVG assembly,
parser parity validation, and `UserTemplate` persistence. Do not add networking,
analytics, remote processing, or SDK data collection without explicit approval.

## Tests

Important test coverage:

- Canvas behavior: `ColoringFlowTests`, `Canvas/RegionPigmentEngineTests`,
  `Canvas/CanvasStayInTheLinesTests`, `CanvasViewportTests`.
- Template safety: `SVGCatalogParityTests`, `Scripts/validate_template_svg.py`.
- Photo pipeline: `PhotoPipeline/*Tests`, `PhotoPreValidatorTests`.
- App metadata/privacy: `InfoPlistValidationTests`, `PrivacyManifestTests`,
  `LoggingGatingTests`.
- UI/personas: `AccessibilityUITests`, `ScreenshotUITests`,
  `ColorFlowUITests/Personas`.

Debug builds run `PersonaSeedLoader.seedIfNeeded()` so UI/persona tests have
local sample projects.

## Gotchas

- Older docs and `README.md` are stale in places. Prefer `AGENTS.md`,
  `project.yml`, and current source.
- `Package.swift.bak` is not the app build. Do not add package dependencies or
  link SVGKit without discussion; `OTHER_LDFLAGS` is intentionally empty.
- Keep resources wired through `project.yml`; assets/resources are not source
  files.
- Keep accessibility identifiers stable unless tests are updated.
- Use `UserDefaults.standard` directly inside `@Observable` classes; do not use
  `@AppStorage` there.
- Preserve local privacy posture: no accounts, no telemetry, no normal-use
  network dependency.
