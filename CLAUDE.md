# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ColorFlow is an iPad-only SwiftUI coloring book app (iPadOS 17+, Swift 5.9). Apple Pencil + PencilKit for strokes, CoreGraphics flood fill for tap-to-fill, SVG templates as line art. App is dark-themed, three-tab (Home / Library / My Work), with a single full-screen `CanvasView` presented via `galleryViewModel.openedProject`.

Authoritative build target is `ColorFlow.xcodeproj` (generated from `project.yml` via XcodeGen). `Package.swift` exists only for reference/local SwiftPM experimentation — do not rely on it for the app build.

## Build, run, test

The Xcode project is generated, not committed source-of-truth. Regenerate after editing `project.yml`:

```sh
xcodegen generate        # run from repo root
open ColorFlow.xcodeproj
```

**FlowDeck CLI** (preferred for development):

```sh
flowdeck run -S "iPad Air 11-inch (M4)"   # build + launch on simulator
flowdeck test -S "iPad Air 11-inch (M4)"  # run all tests
flowdeck clean                              # clean build artifacts
```

Legacy xcodebuild (still works):

```sh
bash run_tests.sh        # clean + build + unit tests + UI tests on a specific simulator UDID
```

The hardcoded simulator UDID in `run_tests.sh` (`8C2621A4-…`) will differ per machine — update it or pass your own `-destination` when invoking `xcodebuild` directly.

Run a single unit test:

```sh
xcodebuild test \
  -project ColorFlow.xcodeproj -scheme ColorFlow \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -only-testing:ColorFlowTests/CanvasDefaultToolTests/test_freshInstall_postOnboarding_defaultsToFloodFill
```

Canvas smoke test (FlowDeck UI automation):

```sh
bash Scripts/qa/canvas_smoke.sh            # drives first-tap-fills-region golden path
```

There is no lint tooling wired up.

## Architecture

MVVM. Views observe `@MainActor` view models; services are plain classes owned by view models.

**Canvas pipeline (`CanvasView` → `CanvasViewModel`)** is where most of the complexity lives:
- `SVGParser` parses the template SVG into a `TemplateGeometry` (viewBox + `[RegionGeometry]` with `CGPath`s + decorative paths). The parser is strict: only `translate(x,y)` transforms, no arc commands (`A/a`) — convert arcs to cubic beziers upstream in Inkscape.
- Tap-to-fill uses `TemplateGeometry.region(at:)` for vector hit-testing (bounds pre-check then `CGPath.contains`), not the pixel `FloodFill` bitmap. `FloodFill.swift` / `FillBitmap` exists for raster flood fill fallback and compositing.
- `TemplateRenderer` rasterises the line art and fills into `UIImage`s. Two published images drive the canvas: `templateImage` (line art, gated by `showLineArt`) and `fillLayerImage` (painted regions, gated by `showColorLayer`).
- `PencilCanvasRepresentable` wraps `PKCanvasView` inside a `UIScrollView`. The Coordinator is both `UIScrollViewDelegate` and `PKCanvasViewDelegate`. Key behaviors:
  - `scrollView.bounces = false` — no pan-bounce at fitted zoom.
  - `updatePanGate()` disables `isScrollEnabled` when `zoomScale <= fitScale + epsilon` — finger pans are gated on zoom state.
  - `lastAppliedContentSize` guard prevents `setZoomScale` re-application during toolbar animation frames (bounds-flutter fix).
  - Stay-in-the-lines clipping in `canvasViewDrawingDidChange`: clips new strokes to the region containing the first point. Eraser is exempt. Uses `isRevertingDrawing` flag to prevent delegate re-entry.
  - `#if DEBUG` block enables `-enableFingerDrawing` launch arg for FlowDeck automation (sets `drawingPolicy = .anyInput`).
