# App Store Privacy Label — ColorFlow

Answers to the App Store Connect "App Privacy" questionnaire. Derived from
and consistent with `docs/solutions/2026-04-privacy-manifest-audit.md`.

Update both documents together whenever the app's data practices change.

---

## Does this app collect data?

**No.**

Select "No, we do not collect data from this app" in App Store Connect.

---

## Detailed answers (in case App Review questions the "No" selection)

The answers below document why each data category is "Not collected":

| Category                         | Collected? | Reason                                                                           |
|----------------------------------|------------|----------------------------------------------------------------------------------|
| Contact info (name, email, etc.) | No         | No accounts, no sign-in, no user-facing network calls.                          |
| Health & fitness                 | No         | Not applicable.                                                                  |
| Financial info                   | No         | No IAP, no payment flows in v1.                                                 |
| Location                         | No         | App never calls CoreLocation.                                                    |
| Sensitive info                   | No         | No sensitive category access.                                                    |
| Contacts                         | No         | App never calls Contacts framework.                                             |
| User content (artwork)           | *Stored locally only* — artwork stays in the app's Documents directory and the user's own Photos library. Not transmitted to any server. App Store defines "collect" as transmitting off-device; this data never leaves the device. |
| Browsing history                 | No         | No web views, no URL tracking.                                                   |
| Search history                   | No         | Template search is in-memory, not persisted or transmitted.                     |
| Identifiers (Device ID, etc.)    | No         | No analytics SDK, no advertising framework.                                     |
| Usage data (crashes, sessions)   | No         | No crash reporter, no session analytics in v1.                                  |
| Diagnostics                      | No         | No Crashlytics, Sentry, Firebase, or equivalent.                                |
| Other data                       | No         |                                                                                  |

---

## Third-party SDKs with their own privacy manifests

None. ColorFlow has no third-party SDK dependencies at submission time.
Every capability uses first-party Apple frameworks (SwiftUI, PencilKit,
Vision, CoreML, Core Image, CoreGraphics, Foundation).

---

## Required Reason API summary

See `docs/solutions/2026-04-privacy-manifest-audit.md` for the full audit.
Summary for the App Privacy form:

| API category                     | Used via                            | Reason code |
|----------------------------------|-------------------------------------|-------------|
| UserDefaults                     | `@AppStorage` (onboarding flag, recent colors) | CA92.1 |

No other Required Reason APIs are in use today.

---

## Photo library access

The app requests **write-only** access (`NSPhotoLibraryAddUsageDescription`)
to save finished artwork. It does NOT read the user's existing photos today.

Phase C (photo-to-template) will add **read** access
(`NSPhotoLibraryUsageDescription`). The purpose string is already in
`Info.plist` per the A2 audit (shipped early to avoid a second review
cycle). The privacy label answer remains "No data collected" because the
photo is processed entirely on-device and no bytes are transmitted.

---

## Camera access

Phase C adds camera capture. Same analysis: photo processed on-device, not
transmitted. Privacy label stays "No data collected."
`NSCameraUsageDescription` is already in `Info.plist`.

---

## Changes that would flip the "No data collected" answer

Any of these would require updating this document AND the App Store listing:

1. Adding an analytics SDK (Mixpanel, Amplitude, Firebase Analytics, etc.)
2. Adding a crash reporter that transmits stacks off-device (Crashlytics, Sentry)
3. Adding remote config / feature flags that call a server with a device identifier
4. Adding iCloud sync (would require justifying "user content" collection)
5. Adding a CDN for ambient sounds that logs access with any device-identifying header

If any of these land, update the privacy manifest, re-run the A2 audit, and
update this document before the next submission.
