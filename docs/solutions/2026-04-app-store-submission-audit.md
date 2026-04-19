---
date: 2026-04-14
topic: App Store submission readiness audit (Phase A1)
status: partial
related_plan: docs/plans/2026-04-14-001-feat-app-store-readiness-roadmap-plan.md
---

# App Store Submission Readiness Audit — Phase A1

Scope: mechanical submission hygiene on the current tracked tree. Findings are
categorised **Blocker** (rejection risk), **Major** (review friction / post-launch
surprise), or **Minor** (hygiene). Phase A2 and later cover privacy manifest
completeness, asset catalog contents, performance baselines, and store copy.

## Findings

| ID   | Severity | Area                          | Finding                                                                                                                                  | Resolution                                                                                       |
| ---- | -------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| F-01 | Blocker  | Info.plist / orientation      | `UISupportedInterfaceOrientations` (base) declared only `Portrait`, while `~ipad` variant declared all four. iPad Split View / Slide Over can hit the base key. | **Fixed.** Base key now mirrors `~ipad` with all four orientations. See `ColorFlow/Info.plist`. |
| F-02 | Major    | Info.plist / export compliance | `ITSAppUsesNonExemptEncryption` missing. Each TestFlight upload would prompt the submitter. App uses only Apple-provided TLS, no custom crypto. | **Fixed.** Added `<false/>` with inline rationale.                                               |
| F-03 | Blocker  | Entitlements                  | `ColorFlow.entitlements` contained `com.apple.security.app-sandbox` — a **macOS** key. Harmless on iOS at build time but flags as misconfigured and is a code-sign surprise. | **Fixed.** Entitlements file reduced to an empty `<dict/>`. No iOS capabilities required today. |
| F-04 | Minor    | Asset catalog                 | `AppIcon.appiconset/` contained 9 orphan `Icon-*.png` files not referenced by `Contents.json` (which uses `AppIcon-*.png`). Dead weight in bundle; can confuse reviewers running `ipatool`. | **Fixed.** Orphans deleted. Tracked `AppIcon-*.png` set is complete for iPad (20/29/40/76/83.5 @1x+2x + 1024 marketing). |
| F-05 | Blocker  | Test target missing           | `project.yml` declares no test target. Plan unit A1 calls for `ColorFlowTests/InfoPlistValidationTests.swift`, but there is nowhere for it to run. `run_tests.sh` references scheme/targets that do not exist. | **Deferred to follow-up.** Test file authored at planned path with doc note. Adding a `ColorFlowTests` target to `project.yml` is pulled out of A1 to avoid scope creep. Tracked as a new blocker for A3 (Regression suite). |
| F-06 | Minor    | Shell scripts                 | `run_tests.sh` at repo root references non-existent targets; running it fails. Likely carry-over from an earlier scaffold.             | Leave in place for A3. Will be rewritten when the test target lands.                             |
| F-07 | Minor    | Repo hygiene                  | Root of repo previously contained duplicated `App/`, `Models/`, `Views/`, etc. untracked directories mirroring `ColorFlow/ColorFlow/`. Pure junk; confusing for new contributors. | **Fixed.** Removed prior to branching so cleanup does not propagate across branches.             |

## Not audited in A1 (explicitly deferred)

- **Privacy manifest completeness** — `PrivacyInfo.xcprivacy` currently declares only
  `CA92.1` (UserDefaults). File I/O API category not yet audited against
  `FileManager` usage. Owned by **A2**.
- **Purpose strings** — Only `NSPhotoLibraryAddUsageDescription` present. The photo
  import feature (Phase C) will need `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription`. Owned by **A2** (strings land early even though
  the feature is later, so the TestFlight build for Phase B already carries the
  copy).
- **Cold-launch baseline** — Plan asks for a launch-time baseline on iPad Pro 11"
  (iOS 17) and iPad (10th gen, iOS 17). Cannot be automated from this shell
  session; must be taken manually from Instruments once the test target and CI
  scaffolding land. Deferred into A3.
- **Archive build** — A final `xcodebuild archive` dry-run against the
  Release config was not executed in this session. Tracked as A5 work.

## Source of truth

All of these findings trace to a read-only pass of the tracked tree on branch
`feat/app-store-submission-audit-privacy` at commit
(see `git log -n 1 --format=%H` at the time of merge). No source files outside
the fixes listed above were modified.
