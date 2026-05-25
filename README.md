# Gouache — iPad Coloring Book App

A premium, distraction-free coloring book app for iPad with Apple Pencil support.

## Features
- Tap-to-fill flood fill (enclosed regions, respects SVG line art boundaries)
- Apple Pencil with pressure-sensitive pencil, marker, and watercolor tools
- 8 curated color palettes + custom HSB/hex color picker
- 17 original SVG templates across 6 categories
- Auto-save, gallery, and PNG/JPEG export
- Layer panel (background, color, line art)

## Setup

Use the repo entrypoint so simulator selection, build settings, and generated
project files stay consistent:

```sh
./dev gen
./dev build
./dev test
```

## Adding SVG Templates

Run the template pipeline described in `Scripts/pipeline/README.md`.
Passing SVGs live flat in `ColorFlow/Resources/Templates/`, and
`ColorFlow/Resources/templates.json` is the manifest.

## Privacy

Gouache does not collect, store, sell, or transmit personal data.

Artwork you create is stored locally on your device. If you choose to export
artwork to your Photos library, Gouache uses iOS's save-to-Photos permission
for that user-initiated action.

Gouache does not use analytics SDKs, advertising networks, tracking SDKs,
crash-reporting services, accounts, or user-facing network features.

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
- [ ] Phase 6: App Store prep — screenshots, TestFlight, App Store Connect metadata
