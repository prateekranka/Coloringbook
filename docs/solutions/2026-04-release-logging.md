---
date: 2026-04-14
topic: Release build logging hygiene (Phase A3)
status: complete
related_plan: docs/plans/2026-04-14-001-feat-app-store-readiness-roadmap-plan.md
tests: ColorFlowTests/LoggingGatingTests.swift
---

# Release Build Logging Hygiene — Phase A3

Before shipping, ensure no init-time breadcrumbs, SVG-parse traces, or
"bundle resource URL is ..." dumps reach Console on a production device.
Apple's logging guidance is explicit: `Logger.fault(...)` is meant for
crash-worthy conditions and is **always** shown; it was being used for
routine breadcrumbs.

## What this unit shipped

### New: `ColorFlow/Utilities/AppLog.swift`

Central logging helper with two entry points:

- `AppLog.trace(_:_:)` — compiled out of Release builds via `#if DEBUG`,
  so breadcrumbs never reach a shipping binary. Used for `[CanvasVM]
  loadTemplate...`, template loading, onAppear, etc.
- `AppLog.error(_:_:)` — kept in Release for genuinely unexpected but
  recoverable conditions (e.g., `SVGParser` failure, fallback to the
  hardcoded template catalogue).

All existing `Logger(subsystem:category:)` instances are replaced by
typed statics on `AppLog` (`.app`, `.template`, `.canvas`, `.storage`,
`.svg`) so there's a single source of truth for subsystem names.

### Removed in shipping sources

- Every `NSLog(...)` call. `NSLog` bypasses the unified-logging system,
  can't be filtered or redacted, and appears on production devices.
- Every `Logger.fault(...)` call. Fault is reserved for crash-worthy
  conditions; breadcrumbs were demoted to `AppLog.trace`, and the single
  real failure path (missing template SVG → fallback catalogue) was
  demoted to `AppLog.error`.

### Release build settings

Confirmed in `project.yml` (no change needed):
- `SWIFT_OPTIMIZATION_LEVEL: -O` (Release)
- `ENABLE_TESTABILITY: NO` (Release)
- `DEBUG_INFORMATION_FORMAT: dwarf-with-dsym` (Release) — ensures dSYMs
  generate for crash symbolication
- `VALIDATE_PRODUCT: YES` (Release)

These were already correct; A3 didn't touch `project.yml`.

## Enforcement

`ColorFlowTests/LoggingGatingTests.swift` scans the `ColorFlow/` source
tree and fails if any `NSLog(` or `Logger.fault(` call sneaks back in. It
also asserts that `AppLog.swift` exists. Any future contributor who adds a
breadcrumb via the wrong channel will see a red test locally.

As with the other A1/A2/A4 test files, this runs once the `ColorFlowTests`
target is wired in `project.yml` (tracked as F-05).

## Manual verification (pre-submission)

Archive a Release build and tail Console.app on a real iPad:

    xcodebuild -project ColorFlow.xcodeproj -scheme ColorFlow \
      -configuration Release archive \
      -archivePath /tmp/ColorFlow.xcarchive

Filter Console to `subsystem:com.colorflow.app`. A Release build should
emit **no** `default`-level messages during normal use and **no**
`fault`-level messages at launch. `.error` entries should only appear in
actual failure paths (e.g., an unparseable SVG).

Confirm `dSYMs/ColorFlow.app.dSYM/` exists inside the archive; the UUID
must match `lipo -info` on the binary for symbolication to work in App
Store Connect crash reports.

## Follow-ups

- `ColorFlow/Views/Canvas/PencilCanvasRepresentable.swift` still uses
  `print(...)` in several places. Those are raw stdout, not OSLog, and
  are stripped from Release only because stdout goes to /dev/null on
  device. They don't leak to Console, but they're still technical debt —
  scheduled to be migrated to `AppLog.trace` as part of Phase B's canvas
  refactor, not A3.
