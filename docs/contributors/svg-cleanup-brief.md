# ColorFlow SVG Cleanup Brief

This document is for contractors or contributors who receive flagged SVG files
from the ColorFlow template pipeline and need to fix them in Inkscape before
they can be shipped in the app.

**You do not need to write any code.** Your job is to open a flagged SVG in
Inkscape, apply one or more fixes, save, and verify the file passes the
validator. That's it.

---

## What you need

| Tool | Version | Install |
|------|---------|---------|
| Inkscape | 1.x | [inkscape.org](https://inkscape.org) |
| Python | 3.11+ | pre-installed on macOS/Linux |
| lxml | latest | `pip3 install lxml` |

Verify your setup:

```bash
inkscape --version                                      # 1.x.x
python3 Scripts/validate_template_svg.py --help        # prints usage
```

---

## Workflow

1. Run the cleanup queue script to see which files need work:

   ```bash
   python3 Scripts/pipeline/05_cleanup_queue.py \
       --input   pipeline_work/03_postprocessed/ \
       --pass    pipeline_work/04_pass/ \
       --cleanup pipeline_work/04_needs_cleanup/
   ```

   Files in `pipeline_work/04_needs_cleanup/` are your assignment.

2. Validate a single file to read its specific errors:

   ```bash
   python3 Scripts/validate_template_svg.py pipeline_work/04_needs_cleanup/my_file.svg
   ```

   You'll see output like:

   ```
   ✗ FAIL  my_file.svg
     [ERROR] unclosed-path: id='region-3' path data does not end with Z
     [WARNING] file-size: 215 KB exceeds soft limit of 200 KB
   ```

3. Fix the errors in Inkscape (see Common Fixes below).

4. Save the fixed SVG and validate again:

   ```bash
   python3 Scripts/validate_template_svg.py pipeline_work/04_needs_cleanup/my_file.svg
   ```

   Expected: `✓ PASS`

5. Copy the fixed file back to `pipeline_work/03_postprocessed/` and re-run
   the queue script. It will now route it to `04_pass/`.

6. Submit the fixed file and the validator output to the project lead.

---

## What makes a valid ColorFlow SVG

ColorFlow is a coloring-book app. The SVG is the line art that the user colors
in. The app's parser is strict — it only supports a safe subset of SVG.

**Key rules:**

| Rule | Why |
|------|-----|
| `viewBox` attribute required on `<svg>` | Parser fails without it |
| Named regions must use `id="region-N"` or any descriptive id | Allows tap-to-fill |
| Every **named** region path must end with `Z` | Closes the shape for flood-fill |
| No arc commands (`A` or `a`) in path data | Parser only supports cubic beziers |
| No `<filter>`, `<mask>`, `<clipPath>`, `<use>`, `<image>`, `<style>`, gradient elements | Parser rejects them |
| No `stroke-dasharray` or `opacity` attributes | Forbidden attributes |
| Only `translate(x, y)` transforms on `<g>` elements | Other transforms break coordinates |
| File size < 500 KB (hard), < 200 KB recommended | App bundle size |
| Path count < 500 (hard), < 300 recommended | Rendering performance |

See `docs/svg-template-spec.md` for the full specification.

**Reference file:** `docs/contributors/sample_reference.svg` is a clean,
passing example you can open in Inkscape to understand the expected structure.

---

## Common Fixes

### Fix 1: Unclosed path (`unclosed-path` error)

**Error message:** `id='region-3' path data does not end with Z`

**What happened:** The path is an open contour — the last point doesn't
connect back to the first. The app can't flood-fill an open shape.

**Fix in Inkscape:**

1. Open the SVG in Inkscape.
2. Switch to the Node editor tool (press **N**).
3. Click the path that the error names (check the id in the XML editor
   **Edit → XML editor**, or **Ctrl+Shift+X**).
4. If the path is visually a closed shape, select the start node, then
   Shift-click the end node, then **Path → Join Nodes** (or press **Shift+J**).
5. If it's genuinely open (like a stroke), add a short closing segment
   manually or delete the id so it becomes a decorative path.
6. Save (Inkscape's "Plain SVG" format, not Inkscape SVG — see Save section).

**Quick check:** In the XML editor, look at the `d=` attribute of the path.
It must end with `Z` (or `z`). If it doesn't, you can also edit it directly:
click the `d` value in the XML editor and append ` Z` at the end.

---

### Fix 2: Arc command (`arc-command` error)

**Error message:** `id='region-5' contains arc command (A/a)`

**What happened:** The path uses SVG arc commands (`A` or `a`). The app's
parser doesn't support arcs — only cubic Bézier curves (`C/c`), lines,
and standard move/close commands.

**Fix in Inkscape:**

1. Select the offending path.
2. Go to **Extensions → Modify Path → Flatten Beziers** and run with the
   default settings (or a flatness of 0.5–1.0 for smoother output).
3. This converts arcs to a series of short Bézier segments.
4. Validate again — if arcs remain, increase the flatness value.

Alternative (for circular shapes):

1. Select all objects: **Ctrl+A**.
2. **Path → Object to Path** to flatten any ellipse/circle primitives.
3. **Path → Break Apart**, then re-join if needed.

---

### Fix 3: Non-translate transform (`forbidden-transform` error)

**Error message:** `<g> has non-translate transform: rotate(45)`

**What happened:** A group element has a rotation, scale, or matrix
transform that the parser doesn't support. The post-processor tries to
bake these automatically but sometimes fails on nested groups.

**Fix in Inkscape:**

1. Select all objects: **Ctrl+A**.
2. **Edit → Select Same → Object Type → Groups** to select all groups.
3. **Object → Group → Ungroup** (**Ctrl+Shift+G**) — repeat until no groups remain.
4. Select all again: **Ctrl+A**.
5. **Object → Transform** → **Apply to Each Object** (check that option).
6. **File → Clean Up Document**.
7. Re-group only if required for organization, using plain `translate()` only.

---

### Fix 4: Too many paths (`path-count` warning / error)

**Warning:** `330 paths exceeds soft limit of 300`  
**Error:** `520 paths exceeds hard limit of 500`

**What happened:** VTracer generated too many tiny path segments, usually
from noise or overly detailed source art.

**Fix in Inkscape:**

1. **Path → Simplify** (**Ctrl+L**) — reduces node count across all paths.
   Run it once, check the path count by looking at the status bar.
2. If still over the limit, select small decorative paths and delete them.
   In the XML editor you can see if a path has an `id` (named region) or not.
   Delete unnamed decorative paths first — they don't affect fillability.
3. For overlapping thin strokes: select the stroke paths, then
   **Path → Union** (**Ctrl++**) to merge them.

---

### Fix 5: Forbidden element (`forbidden-element` error)

**Error message:** `contains forbidden element: <filter>`

**What happened:** Inkscape (or another tool) added a filter effect, mask,
or gradient that the parser rejects.

**Fix in Inkscape:**

1. **Edit → Find/Replace** (**Ctrl+F**), search for the element name (e.g., `filter`).
2. Select and delete the offending element from the XML editor.
3. Or: **File → Clean Up Document** removes unreferenced defs including filters.
4. If the filter was applied to a visible path, the path still exists —
   just remove the filter attribute (`filter="url(#...)"`) in the XML editor.

---

### Fix 6: Forbidden attribute (`forbidden-attr` error)

**Error message:** `path id='region-2' has forbidden attribute: stroke-dasharray`

**Fix in Inkscape:**

1. Select the path.
2. Open the XML editor (**Ctrl+Shift+X**).
3. Find the forbidden attribute (`stroke-dasharray` or `opacity`) and
   click the delete button (trash icon) next to it.

---

## Saving from Inkscape

**Always save as "Plain SVG"**, not "Inkscape SVG". Inkscape SVG adds
namespace extensions that can confuse the parser.

1. **File → Save a Copy…** (not Save As, which changes the working copy)
2. Format: **Plain SVG (\*.svg)**
3. Overwrite the file in `pipeline_work/04_needs_cleanup/`

---

## Submission checklist

Before sending back a fixed file, confirm:

- [ ] `python3 Scripts/validate_template_svg.py <file>` shows `✓ PASS`
- [ ] No errors remain (warnings are acceptable unless you can eliminate them)
- [ ] File size is under 200 KB (check: `ls -lh <file>`)
- [ ] The SVG still looks like the original art when opened in a browser
- [ ] You did not change any `id` attributes on existing named regions
- [ ] File was saved as **Plain SVG** (not Inkscape SVG)

---

## Questions?

If you encounter an error that isn't listed here or can't resolve an issue,
attach:
1. The failing SVG file
2. The full validator output (`python3 Scripts/validate_template_svg.py <file>`)
3. A screenshot of what it looks like in Inkscape

and send to the project lead for triage.
