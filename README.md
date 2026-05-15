# Gouache — iPad Coloring Book App

A premium, distraction-free coloring book app for iPad with Apple Pencil support.

## Features
- Tap-to-fill flood fill (enclosed regions, respects SVG line art boundaries)
- Apple Pencil with pressure-sensitive pencil, marker, and watercolor tools
- 8 curated color palettes + custom HSB/hex color picker
- 25+ royalty-free SVG templates across 5 categories
- Auto-save, gallery, and PNG/JPEG export
- Ambient sounds (rain, lo-fi, nature)
- Layer panel (background, color, line art)

## Setup (Xcode)

1. Open Xcode → File → New → Project → **App** (iOS, SwiftUI, iPad only)
2. Copy the `ColorFlow/` folder into your project root
3. Add SVGKit via **File → Add Package Dependencies**:
   ```
   https://github.com/SVGKit/SVGKit
   ```
4. Add all files in `ColorFlow/` to the Xcode target
5. Add `Resources/` folder to the target with **Copy Bundle Resources** build phase
6. Set deployment target to **iPadOS 17.0**
7. Set supported device to **iPad** only
8. Build & run on a connected iPad

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

## Phase Status

- [x] Phase 1: Project setup, PencilKit canvas, SVG template loading
- [x] Phase 2: Flood fill engine, color picker, tool switching
- [x] Phase 3: Template library, categories, browsing UI
- [x] Phase 4: Save/load system, gallery, export
- [x] Phase 5: Polish — layers, ambient sounds, haptics, onboarding
- [ ] Phase 6: App Store prep — icon, screenshots, TestFlight
 icon, screenshots, TestFlight
