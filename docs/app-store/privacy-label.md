# App Store Privacy Label - Gouache

Answers to the App Store Connect "App Privacy" questionnaire. Keep this file,
`ColorFlow/PrivacyInfo.xcprivacy`, and
`docs/solutions/2026-04-privacy-manifest-audit.md` in sync whenever data
practices change.

## Does this app collect data?

No.

Select "No, we do not collect data from this app" in App Store Connect.

## Detailed answers

| Category | Collected? | Reason |
| --- | --- | --- |
| Contact info | No | No accounts, sign-in, forms, or user-facing network calls. |
| Health & fitness | No | Not applicable. |
| Financial info | No | No in-app purchases or payment flows in v1. |
| Location | No | App does not call CoreLocation. |
| Sensitive info | No | No sensitive category access. |
| Contacts | No | App does not call Contacts. |
| User content | No | Artwork is stored locally on-device and may be saved to the user's own Photos library only when the user chooses export. It is not transmitted off-device by Gouache. |
| Browsing history | No | No web views or URL tracking. |
| Search history | No | Template search/filtering is local and not transmitted. |
| Identifiers | No | No analytics, ads, device identifiers, or tracking SDKs. |
| Usage data | No | No session analytics. |
| Diagnostics | No | No crash reporter such as Crashlytics, Sentry, or Firebase. |
| Other data | No | Not applicable. |

## Third-party SDKs with their own privacy manifests

None. Gouache ships first-party app code and Apple frameworks only. SVGKit is
not linked into the app target, and no third-party analytics, ads, or crash
reporting SDK is present at submission time.

## Required Reason API summary

| API category | Used via | Reason code |
| --- | --- | --- |
| UserDefaults | same-app settings such as onboarding, recent colors, and app preferences | CA92.1 |

No other Required Reason API categories are declared or expected for v1.

## Photo library access

The app requests write-only Photos access through
`NSPhotoLibraryAddUsageDescription` so the user can save finished artwork to
their Photos library.

Gouache v1 does not request read access to the user's photo library and does
not include a photo-import feature. Do not add `NSPhotoLibraryUsageDescription`
back until a user-facing import flow is implemented, tested, and listed in App
Store metadata.

## Camera access

Gouache v1 does not request camera access and does not include a camera feature.
Do not add `NSCameraUsageDescription` back until a user-facing camera flow is
implemented, tested, and listed in App Store metadata.

## Changes that would flip the "No data collected" answer

Any of these require updating this file, the privacy manifest, and App Store
Connect before submission:

1. Adding analytics, ads, attribution, crash reporting, remote config, or any SDK that transmits data off-device.
2. Adding accounts, sync, cloud storage, support forms, or contact collection.
3. Adding iCloud or server sync for artwork or user templates.
4. Adding user-facing network features that transmit artwork, photos, identifiers, or diagnostics.
5. Adding photo import/camera features that transmit images off-device.
