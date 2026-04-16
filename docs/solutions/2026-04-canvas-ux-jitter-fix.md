---
date: 2026-04-16
topic: Canvas UX — jitter fix, default tool, stay-in-the-lines
status: complete
related_plan: docs/plans/2026-04-15-001-fix-canvas-ux-fill-bounce-premium-plan.md
tests: ColorFlowTests/Canvas/
---

# Canvas UX — Stop the Bouncing, Make Fill Work, Verify Brushes, Add Stay-in-the-Lines

## The three bugs

1. **Default tool mismatch.** `BrushSettings.tool` defaulted to `.pencil`. On finger-only iPads, the first tap after onboarding produced nothing because PencilKit refuses finger input via `drawingPolicy = .pencilOnly`, and the tap gesture recognizer is disabled for drawing tools. Onboarding says "Tap to Fill" but the default tool wasn't Fill.

2. **Canvas bounce/drift.** `PencilCanvasRepresentable`'s outer `UIScrollView` had `bounces = true` (default) and `isScrollEnabled` was always on. Finger contact on a fitted canvas caused the content to drift within its bounce zone. Additionally, `updateContentSize` re-applied `setZoomScale(fitScale)` on every call — including during toolbar animation frames — causing visible jitter.

3. **No first-use guidance.** No haptic, no hint, no visual affordance when the user enters the canvas. New users stared at a dark screen with a dormant toolbar.

## The three fixes

1. **U2: Post-onboarding default tool resolution.** `CanvasViewModel.init` reads `UserDefaults("lastUsedTool")`. If present + valid → use it. If absent + `hasSeenOnboarding` → `.floodFill`. Pre-onboarding → `.pencil`. `ToolbarView` writes back on every tool switch.

2. **U3 + U4: Finger-pan gate + bounds-flutter guard.**
   - `scrollView.bounces = false` — kills pan-bounce entirely.
   - `updatePanGate()` disables `isScrollEnabled` when `zoomScale <= fitScale + epsilon`. Called from `updateContentSize` and `scrollViewDidEndZooming`.
   - `lastAppliedContentSize` guard skips `setZoomScale` when `updateContentSize` is called with the same size (toolbar animation flutter).

3. **U5: First-use fill hint + canvas-entry haptic.** Non-blocking "Tap a region to fill" overlay gated on `hasCompletedFirstFill`. Dismisses after first successful fill. Canvas entry fires `.light` haptic once per appearance.

## Three invariants to preserve

1. **Finger-pan is OFF when fitted.** `scrollView.isScrollEnabled` must be `false` whenever `zoomScale <= fitScale + epsilon`. Test: `CanvasScrollViewConfigurationTests.test_whenFitted_scrollIsDisabled`.

2. **Bounds-flutter is debounced.** `updateContentSize` with the same size as the previous call must not re-apply `setZoomScale`. Test: `CanvasScrollViewConfigurationTests.test_repeatedUpdateContentSize_withinDebounceWindow_appliesFitZoomOnce`.

3. **Post-onboarding default is `.floodFill`.** A fresh install with `hasSeenOnboarding = true` and no `lastUsedTool` must open the canvas with Fill selected. Test: `CanvasDefaultToolTests.test_freshInstall_postOnboarding_defaultsToFloodFill`.

## Additional features shipped

- **U7: Brush verification harness.** Headless render-and-sample tests for all four brushes. `PixelSampler` helper samples pixel data from rendered exports. `-enableFingerDrawing` debug launch arg feathers `drawingPolicy` for FlowDeck automation (compiled out in Release).

- **U8: Stay-in-the-lines mode.** Commit-time stroke clipping via `clipStroke(_:toRegion:)`. New canvas settings sheet with toggle. Eraser exempt. Strokes starting outside all regions commit unclipped.