- PencilKit strokes are stored in `@Published var drawing: PKDrawing` separately from the fill layer.
- `ProjectPaintState` is the mutable per-region fill map; fill undo/redo lives in `FillAction` stacks on the view model (separate from PencilKit's own undo manager).

**Canvas UX features** (added in canvas-ux branch):
- **Default tool resolution**: `CanvasViewModel.resolveInitialTool()` reads `UserDefaults("lastUsedTool")` → stored tool; absent + post-onboarding → `.floodFill`; pre-onboarding → `.pencil`. `ToolbarView` writes back on every tool switch.
- **First-use fill hint**: Non-blocking "Tap a region to fill" capsule overlay gated on `hasCompletedFirstFill` UserDefault. Dismisses after first successful fill. Canvas entry fires `.light` haptic once per appearance (respects reduce-motion).
- **Stay-in-the-lines mode**: Commit-time stroke clipping via `clipStroke(_:toRegion:)`. Toggled in canvas settings sheet ("..." button in toolbar). Eraser exempt. Strokes starting outside all regions commit unclipped. Setting persists via `UserDefaults("stayInTheLines")`.

**Persistence (`StorageService`)**: `projects.json` index in `Documents/`, plus per-project subdirectories containing PKDrawing `.data`, fill-layer PNG, and thumbnail. `GalleryViewModel` owns the project list and the `openedProject` binding that triggers `CanvasView` presentation from `MainTabView`.

**Templates**: SVG files live in `ColorFlow/Resources/Templates/*.svg` and are copied to the bundle **root** (flat) by a `preBuildScript` in `project.yml` — not as a folder reference. `Template.svgURL` tries `Templates/` subdirectory first, then flat bundle root, then a manual fallback. `Template.loadAll()` prefers `templates.json` from the bundle but falls back to a hardcoded `bundledTemplates` array so the app always has content — keep these two in sync when adding templates.

**Theming**: all colors/metrics come from `AppTheme` (dark background `#1C1C1E`, accent purple `#7B5FE8`). Tab bar and nav bar are configured via `UITabBarAppearance` / `UINavigationBarAppearance` in `ColorFlowApp.init` — SwiftUI `.tint` alone isn't sufficient on iPad because iOS 18 defaults to a sidebar/top tab style.

## Test structure

Canvas tests live under `ColorFlowTests/Canvas/` with shared helpers in `Canvas/Support/`:

| Test class | What it covers |
|---|---|
| `CanvasViewModelFillTests` | Fill pipeline — region hit, color change, miss, undo/redo, image identity |
| `CanvasDefaultToolTests` | Post-onboarding tool resolution (`lastUsedTool`, fresh install, corrupted) |
| `CanvasScrollViewConfigurationTests` | Pan-gate at fitted zoom, zoom-unlock, bounds-flutter debounce |
| `CanvasFirstFillHintTests` | `hasCompletedFirstFill` flag lifecycle |
| `CanvasBrushRenderTests` | Headless render+sample for pencil, marker, watercolor, eraser, color/size changes |
| `CanvasStayInTheLinesTests` | Stroke clipping — fully inside, crossing, outside, eraser exempt, persistence |
| `FlowDeckCanvasSmokeTests` | Verifies `Scripts/qa/canvas_smoke.sh` exists and is executable |

**Test helpers** (`Canvas/Support/`):
- `CanvasTestFixture` — `makeLoadedViewModel()`, `interiorPoint(of:)`, `pointOutsideAllRegions`
- `PKStrokeFactory` — synthetic stroke/drawing builders for deterministic PencilKit tests
- `PixelSampler` — `meanColor(of:in:)`, `redPixelCount`, `nonWhitePixelCount` for render assertions

## Things that will bite you

- **SVGKit is declared as a dependency but currently stubbed out** (`OTHER_LDFLAGS: ""`). Rendering goes through the in-house `SVGParser` + `TemplateRenderer`. Do not assume SVGKit is linked.
- `TARGETED_DEVICE_FAMILY: "2"` (iPad only). Do not add iPhone layouts or `.navigationViewStyle` variants without updating `project.yml`.
- `preferredColorScheme(.dark)` is forced at the root; views should not branch on `colorScheme`.
- `project.yml` uses `createIntermediateGroups: true` and excludes `Assets.xcassets/**` / `Resources/**` from sources — they're added via the `resources:` block. Adding a new asset folder means editing `project.yml` and re-running `xcodegen`.
- Bundle ID `com.prateekranka.colorflow` and signing team `Y4QMMY38ZN` are baked into `project.yml` — override locally, don't commit changes to these.
- SVGs must have a `viewBox` attribute, closed paths, and no unsupported elements/transforms, or `SVGParser` will fail loudly via `SVGParseError`.
- **UserDefaults keys used by canvas**: `lastUsedTool`, `hasSeenOnboarding`, `hasCompletedFirstFill`, `stayInTheLines`. Tests clean these up in `setUp`/`tearDown` — if you add a new key, add cleanup to relevant test fixtures.
- **`isRevertingDrawing` flag** in `PencilCanvasRepresentable.Coordinator` prevents delegate re-entry when programmatically replacing `canvasView.drawing` (e.g., stay-in-the-lines clipping). Always set it around programmatic drawing mutations.
- **`-enableFingerDrawing` launch arg** is `#if DEBUG` only. It switches `drawingPolicy` to `.anyInput` for FlowDeck UI automation on non-Pencil simulators. Compiled out in Release.
