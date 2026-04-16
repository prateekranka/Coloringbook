# ColorFlow — iPad Coloring Book App

A premium, distraction-free coloring book app for iPad with Apple Pencil support.

## Features
- Tap-to-fill flood fill (enclosed regions, respects SVG line art boundaries)
- Apple Pencil with pressure-sensitive pencil, marker, and watercolor tools
- Stay-in-the-lines mode — strokes are clipped to the region where they start
- Smart default tool — Fill is selected after onboarding; last-used tool is remembered
- First-use guidance — "Tap a region to fill" hint with haptic feedback on canvas entry
- Rock-solid canvas — no pan-bounce or jitter at fitted zoom
- 8 curated color palettes + custom HSB/hex color picker
- 25+ royalty-free SVG templates across 5 categories
- Auto-save, gallery, and PNG/JPEG export
- Ambient sounds (rain, lo-fi, nature)
- Layer panel (background, color, line art)

## Setup

### Using XcodeGen (recommended)

```sh
brew install xcodegen        # one-time
xcodegen generate            # generates ColorFlow.xcodeproj from project.yml
open ColorFlow.xcodeproj
```

### Using FlowDeck CLI

```sh
flowdeck run -S "iPad Air 11-inch (M4)"   # build + launch on simulator
flowdeck test -S "iPad Air 11-inch (M4)"  # run all tests
```

### Manual Xcode setup

1. Run `xcodegen generate` to create the `.xcodeproj`
2. Open `ColorFlow.xcodeproj` in Xcode
3. Select an iPad simulator (iPad Air 11-inch M4 recommended)
4. Build & run (Cmd+R)

## Adding SVG Templates

1. Source royalty-free SVGs from [Wikimedia Commons](https://commons.wikimedia.org), [OpenClipArt](https://openclipart.org), or [FreeSVG.org](https://freesvg.org)
2. Clean up in Inkscape: flatten transforms, ensure closed paths, remove metadata
3. Place in `Resources/Templates/<category>/`
4. Add entry to `Resources/templates.json`

## Architecture

```
MVVM + SwiftUI + PencilKit + Core Graphics

CanvasView
  └── CanvasViewModel
        ├── FloodFillEngine (background thread, scanline algorithm)
        ├── StorageService (JSON project index + file system)
        └── ExportService (UIGraphicsImageRenderer composite)

GalleryView  ← GalleryViewModel ← StorageService
TemplateLibraryView ← TemplateLibraryViewModel
```

## Testing

```sh
# All tests
flowdeck test -S "iPad Air 11-inch (M4)"

# Canvas smoke test (FlowDeck UI automation)
bash Scripts/qa/canvas_smoke.sh

# Manual QA checklist
# See docs/contributors/canvas-qa.md for a 13-step smoke test
```

## Phase Status

- [x] Phase 1: Project setup, PencilKit canvas, SVG template loading
- [x] Phase 2: Flood fill engine, color picker, tool switching
- [x] Phase 3: Template library, categories, browsing UI
- [x] Phase 4: Save/load system, gallery, export
- [x] Phase 5: Polish — layers, ambient sounds, haptics, onboarding
- [x] Phase 5.5: Canvas UX — default tool, pan-bounce fix, stay-in-the-lines, first-use hints
- [ ] Phase 6: App Store prep — icon, screenshots, TestFlight
