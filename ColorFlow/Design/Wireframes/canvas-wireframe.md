# Canvas — Wireframe

## Layout Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ┌─────┐                                                │
│  │ [←] │  ← Back button (chevron.left)                  │
│  │[≡]  │  ← Toggle sidebar (sidebar.left)               │
│  ├─────┤                                                │
│  │     │                                                │
│  │ ✏️  │  ← Pencil (selected = accent bg)               │
│  │ 🖌️  │  ← Brush                                       │
│  │ 🪣  │  ← Fill                                        │
│  │ 🧹  │  ← Eraser                                      │
│  ├─────┤                                                │
│  │ ↩️  │  ← Undo                                        │
│  │ ↪️  │  ← Redo                                        │
│  ├─────┤                                                │
│  │ 📑  │  ← Layers                                      │
│  │ ⋯  │  ← Settings (ellipsis)                         │
│  ├─────┤                                                │
│  │     │                                                │
│  │ 🟢  │  ← Color well (circle, 32pt)                  │
│  └─────┘                                                │
│                                                         │
│  ┌─── Drawer (appears when tool tapped twice) ────┐    │
│  │  Brush size                                     │    │
│  │  ──────────────────────────────  ← scrubber     │    │
│  │                                                 │    │
│  │  Opacity (inking tools only)                    │    │
│  │  ──────────────────────────────  ← slider       │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│           CANVAS (full-bleed, white)                     │
│                                                         │
│  ┌─── Floating Color Picker (draggable HUD) ──────┐    │
│  │  ─── (drag handle)                    [×]      │    │
│  │  [Default ▼]                                   │    │
│  │  ┌─────────────────────────────────────────┐   │    │
│  │  │                                         │   │    │
│  │  │         🌸 FLOWER WHEEL                 │   │    │
│  │  │         (hue ring + swatches)           │   │    │
│  │  │                                         │   │    │
│  │  └─────────────────────────────────────────┘   │    │
│  │  ┌─ Brightness ─────────────────────────────┐  │    │
│  │  │  ████████████░░░░░░░░░░░░░░░░░░░░░░░░░  │  │    │
│  │  └──────────────────────────────────────────┘  │    │
│  │  Recent: 🟢 🔴 🔵 🟡 🟣 🟠                    │    │
│  │  ┌─ Hex ───────────────────────────────────┐   │    │
│  │  │  #7AB887                                │   │    │  ← NEW
│  │  └─────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Toolbar Rail Specs

```
┌─────┐
│     │  Width: 44pt (touchTarget)
│     │  Padding: 12pt vertical, 6pt horizontal
│     │  Background: .regularMaterial
│     │  Corner radius: Radius.lg (16)
│     │  Margin: 12pt from leading edge, 12pt from top
│     │
│     │  Button size: 44×44pt (touchTarget)
│     │  Icon size: 18pt
│     │  Icon weight: .medium (selected: .semibold)
│     │  Selected bg: Brand.accentSubtle
│     │  Selected icon: Brand.accent
│     │  Unselected icon: Ink.primary
│     │
│     │  Divider: 1pt, Ink.tertiary at 0.15 opacity
│     │  Divider padding: 6pt horizontal
└─────┘
```

## Drawer Specs

```
┌─────────────────────────────┐
│  Brush size                 │  ← Label (Font.cfCaption)
│  ────────────────────────   │  ← BrushSizeScrubber
│                             │    Width: 120pt
│  Opacity (inking only)      │  ← Label
│  ────────────────────────   │  ← Slider, 0.1...1.0
└─────────────────────────────┘

Width: 150pt (fixed)
Padding: 14pt horizontal, 16pt vertical
Background: .regularMaterial
Corner radius: Radius.lg (16)
Border: Stroke.hairline (1pt)
Position: Right of toolbar rail, top-aligned
Transition: .move(edge: .leading) + .opacity
```

## Floating Color Picker Specs

```
Card size: 560×680pt (fixed)
Corner radius: Radius.xxl (24)
Background: .regularMaterial
Border: Stroke.hairline (1pt)
Shadow: .black opacity 0.08, radius 4, y 2
        .black opacity 0.18, radius 24, y 12

Drag handle: Capsule, 36×4pt, Ink.tertiary
Header: "Color" label + × button
Mode switch: [Default ▼] pill button
Flower wheel: 420pt height, 18pt horizontal padding
Brightness strip: Full width, 18pt padding
Recent row: Horizontal scroll, 28pt circles
NEW: Hex input field below recent row
```

## Radial Tool Selector Specs

```
Summoned by: Long-press (0.35s) on canvas
Center: Touch point
Tools arranged in circle around center
Each tool: 44pt circle with icon
Active tool: Accent background
Animation: Spring (response 0.35, damping 0.72)
```

## Key Changes from Current

1. **Color picker**: Add hex input field below recent colors
2. **Toolbar grouping**: Visual dividers between tool groups (drawing, undo/redo, layers)
3. **Drawer**: Show live preview stroke when adjusting brush size
4. **Auto-hide**: Consider hiding toolbar after 3s of drawing inactivity
