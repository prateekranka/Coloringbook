# App Store Listing Copy — ColorFlow v1

Source of truth for all App Store Connect text fields. Update this doc and
re-paste into App Store Connect together — never edit one without the other.

Two description variants are maintained: **v1-without-photo** (Phase A+B submission)
and **v1-with-photo** (Phase A+B+C submission). Choose the applicable variant at
submission time.

---

## Identity fields

| Field               | Value                             | Character limit |
|---------------------|-----------------------------------|-----------------|
| App Name            | ColorFlow                         | 30              |
| Subtitle            | Coloring Book for iPad            | 30              |
| Bundle ID           | com.prateekranka.colorflow        | —               |

---

## Description

### v1-with-photo (preferred — use when Phase C ships)

```
ColorFlow turns your iPad into a distraction-free coloring studio.

Dozens of hand-drawn templates span mandalas, botanicals, animals, abstract patterns, architecture, and everyday scenes. Tap any region to flood-fill it with color, or pick up an Apple Pencil and paint freehand — the canvas handles both naturally.

COLORING, YOUR WAY
• Tap-to-fill: choose a color from curated palettes and tap any enclosed region to fill it instantly.
• Freehand drawing: full Apple Pencil support with adjustable brush size and opacity.
• Undo/redo on every stroke and fill, with separate layer controls for line art and color.
• Export finished artwork straight to your Photos library in full resolution.

TURN ANY PHOTO INTO A COLORING PAGE
• Import a photo from your library or capture one with your camera.
• ColorFlow analyzes it on-device and generates a hand-drawn coloring page in seconds.
• Your photos never leave your device — all processing happens locally.
• Choose from three styles: Simple, Detailed, or Artistic (powered by on-device AI).

DESIGNED FOR IPAD
• Optimized for iPad Pro, iPad Air, and iPad — with or without Apple Pencil.
• Works great in Split View alongside music, podcasts, or reference photos.
• Dark canvas keeps the focus on your colors.

Privacy note: ColorFlow collects no personal data and makes no network requests during use.
```

### v1-without-photo (fallback — use if Phase C slips)

```
ColorFlow turns your iPad into a distraction-free coloring studio.

Dozens of hand-drawn templates span mandalas, botanicals, animals, abstract patterns, architecture, and everyday scenes. Tap any region to flood-fill it with color, or pick up an Apple Pencil and paint freehand — the canvas handles both naturally.

COLORING, YOUR WAY
• Tap-to-fill: choose a color from curated palettes and tap any enclosed region to fill it instantly.
• Freehand drawing: full Apple Pencil support with adjustable brush size and opacity.
• Undo/redo on every stroke and fill, with separate layer controls for line art and color.
• Export finished artwork straight to your Photos library in full resolution.

DESIGNED FOR IPAD
• Optimized for iPad Pro, iPad Air, and iPad — with or without Apple Pencil.
• Works great in Split View alongside music, podcasts, or reference photos.
• Dark canvas keeps the focus on your colors.

Privacy note: ColorFlow collects no personal data and makes no network requests during use.
```

---

## Keywords (100 characters max, comma-separated)

```
coloring book,adult coloring,mandala,drawing,art,sketch,paint,relax,mindful,pencil,doodle,pattern
```

Character count: 97 ✓

Keyword strategy notes:
- "adult coloring" and "coloring book" are the highest-traffic App Store terms in this category.
- "mandala" is a standalone high-volume term; don't roll it into "coloring book".
- Avoid repeating words from the app name ("ColorFlow") or subtitle ("coloring", "iPad") — App Store search indexes those automatically.
- Reserve "mindful" and "relax" for mental wellness adjacent discovery; "pattern" catches architecture/abstract seekers.

---

## Promotional text (170 characters max — updatable without resubmission)

**v1 launch:**
```
New: turn any photo into a hand-drawn coloring page. All processing stays on your device.
```
(89 chars ✓)

**Fallback if Phase C slips:**
```
Hand-drawn templates for mandalas, botanicals, animals, and more. Distraction-free coloring for iPad.
```
(101 chars ✓)

---

## Release notes — version 1.0

```
Welcome to ColorFlow.

Tap to fill any region, paint freehand with Apple Pencil, or turn a photo into a coloring page — all on your iPad, all offline.
```

---

## Support and marketing URLs

These must be live URLs at submission time. A GitHub Pages one-pager is
acceptable for v1.

| Field          | Target                                      | Status      |
|----------------|---------------------------------------------|-------------|
| Support URL    | `https://github.com/prateekranka/colorflow` | Needs setup |
| Marketing URL  | Same as support URL for v1                  | Needs setup |
| Privacy Policy | Inline section on the support page          | Needs setup |

### Minimum privacy policy copy (inline on support page)

```
ColorFlow Privacy Policy

ColorFlow does not collect, store, or transmit any personal data.

All artwork you create is stored locally on your device in your app's Documents directory.
If you choose to export artwork to your Photos library, that action uses iOS's standard
save-to-Photos permission (NSPhotoLibraryAddUsageDescription).

The app does not use analytics SDKs, advertising networks, or crash-reporting services
that transmit data off your device.

For questions, open an issue at: https://github.com/prateekranka/colorflow
```

---

## Age rating

Expected rating: **4+** (no objectionable content, no user-generated content
sharing, no location). Confirm in the Rating questionnaire during submission.

---

## Content rights

All bundled SVG templates are original works produced for this app. No
licensed IP, no third-party stock art. The Informative Drawings CoreML model
(Phase C) is covered by its MIT license (carolineec/informative-drawings).

---

## App Review information

| Field             | Value                                                             |
|-------------------|-------------------------------------------------------------------|
| Demo account      | Not required (no login)                                           |
| Review notes      | "The app is iPad-only. To review the photo feature (if present), use the camera or the Photos library picker from the Home tab." |
| Attachment        | None required                                                     |
