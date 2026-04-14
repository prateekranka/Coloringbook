# ColorFlow SVG Template Specification

Version 1.0 — 2026-04-14

This document is the authoritative contract for all SVG files shipped in
`ColorFlow/Resources/Templates/` and for SVGs produced by the on-device
photo pipeline (Phase C). The Python validator (`Scripts/validate_template_svg.py`)
and the Swift parity test (`ColorFlowTests/SVGCatalogParityTests.swift`) both
enforce this spec. A file that passes both is guaranteed to render correctly
in the canvas.

**Source of truth is `SVGParser.swift`.** This document describes what the
parser accepts; it does not define an independent contract. If the parser
and this document disagree, the parser wins — update the document.

---

## 1. File requirements

| Rule | Detail |
|------|--------|
| **File extension** | `.svg` |
| **Encoding** | UTF-8. No BOM. |
| **File size** | < 500 KB per file. Files larger than this cause perceptible parse lag on older iPad hardware. |
| **Root element** | `<svg>` with a `viewBox` attribute (see §3). |
| **XML validity** | Well-formed XML. All tags closed, all attribute values quoted. |

---

## 2. Allowed elements

Only the following SVG elements may appear anywhere in the document:

| Element | Notes |
|---------|-------|
| `<svg>` | Root element only. |
| `<g>` | Group element. May carry a `transform` attribute (see §5). |
| `<path>` | Primary drawing primitive. See §4 for path data rules. |
| `<circle>` | Converted to an ellipse path by the parser. |
| `<ellipse>` | Converted to an ellipse path by the parser. |
| `<rect>` | Rounded or plain rectangles. `rx`/`ry` are supported. |
| `<polygon>` | Converted to a closed polyline path. |
| `<defs>` | Allowed as an empty container for compatibility with Inkscape export. Must not define any of the rejected elements below. |
| `<title>` | Allowed (informational; ignored by parser). |
| `<desc>` | Allowed (informational; ignored by parser). |
| `<metadata>` | Allowed (informational; ignored by parser). |

### Rejected elements (immediate parse failure)

| Element | Reason |
|---------|--------|
| `<filter>` | Blur/drop-shadow filters are not composited in the canvas. |
| `<mask>` | Mask compositing not supported. |
| `<clipPath>` | Clip-path compositing not supported. |
| `<use>` | Symbol reuse not resolved; produces incorrect hit-testing. |
| `<image>` | Raster embeds not supported; canvas is vector-only. |
| `<style>` | CSS styles not applied; all styling must be inline or omitted. |
| `<linearGradient>` | Canvas uses solid flood-fills; gradients not composited. |
| `<radialGradient>` | Same as above. |

### Rejected attributes (immediate parse failure on any element)

| Attribute | Reason |
|-----------|--------|
| `stroke-dasharray` | Dashed strokes not supported in canvas compositing. |
| `opacity` | Element-level opacity not applied; use `fill-opacity` only if needed. |

---

## 3. viewBox

The `<svg>` root element **must** have a `viewBox` attribute with exactly
four space- or comma-separated numbers: `min-x min-y width height`.

- `width` and `height` must both be > 0.
- Typical values: `0 0 800 800` or `0 0 1000 1000`.
- The canvas scales the viewBox to fit the device screen; the absolute
  dimensions are arbitrary as long as paths are authored in the same space.

```xml
<!-- valid -->
<svg viewBox="0 0 800 800" xmlns="http://www.w3.org/2000/svg">

<!-- invalid — no viewBox -->
<svg width="800" height="800" xmlns="http://www.w3.org/2000/svg">
```

---

## 4. Path data rules

### 4.1 Supported commands

| Command | Name | Notes |
|---------|------|-------|
| `M / m` | Move to | Required as first command. |
| `L / l` | Line to | |
| `H / h` | Horizontal line | |
| `V / v` | Vertical line | |
| `C / c` | Cubic Bézier | Three control-point form. |
| `S / s` | Smooth cubic Bézier | Smooth form; control point reflected. |
| `Q / q` | Quadratic Bézier | |
| `T / t` | Smooth quadratic Bézier | |
| `Z / z` | Close path | **Required** at the end of every fillable subpath (see §4.2). |

### 4.2 Closed contours (Z required)

Every `<path>` that defines a fillable region **must** end with a `Z` or `z`
close-path command. Open paths are accepted syntactically but will not
flood-fill correctly and may produce visual gaps.

Validator rule: a `<path>` element with an `id` attribute (i.e. a named,
fillable region) must end with `Z` in its `d` data (after stripping
trailing whitespace). Decorative paths (no `id`) should also be closed but
are not enforced by the validator.

### 4.3 Arc commands forbidden

