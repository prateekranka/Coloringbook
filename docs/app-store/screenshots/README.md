# App Store Screenshots - Gouache

## Required iPad size

Apple's current App Store Connect screenshot specification requires iPad
screenshots when an app runs on iPad. For the 13-inch iPad display slot, App
Store Connect accepts PNG/JPEG/JPG screenshots in either of these portrait
sizes, plus the matching landscape sizes:

| App Store Connect slot | Accepted portrait size | Accepted landscape size | Requirement |
| --- | --- | --- | --- |
| 13-inch iPad display | 2064 x 2752 px | 2752 x 2064 px | Required for iPad apps |
| 13-inch iPad display | 2048 x 2732 px | 2732 x 2048 px | Also accepted |

Use one to ten screenshots. If the app UI is the same across iPad sizes, Apple
allows the highest-resolution required screenshots to scale down to smaller
device sizes. Custom 12.9-inch, 11-inch, 10.5-inch, and 9.7-inch sets can still
be added later through Media Manager, but they are not required for Gouache v1.

Reference:
- https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots

## Shot list - v1

Capture five portrait screenshots for the required 13-inch iPad slot. Plain
simulator screenshots are acceptable; marketing overlays are optional and should
not cover artwork or primary controls.

| File | Screen | Purpose |
| --- | --- | --- |
| `gouache_ipad_13in_01_home.png` | Home | First impression, featured collections, recent work surface. |
| `gouache_ipad_13in_02_library.png` | Library | Shows catalog breadth and category browsing. |
| `gouache_ipad_13in_03_canvas.png` | Canvas | Shows the coloring surface, line art, color tray, and tools. |
| `gouache_ipad_13in_04_profile.png` | Profile/My Work | Shows saved-work surface and local-only project model. |
| `gouache_ipad_13in_05_collection.png` | Collection | Shows template collection detail and card artwork. |

Do not include photo import, camera, or AI conversion shots in v1 screenshots;
those features are not reviewable in the shipping UI.

## Automated capture

Run the screenshot pipeline from the repository root:

```sh
Scripts/screenshots/capture.sh --output-dir docs/app-store/screenshots/generated
```

The pipeline reads `Scripts/screenshots/devices.json`, runs the screenshot UI
tests, and saves PNGs under `docs/app-store/screenshots/generated/iPad13/Portrait/`.

After capture, verify dimensions:

```sh
sips -g pixelWidth -g pixelHeight docs/app-store/screenshots/generated/iPad13/Portrait/*.png
```

Expected portrait dimensions for the default 13-inch simulator are
`2064 x 2752`. A `2048 x 2732` fallback from an accepted iPad Pro simulator is
also valid for the 13-inch iPad App Store Connect slot.

## Manual fallback

1. Build and run Gouache on an iPad Pro 13-inch simulator.
2. Navigate to each screen in the shot list.
3. Save the simulator screen with Command-S or:
   `xcrun simctl io booted screenshot screenshot.png`
4. Place PNG files in `docs/app-store/screenshots/generated/iPad13/Portrait/`
   using the naming convention above.
5. Confirm each image is only the device screen, with no simulator window frame.

## App preview video

An app preview is optional. If one is added later, use a 15-30 second H.264
`.mov`, `.m4v`, or `.mp4` showing: open a template, fill a few regions, switch
tools, draw with Apple Pencil, save, and export.
