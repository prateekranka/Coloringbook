# Canvas — Design References

## Current State
- Full-bleed white canvas with PencilKit
- Left-side collapsible toolbar (back, tools, undo/redo, layers, settings, color well)
- Floating draggable color picker HUD (flower wheel + hue ring + recent colors)
- Radial tool selector on long-press
- Brush size/opacity drawer opens to the right of toolbar rail

## References

### 1. ArtRage — Sidebar Toolbox + Color Wheel
- **URL**: https://www.artrage.com/artrage-vitae/
- **What to borrow**: Left sidebar with brush tools, right sidebar with color wheel + palette picker + hue/saturation sliders. The canvas dominates the center. Tools are visually grouped by function.
- **Apply to**: Toolbar grouping, color picker layout

### 2. Procreate — Minimal Chrome
- **URL**: https://procreate.com/en/procreate
- **What to borrow**: Tools are gesture-accessible (tap to toggle, swipe to resize). The canvas is the hero — almost no visible chrome. Tools appear only when needed.
- **Apply to**: Consider auto-hiding toolbar after inactivity, making tools more gesture-driven

### 3. Craft — Color Picker Bottom Sheet
- **URL**: Craft mobile app
- **What to borrow**: Color picker is a bottom-sheet with Grid/Sliders tabs, hex input, RGB fields, preview swatch, and quick color presets. Clean and functional.
- **Apply to**: Add hex input field to the floating color picker, add RGB sliders mode

### 4. Ditto Music — Canvas + Side Controls
- **URL**: https://dittomusic.com/en/spotify-canvas
- **What to borrow**: Left sidebar gallery + central large preview + right-side editing controls with sliders. The layout is balanced — controls don't overlap the canvas.
- **Apply to**: Color picker positioning (don't overlap canvas content)

### 5. iMovie — Modal Color Picker with Swatch Grid
- **URL**: iMovie mobile app
- **What to borrow**: Modal color picker with a grid of preview tiles (Yellow, Beige, Pink, etc.). Tap to select, Done/Cancel to confirm. Simple and clear.
- **Apply to**: Palette mode in the color picker

## Proposed Changes Summary
1. **Color picker**: Add hex input field below flower wheel, add RGB slider mode toggle
2. **Toolbar**: Group tools visually (drawing, navigation, canvas), add subtle dividers
3. **Brush drawer**: Show live preview stroke as user adjusts size
4. **Radial selector**: Enhance with haptic feedback + tool name labels
5. **Auto-hide**: Consider hiding toolbar after 3s of drawing inactivity
