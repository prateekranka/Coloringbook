---
date: 2026-04-14
topic: Privacy manifest + purpose strings audit (Phase A2)
status: complete
related_plan: docs/plans/2026-04-14-001-feat-app-store-readiness-roadmap-plan.md
tests: ColorFlowTests/PrivacyManifestTests.swift
---

# Privacy Manifest & Purpose Strings Audit — Phase A2

Apple's App Store submission pipeline (in force since May 2024) rejects builds
that use specific "Required Reason" APIs without declaring them in
`PrivacyInfo.xcprivacy`, and rejects purpose-string prompts whose copy is
missing, empty, or unclear. This audit establishes the ColorFlow baseline.

## Required Reason API usage — direct scan of tracked sources

Scan performed against `ColorFlow/**/*.swift` on branch
`feat/app-store-submission-audit-privacy`.

| API category key                                        | Where we use it                                                                 | Reason code | Declared |
| ------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------- | -------- |
| `NSPrivacyAccessedAPICategoryUserDefaults`              | `@AppStorage("hasSeenOnboarding")` in `ColorFlow/App/ColorFlowApp.swift`; `@AppStorage("recentColors")` in `ColorFlow/ViewModels/CanvasViewModel.swift`. `@AppStorage` is UserDefaults-backed. | `CA92.1`    | ✅       |
| `NSPrivacyAccessedAPICategoryFileTimestamp`             | **Not used.** `FileManager` is used only for `fileExists`, `createDirectory`, `removeItem`, and `urls(for:in:)`. No reads of `creationDate`, `modificationDate`, or `attributesOfItem`. | —           | —        |
| `NSPrivacyAccessedAPICategorySystemBootTime`            | **Not used.**                                                                   | —           | —        |
| `NSPrivacyAccessedAPICategoryDiskSpace`                 | **Not used today.** If Phase C's on-device pipeline adds a pre-flight disk-space check, append this category with reason `85F4.1`. | —           | future   |
| `NSPrivacyAccessedAPICategoryActiveKeyboards`           | **Not used.**                                                                   | —           | —        |

## Third-party SDKs

None. Every dependency is a compile-time Swift source file in this repo.
SVGKit is declared in `Package.swift` but is stubbed out via `OTHER_LDFLAGS=""`
in `project.yml` and does not ship.

If a third-party SDK is added later, its own `PrivacyInfo.xcprivacy` must ship
inside its bundle; do not copy its entries into the app-level manifest.

## Data collection and tracking

- `NSPrivacyTracking`: `false`. App has no analytics, no ad SDK, no
  cross-app/website tracking.
- `NSPrivacyCollectedDataTypes`: empty. App persists everything to
  `Documents/` on the device only. Photos save via `UIImageWriteToSavedPhotosAlbum`
  targets the user's own Photos library, which is not "data collection" in
  Apple's taxonomy.

If this ever flips (e.g., adding crash reporting, remote config, purchases),
the App Privacy questionnaire in App Store Connect must be updated in the
same PR as the manifest change.

## Purpose strings (Info.plist)

The v1 submission carries only purpose strings for features that are visible
and reviewable in the shipping app. Photo-import and camera strings were removed
until those flows have user-facing UI and matching App Store metadata.

| Key                                    | Needed by                                 | Shipping now? | Copy reviewed for clarity? |
| -------------------------------------- | ----------------------------------------- | ------------- | -------------------------- |
| `NSPhotoLibraryAddUsageDescription`    | Save finished artwork to Photos (today)   | Yes           | Yes                        |
| `NSPhotoLibraryUsageDescription`       | Import a photo to a coloring page         | No            | Add when the feature ships |
| `NSCameraUsageDescription`             | Capture a photo to a coloring page        | No            | Add when the feature ships |

Copy follows Apple's guidance: specific, user-visible reason, no marketing.
When photo import/camera support ships, add the purpose strings in the same PR
as the visible picker/camera UI, tests, privacy-label update, and App Store copy.

Deliberately **not** shipping:
- `NSMicrophoneUsageDescription` — no audio input.
- `NSLocationWhenInUseUsageDescription` — no geofencing or localisation.
- `NSContactsUsageDescription` — no contact access.
- `NSFaceIDUsageDescription` — no biometric auth (there is no account).

## Enforcement

`ColorFlowTests/PrivacyManifestTests.swift` encodes the contract:
- Tracking is off.
- Data collection is empty.
- Required Reason API categories equal `{ UserDefaults }` exactly — adding a
  new category without updating this doc trips a test failure.
- The write-only Photos export purpose string is present and non-empty.
- Photo-library read and camera purpose strings stay absent until those features
  are visible and reviewable.

These tests run once the `ColorFlowTests` target is wired in `project.yml`
(blocker `F-05` in the A1 audit). Until then, the test file serves as the
contract that the wiring PR unlocks.

## Known limitations of this audit

- **Static analysis only.** No dynamic Instruments trace was run to catch
  APIs invoked via UIKit/SwiftUI internals that would also need declaration.
  Apple's static analyzer in App Store Connect runs its own pass at upload
  time; any gap will surface there as a non-blocking warning on the first
  TestFlight upload and is easy to remediate before promoting to production.
- **Photo-to-template remains future work.** If the photo feature lands
  differently than the research pack suggests (e.g., requires network calls for
  model fetch), the `NSPrivacyTracking` / data-collection posture must be
  re-evaluated before it ships.
