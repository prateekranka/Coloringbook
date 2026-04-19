# App Store Screenshots — ColorFlow

## Required sizes (as of App Store Connect 2024+)

iPad screenshots are the only required device type (iPhone screenshots are
not needed for an iPad-only app unless Universal is checked — it is not).

| Slot name in App Store Connect | Display size    | Required resolution (portrait) | Required resolution (landscape) |
|-------------------------------|-----------------|-------------------------------|--------------------------------|
| iPad Pro 13-inch (M4)         | 13-inch / 6.9"  | 2064 × 2752 px                | 2752 × 2064 px                 |
| iPad Pro 12.9-inch (6th gen)  | 12.9-inch       | 2048 × 2732 px                | 2732 × 2048 px                 |

You **must** supply at least the 13-inch (M4) set. The 12.9-inch set is
optional but recommended because older devices are still common. App Review
may reject if only one size is provided and the other is clearly absent from
the store page.

App Store Connect accepts both JPEG and PNG. Use PNG to avoid compression
artifacts on the line art.

**Status bar:** must not show simulated battery or Wi-Fi icons unless they
are genuinely captured from the simulator or device. The cleanest approach
is to hide the status bar at capture time (or crop it out) and use a clean
simulator screenshot.

---

## Shot list — v1 (5 screenshots per device size)

Capture all shots on an **iPad Pro 13-inch simulator** running the latest
iPadOS. The app is dark-themed; ensure the simulator's dark appearance is on.

### Shot 1 — Home tab (feature overview)

- Template: Home tab visible, Recent Work section populated with 2–3 completed projects
- Thumbnail row showing suggested templates beneath
- Goal: first impression — "there's real content here"
- Overlay text idea: **"Dozens of hand-drawn templates"**

### Shot 2 — Library tab (template grid)

- Library tab open, "All" category selected, 8+ template cards visible in the grid
- Several categories visible via category pills: Mandalas, Animals, Botanicals
- Goal: shows catalog breadth
- Overlay text idea: **"Browse by category"**

### Shot 3 — Canvas (partially colored)

- Open a mandala or botanical template; color 6–8 regions with a warm palette
- Toolbar visible on the left; color picker recently used
- Goal: shows the coloring experience itself
- Overlay text idea: **"Tap to fill, or paint freehand"**

### Shot 4 — Canvas (Apple Pencil strokes)

- Same or different template; visible Pencil strokes over a region (not just flood fill)
- Toolbar shows Pencil tool selected
- Goal: shows Apple Pencil support
- Overlay text idea: **"Full Apple Pencil support"**

### Shot 5a — Photo-to-template result (if Phase C ships)

- Split: left half shows a photo, right half shows the generated coloring page open in the canvas
- Or: just the canvas view of a photo-derived template being colored
- Goal: the differentiating feature
- Overlay text idea: **"Turn any photo into a coloring page"**

### Shot 5b — Layers panel (if Phase C doesn't ship)

- Canvas open, Layers sheet pulled up showing Line Art / Color / Background layers
- Demonstrates feature depth without Phase C
- Overlay text idea: **"Layers, undo/redo, and export"**

---

## Capture workflow

1. Open `ColorFlow.xcodeproj` in Xcode.
2. Select the **iPad Pro 13-inch** simulator.
3. Build and run; navigate to each state described in the shot list.
4. Use **⌘S** in the simulator (File → Save Screen) or `xcrun simctl io booted screenshot screenshot.png` to capture.
5. Do **not** include the simulator chrome (window frame). Crop to the device screen only if needed.
6. Rename each file per the naming convention below and place it in this directory.

### Naming convention

```
colorflow_ipad_13in_01_home.png
colorflow_ipad_13in_02_library.png
colorflow_ipad_13in_03_canvas_fill.png
colorflow_ipad_13in_04_canvas_pencil.png
colorflow_ipad_13in_05_photo.png          (or _05_layers.png)
colorflow_ipad_12_9in_01_home.png         (12.9" set if captured)
...
```

---

## Optional: screenshot overlay frames

If you add marketing text overlays (the "overlay text idea" rows above),
use the `SF Pro Display` font family to stay consistent with Apple's
marketing aesthetic. White text on the dark canvas works without a separate
background frame. Keep overlays outside the canvas area to avoid obscuring
the art.

No overlay is required — plain simulator screenshots are accepted by App
Review. Overlays are for the store page presentation.

---

## Preview video (optional)

A 15–30 second screen recording showing:
1. Opening a template from the Library
2. Tapping to flood-fill a few regions
3. Switching to the Pencil tool and drawing a stroke
4. (If Phase C) importing a photo and watching it convert

Export as H.264 MP4 at the required resolution. App Store Connect accepts
`.mov` as well. Max 500 MB, min 15 s.