The `A` and `a` commands (elliptical arc) are **not supported** and will
cause an immediate parse failure. The error message is:
> "Arc commands (A/a) are not supported in path data. Convert arcs to
> cubic bezier curves."

**Fix:** In Inkscape, use *Path → Object to Path* then *Extensions → Modify
Path → Flatten Beziers* (or the built-in arc-to-bezier conversion). In the
catalog pipeline, VTracer in spline mode produces only cubic Béziers.

### 4.4 Path count

A single SVG file should contain **no more than 300 paths** (regions +
decorative paths combined). Above this threshold, initial render and
hit-testing may produce perceptible lag on iPad (10th gen, A14 chip).

The validator emits a **warning** (not a failure) when path count exceeds
300. Files with > 500 paths will **fail**.

---

## 5. Transforms

Only `translate(x)` and `translate(x, y)` are supported on `<g>` elements.

The following transform functions cause an immediate parse failure:

| Forbidden transform | Common origin |
|---------------------|---------------|
| `matrix(...)` | Inkscape "Apply Transforms" not run |
| `rotate(...)` | Rotation not pre-baked |
| `scale(...)` | Scaling not pre-baked |
| `skewX(...)` | Skew not pre-baked |
| `skewY(...)` | Skew not pre-baked |

**Fix:** In Inkscape, select all objects and use *Object → Transform → Apply
to each object* then *File → Clean up document* to pre-bake non-translate
transforms. In the catalog pipeline, the `03_postprocess.py` script
automatically pre-bakes these.

Transforms on individual shape elements (`<path>`, `<circle>`, etc.) are
not applied by the parser. All non-translate transforms must be pre-baked
into path coordinates before the file is committed.

---

## 6. Region ID convention

Fillable regions must carry an `id` attribute. The convention is:

```
id="region-N"
```

where `N` is a zero-padded integer (`region-0`, `region-1`, … `region-042`).

The flood-fill tap-to-fill code uses these IDs to track which region the
user has filled. If two regions share the same `id`, only the first will
be fillable; the second is silently treated as decorative.

Decorative paths (outlines, grid lines, borders) should have **no** `id`
attribute so the parser routes them to `decorativePaths` rather than
`regions`.

---

## 7. Styling attributes

The parser ignores most styling attributes (`fill`, `stroke`, `stroke-width`,
`fill-opacity`) — they are not composited. The canvas supplies its own fill
colors at runtime. Do not rely on embedded color values being visible to
the user.

**Permitted:** `fill-rule` (`nonzero` or `evenodd`) on any shape element.
This affects the CGPath fill rule used for hit-testing and flood-fill.

**Forbidden:** `opacity` on any element (causes parse failure). Use
`fill-opacity` on individual shapes if transparency is needed.

---

## 8. File size and complexity targets

| Metric | Soft limit (warning) | Hard limit (failure) |
|--------|---------------------|----------------------|
| File size | 200 KB | 500 KB |
| Path count | 150 paths | 500 paths |
| Path data length per path | 2,000 chars | 10,000 chars |

These limits exist to keep memory pressure predictable on the range of
supported hardware (iPad 10th gen, A14, 4 GB RAM).

---

## 9. Validation workflow

### Python (host-side catalog)

```bash
cd ColorFlow   # repo root
python3 Scripts/validate_template_svg.py ColorFlow/Resources/Templates/
```

Exits 0 if all files pass, 1 if any fail. Suitable for pre-commit hooks
and CI.

### Swift (device-side parity)

The `SVGCatalogParityTests` test target runs every SVG in
`Resources/Templates/` through `SVGParser.parse(url:)` and asserts
`.success`. This runs as part of the normal `xcodebuild test` pass.

Both validators must pass before any SVG is committed to the repo.

---

## 10. Quick checklist for new templates

Before committing a new SVG to `Resources/Templates/`:

- [ ] File is UTF-8, < 500 KB
- [ ] Root `<svg>` has `viewBox`
- [ ] No `<filter>`, `<mask>`, `<clipPath>`, `<use>`, `<image>`, `<style>`, `<linearGradient>`, `<radialGradient>`
- [ ] No `stroke-dasharray` or `opacity` attributes
- [ ] No `A`/`a` arc commands in any `<path d="...">`
- [ ] All fillable regions have `id="region-N"` and end with `Z`
- [ ] All `<g>` transforms are `translate(x, y)` only (or no transform)
- [ ] Non-translate transforms have been pre-baked into path coordinates
- [ ] Path count ≤ 300 (ideally ≤ 150)
- [ ] `validate_template_svg.py` passes
- [ ] `SVGCatalogParityTests` passes with the file in place
- [ ] `templates.json` updated
- [ ] `Template.bundledTemplates` fallback array updated
