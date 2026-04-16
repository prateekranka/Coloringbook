# Canvas QA — Manual Smoke Test

Run this 5-minute smoke on a clean simulator to verify the canvas surface works end-to-end.

## Prerequisites

- iPad simulator booted (iPad Air 11-inch M4 or iPad Pro 13-inch M5 recommended)
- App installed via `flowdeck run` or Xcode

## Steps

### 1. Reset state
```bash
flowdeck stop
# Delete the app to clear UserDefaults
flowdeck uninstall -S "iPad Air 11-inch (M4)"
flowdeck run -S "iPad Air 11-inch (M4)"
```

### 2. Onboarding
- Advance through all onboarding screens
- Confirm the final screen says "Tap to Fill"

### 3. First canvas entry
- Open any template from the Library tab
- **Verify:** Fill tool is selected in the toolbar (drop icon highlighted)
- **Verify:** "Tap a region to fill" hint appears near the bottom
- **Verify:** A subtle haptic fires on canvas entry (device only)

### 4. First fill
- Tap inside an enclosed region
- **Verify:** Region fills with the selected color in < 300ms
- **Verify:** Hint overlay disappears after successful fill
- **Verify:** Haptic fires on fill (device only)

### 5. Fill three regions with distinct colors
- Open the color picker, select red, tap a region
- Select blue, tap a different region
- Select green, tap a third region
- **Verify:** All three regions show their assigned colors

### 6. Pan/zoom behavior (fitted)
- With the canvas at default zoom (fitted), drag with a finger
- **Verify:** Canvas does NOT drift or bounce — stays perfectly still

### 7. Pan/zoom behavior (zoomed)
- Pinch in to zoom past fit scale
- Drag with a finger
- **Verify:** Canvas pans normally
- Pinch out back to fit
- **Verify:** Pan is disabled again — no drift

### 8. Toolbar collapse
- Tap the sidebar-toggle button to collapse the toolbar
- **Verify:** Canvas stays visually still during the 220ms animation (no jitter)
- Tap to restore the toolbar

### 9. Undo/redo
- Tap Undo three times
- **Verify:** Three fills revert in reverse order
- Tap Redo
- **Verify:** One fill re-applies

### 10. Stay in the lines
- Tap the "..." button at the bottom of the toolbar
- Toggle "Stay in the lines" ON
- Select a drawing tool (pencil or marker)
- Draw a stroke that starts inside a region and crosses the boundary
- **Verify:** Only the portion inside the starting region is visible
- Toggle OFF, draw freely
- **Verify:** Stroke renders without clipping

### 11. Brushes (Pencil iPad only, or use -enableFingerDrawing debug flag)
- Select each brush: pencil, marker, watercolor, eraser
- Draw a short stroke with each
- **Verify:** Each brush produces a visually distinct stroke
- **Verify:** Eraser removes strokes but does not affect filled regions

### 12. Persistence
- Close the project (back button)
- Reopen the same project from Library or My Work
- **Verify:** All fills, strokes, and undo history are preserved

### 13. Non-Pencil iPad verification
- On a non-Pencil simulator with default settings:
  - Fill tool is selected on first canvas entry
  - Tap-to-fill works immediately
  - Drawing tools do not respond to finger (drawingPolicy = .pencilOnly)

## FlowDeck automation alternative

For CI or automated runs:
```bash
bash Scripts/qa/canvas_smoke.sh
```

The script drives steps 1-6 via FlowDeck UI automation with log-scrape assertions.
