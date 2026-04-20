# Persona-Based UI Tests

## Overview

Persona tests simulate weeks of real user behavior compressed into minutes. They use accessibility-tree-based automation (via `axe`) to drive the app like a real user.

## Personas

### Daily Doodler
- **Behavior:** 20 short flood-fill sessions, rare save
- **Asserts:** No orphaned thumbnails, projects.json stays consistent
- **Duration:** ~2 minutes

### Deep Colorist
- **Behavior:** Long pencil sessions with 50+ strokes, heavy undo/redo, tool switching
- **Asserts:** PKDrawing data round-trips, file integrity
- **Duration:** ~3 minutes

### Tab Switcher
- **Behavior:** 30 rapid tab navigations, picker open/close, rotation mid-session
- **Asserts:** Picker offset stays in bounds after rotation, tab state preserved
- **Duration:** ~2 minutes

## Running Locally

```sh
# Run all personas
./Scripts/run_personas.sh

# Run a single persona
xcodebuild test \
  -project ColorFlow.xcodeproj \
  -scheme ColorFlow \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -only-testing:ColorFlowUITests/Personas/DailyDoodlerTests \
  -testLaunchArguments "-personaRun -skipOnboarding"
```

## Gating

Persona tests are gated behind the `-personaRun` launch argument. Without it, they skip via `XCTSkipIf`. This keeps them out of the default `./dev test` cycle.

## Known Flakes

- **Share sheet dismissal** (Deep Colorist): The system share sheet is outside the app's accessibility tree. Falls back to label-based selection.
- **Simulator boot timing**: If the simulator isn't fully booted, early steps may fail. The script waits 3 seconds after boot.

## When to Re-inventory Identifiers

After any view rename or accessibility identifier change, update `ColorFlow/Support/AccessibilityIdentifiers.swift`. The persona tests depend on these identifiers being stable.
