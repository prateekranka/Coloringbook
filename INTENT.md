# ColorFlow Intent Draft

This document is a working statement of product intent inferred from the
current repo. It is meant to make the "why" obvious to future agents before
they start editing code.

It separates what is known from code and docs, what is a strong inference, and
what still needs a human answer.

## One-Sentence Intent

ColorFlow is an iPad-only, coloring studio that turns curated SVG
line art, and eventually user photos, into calm, premium coloring sessions built
around Apple Pencil, tap-to-fill regions, local persistence, and a highly
designed visual catalog.

## What Is Certain

These points are directly supported by the app source, project settings, tests,
or committed docs.

- The product is a native SwiftUI iPad app. `project.yml` targets iOS/iPadOS
  18.0 today and sets `TARGETED_DEVICE_FAMILY: "2"`, so iPhone and Mac Catalyst
  are not part of the current product surface.
- The repo identity is still ColorFlow at the module/project level:
  `ColorFlowApp`, `ColorFlow.xcodeproj`, `ColorFlow/`, test targets, and app
  store docs all use ColorFlow in many internal places.
- The visible app brand is not fully settled in the tree. The home hero says
  `SABLE`, `Info.plist` currently displays `Gouache`, and older docs describe
  `ColorFlow`. A 2026-04-17 v1 plan says "Rebrand to Sable" was a locked v1
  scope decision, but the code has not converged on one public name.
- The app's primary surface is a three-tab shell: Home, Explore, and My Library.
  Home emphasizes recent work, featured collections, and moods. Explore lists
  templates. My Library lists saved projects.
- The current implemented canvas is centered on tap-to-fill. A user selects a
  palette and swatch, taps a fillable SVG region, sees progress update, can
  undo/redo fills, clear artwork, zoom/pan the canvas, and save.
- SVG templates are the main content format. The app parses SVGs into strict
  `TemplateGeometry` made of fillable `RegionGeometry` objects and decorative
  paths. Region IDs are the durable bridge between line art and saved color.
- The SVG parser is intentionally narrow. It requires a viewBox, rejects many
  complex SVG features, does not support arc commands, and supports only
  translate transforms. This is a product constraint, not an accident: template
  reliability and hit-testing matter more than arbitrary SVG compatibility.
- The catalog is bundled and flat at build time. `templates.json` is preferred,
  `Template.bundledTemplates` is a fallback, and SVG files are copied into the
  app bundle root by the XcodeGen pre-build script.
- Projects are local documents. A project records the template ID, completion,
  status, and paths for drawing data, fill layers, paint state, and thumbnails.
- Persistence is local and file-based. `StorageService` stores `projects.json`,
  per-project files, and `user_templates.json` under the app's Documents
  directory and serializes I/O through a private queue.
- Privacy is a core invariant. The privacy manifest, app-store privacy docs,
  and `PhotoPipelineService` comments all say the app should collect no data,
  avoid analytics/ads/crash SDKs, and process photos on device.
- The repo is being prepared for App Store submission. There are submission
  audits, privacy labels, listing copy, screenshot plans, icon plans, and
  release-log checks.
- The design system currently uses the Sable visual language: cream paper,
  black editorial cards, crimson/progress-pink accents, bold typography, 8px
  card radii, and mood/category accent colors.
- Accessibility and deterministic UI testing matter. Views expose explicit
  accessibility identifiers, and UI tests include persona-style flows and
  seeded project setup.
- The project is generated from `project.yml`. Agents should not hand-edit the
  generated Xcode project.
- `./dev` is the intended day-to-day build/test entrypoint, even though some
  older docs still mention raw `xcodebuild` or stale scripts.

## Strong Inferences

These are not always stated in one canonical place, but the code and docs point
strongly in this direction.

- The product wants to feel like a premium creative tool rather than a toy
  coloring app. The UI leans editorial and art-directed, the v1 plan discusses a
  $9.99 paid-up-front model, and the catalog/screenshots/icon plans are framed
  around App Store polish.
- "Distraction-free" means no accounts, no social feed, no telemetry, no remote
  config, no network-dependent catalog, and no server-side photo processing.
  The app should feel self-contained on the iPad.
- Apple Pencil is important to the desired identity, but the current visible
  canvas implementation is ahead on tap-to-fill and behind the older PencilKit
  ambitions. `StorageService`, tests, and docs still reference PencilKit
  drawing data, while `ColoringCanvasView` currently renders fill and line-art
  images rather than an embedded `PKCanvasView`.
- The catalog is meant to be a major differentiator. The repo contains both a
  hand-authored bundled catalog and host-side template-production tooling for
  generating, validating, cleaning, and shipping more templates.
- The photo-to-template feature is strategically important, but its shipping
  status is ambiguous. Services and tests exist for the on-device pipeline, yet
  the committed v1 Sable plan demotes photo-to-template to v1.1 and the current
  main UI does not expose a photo import flow.
- "Stay in the lines" is a likely core UX promise. The architecture uses vector
  regions for hit-testing and clipping, and tests include canvas stay-in-lines
  support.
- The intended user may include adult colorists and creative iPad owners who
  want relaxing, polished sessions rather than gamified coloring. Mood browsing,
  premium App Store copy, and the absence of social mechanics all support this.
- The codebase is in a transitional phase: older ColorFlow/README/CLAUDE
  language, newer Sable UI, current Gouache display name, and Phase C photo
  work coexist. Future agents should avoid treating any single old doc as
  canonical without checking AGENTS.md, `project.yml`, and current source.

## Product Shape

