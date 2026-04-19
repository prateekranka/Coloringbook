---
date: 2026-04-14
topic: Accessibility baseline (Phase A4)
status: complete
related_plan: docs/plans/2026-04-14-001-feat-app-store-readiness-roadmap-plan.md
tests: ColorFlowUITests/AccessibilityUITests.swift
---

# Accessibility Baseline — Phase A4

Minimum-viable coverage for App Review and VoiceOver users. Not a full
accessibility audit — that is a separate pass once the v1 feature set is locked.

## What this unit shipped

### VoiceOver labels + identifiers on icon-only controls

Every icon-only `Button` in the coloring pipeline now carries both an
`accessibilityLabel` (for VoiceOver) and an `accessibilityIdentifier` (for
UI tests). Identifiers use a dotted-namespace convention (`canvas.undo`,
`library.template.<uuid>`, etc.) so UI tests can target them without
depending on user-facing copy.

Covered surfaces:

| Surface        | File                                          | Labels added                                                                |
| -------------- | --------------------------------------------- | --------------------------------------------------------------------------- |
| Tab bar        | `ColorFlow/App/ColorFlowApp.swift`            | identifiers on each tab root                                                |
| Home           | `ColorFlow/Views/Home/HomeView.swift`         | `+` button, "Browse Templates" CTA, recent/suggested cells                  |
| Library        | `ColorFlow/Views/Library/LibraryTabView.swift` | category tabs, template cards                                               |
| Canvas toolbar | `ColorFlow/Views/Tools/ToolbarView.swift`     | back, toolbar toggle, color well, each tool, brush size slider, undo/redo, layers |
| Canvas chrome  | `ColorFlow/Views/Canvas/CanvasView.swift`     | floating back + restore-toolbar buttons                                     |
| Layers sheet   | `ColorFlow/Views/Tools/LayerPanelView.swift`  | visibility toggle per layer                                                 |
| Color picker   | `ColorFlow/Views/Tools/ColorPickerView.swift` | swatches labeled with hex value + selection trait                           |

### 44pt tap targets

Added `AppTheme.minTapTarget: CGFloat = 44` and applied it to icon-only
buttons that previously framed at 36–40pt. Hit area is expanded via
`.frame(...)` + `.contentShape(Rectangle())` so VoiceOver and Switch Control
can reliably focus the full control even when the rendered icon is smaller.

### Dynamic Type

The dark-mode pass already uses semantic fonts (`.title2`, `.subheadline`,
`.caption`, `.headline`) throughout Home and Library. No hardcoded point
sizes on body copy. Icon-only buttons keep fixed point sizes on purpose —
SF Symbols don't need Dynamic Type.

### Contrast

`AppTheme.textSecondary` = `Color(white: 0.65)` on background `#1C1C1E`
yields a contrast ratio of **~7.0:1**, which clears WCAG AAA for normal
text. No bump needed; kept as-is.

### Accent + selection state

Selected-tool buttons now carry `.isSelected` accessibility trait so
VoiceOver announces "selected" alongside the tool name. Same for the
category bar in Library.

## What this unit deliberately did not do

- **No change to forced `.dark` preferredColorScheme.** The plan calls out
  that the app locks dark mode; increased-contrast and light-theme support
  is a future feature, not an A4 deliverable. iOS's "Increase Contrast"
  accessibility setting still flows through to standard material and text
  because `AppTheme.textPrimary = .white` picks up dynamic contrast
  adjustments automatically.
- **No Reduce Motion pass.** CanvasView uses `withAnimation(...)` for the
  toolbar slide; Reduce Motion integration is deferred until we have a
  motion inventory across the app.
- **No locale pseudo-loc run.** Copy is still English-only; a separate
  localisation sweep is pre-submission work.

## Manual verification (recommended before submission)

- Run Xcode's Accessibility Inspector on Home, Library, My Work, and Canvas.
  Every interactive element should show a non-empty label and a sensible
  trait.
- Turn on VoiceOver on a real iPad and swipe through Home → Library. Every
  card should announce name + category + difficulty.
- Enable Larger Text (XL) in Settings → Accessibility → Display & Text Size
  → Larger Text. Confirm Home's hero copy, section headers, and cells
  still lay out without clipping.

These are **manual** gates; the UI tests in
`ColorFlowUITests/AccessibilityUITests.swift` encode the automation-friendly
subset (identifier presence + tab reachability).

## Follow-ups (not blockers for v1)

- Canvas UI test is scaffolded but currently skipped — seeding a template
  fixture requires the UI test target plumbing tracked in F-05.
- Consider an `AppTheme.hitTargetPadding(_:)` view modifier to remove the
  repeated `.frame(minWidth:minHeight:)` + `.contentShape(Rectangle())`
  pair. Leaving the explicit pattern for now so reviewers can see where
  44pt is enforced.