The current product idea appears to have four pillars.

### 1. A Curated Coloring Catalog

Users browse templates by category, collection, and mood. Templates are not just
files; they are the app's content library and store value. The catalog spans
mandalas, animals, architecture, abstract patterns, botanicals, and lifestyle
scenes.

Agent implication: when adding templates, treat the SVG spec, manifest, parser
parity tests, and visual thumbnail quality as product-critical.

### 2. A Calm iPad Canvas

The canvas should make coloring feel direct. In the current implementation the
core action is: choose color -> tap enclosed region -> see it fill -> save or
undo. Zoom, pan, progress, and save state are visible but restrained.

Agent implication: preserve canvas clarity. Avoid adding chrome that competes
with the artwork unless it materially improves coloring.

### 3. Local Ownership and Privacy

Artwork, project state, user-generated templates, and thumbnails live locally.
Docs repeatedly say no accounts, no analytics, no tracking, and no network
requests during normal use.

Agent implication: before adding any SDK, network call, cloud sync, analytics,
remote config, crash reporting, or CDN asset load, treat it as a product-policy
change requiring explicit human approval and privacy doc updates.

### 4. On-Device Creation From Photos

The code includes an on-device photo pipeline with pre-validation, preprocessing,
segmentation, edge detection, contour vectorization, SVG assembly, parser parity
checks, and user-template persistence. This suggests the long-term product wants
users to create personal coloring pages without uploading photos.

Agent implication: any photo work must keep the output compatible with the same
strict SVG/template contract as bundled templates.

## Architecture As Product Intent

Several technical choices express product intent:

- Strict SVG parsing makes the canvas predictable and testable.
- Region IDs make fills durable across saves and reopens.
- Separate paint state keeps color data independent from source template
  geometry.
- Local JSON/file persistence keeps the app private and simple.
- Repository protocols make Home/Explore/Library testable and previewable.
- `@MainActor @Observable` view models match the SwiftUI Observation-era
  architecture and avoid legacy `ObservableObject` patterns.
- The template pipeline turns content production into a repeatable asset
  workflow, which matters if the app's value is catalog depth.

## Current User Journey

This is the journey implemented most clearly today:

1. The user opens the app into a branded Home tab.
2. They continue a saved project, choose a featured collection, browse by mood,
   or open Explore.
3. Selecting a template opens or creates a local project.
4. The canvas loads the SVG, parses it into fillable regions, renders line art
   and fills, and presents a fitted page on cream/paper UI.
5. The user chooses a palette and swatch.
6. The user taps regions to color them.
7. The app updates completion percentage and dirty/saved state.
8. The user can undo, redo, clear artwork, reset zoom, save, and return later
   through My Library or Continue.

## Things Agents Should Not Assume

- Do not assume the public product name is settled.
- Do not assume photo-to-template is shipping in the current release just
  because services exist.
- Do not assume PencilKit freehand drawing is fully wired into the current
  canvas just because persistence and older docs mention it.
- Do not assume README.md is current. It describes older setup and feature
  state.
- Do not assume `CLAUDE.md` is more current than AGENTS.md for workflow.
- Do not add iPhone layouts, light-mode branching, remote services, or new
  dependencies without explicit direction.

## Open Questions For Prateek

Please answer these so this document can become authoritative instead of a
well-researched draft.

1. What is the intended public app name right now: ColorFlow, Sable, Gouache, or
   something else?

   Answer:

2. Should root-level/internal code identifiers eventually be renamed to match
   the public brand, or should `ColorFlow` remain the internal module/repo name?

   Answer:

3. Is Apple Pencil required for v1, strongly recommended, or optional? The v1
   plan says required, while current tap-to-fill works without Pencil.

   Answer:

4. For the current release, is the canvas supposed to support freehand
   PencilKit drawing, or is region tap-to-fill the intended v1 core?

   Answer:

5. Is photo-to-template in scope for v1, v1.1, or just exploratory for now?
   The code contains the pipeline, but the Sable v1 plan demotes it.

   Answer:

6. Is the paid-up-front $9.99 positioning still correct?

   Answer:

7. Who is the primary user in your head: adult coloring users, kids/families,
   artists with Apple Pencil, casual relaxers, or another group?

   Answer:

8. What should the emotional tone be: premium art studio, cozy relaxation app,
   playful coloring book, serious creative tool, or a mix?

   Answer:

9. Are mood categories meant to be durable product taxonomy, or are they a
   temporary design device for the current Home screen?

   Answer:

10. Should the app remain strictly offline forever, or are specific future
    network features acceptable, such as template downloads, iCloud sync, or
    crash reporting?

    Answer:

11. Is iPadOS 18.0 the true minimum target now, or should docs that say iPadOS
    17+ still be honored?

    Answer:

12. Are all bundled templates intended to be original app-owned artwork, and
    should agents treat third-party/public-domain template sourcing as
    forbidden unless you explicitly approve it?

    Answer:

13. What should an agent optimize for when tradeoffs appear: App Store
    submission speed, visual polish, catalog depth, canvas fidelity, privacy, or
    maintainability?

    Answer:

14. What would make this app unmistakably "yours" if a competitor copied the
    basic feature list?

    Answer:

## Suggested Canonical Intent After Answers

Once the questions above are answered, condense this file into a short
authoritative statement with:

- Public brand and internal naming policy.
- Target user and emotional promise.
- v1 scope and explicit non-goals.
- Privacy and offline policy.
- Canvas interaction model.
- Catalog/template policy.
- Build/test workflow pointer to AGENTS.md.

