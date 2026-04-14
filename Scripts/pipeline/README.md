# ColorFlow Template Catalog Pipeline — Operator Runbook

This directory contains the host-side Python pipeline that takes AI-generated
raster images and produces parser-compliant SVG templates for the ColorFlow app.

The pipeline does **not** run on-device and is never bundled into the app binary.
Outputs (validated SVGs + updated `templates.json`) are committed to the repo and
shipped in the app bundle.

---

## Prerequisites

### Software

| Tool | Version | Install |
|------|---------|---------|
| Python | 3.11+ | `brew install python` |
| VTracer | latest | `cargo install vtracer` or download binary from [visioncortex/vtracer/releases](https://github.com/visioncortex/vtracer/releases) |
| Rust + Cargo | for VTracer build | `curl https://sh.rustup.rs | sh` |

### Python packages

```bash
cd <repo root>
pip install -r Scripts/requirements.txt
```

### Verify

```bash
python3 --version               # 3.11+
vtracer --version               # any recent version
python3 -c "import lxml; print('lxml OK')"
python3 -c "import yaml; print('yaml OK')"
```

---

## Pipeline overview

```
[Step 0]  Generate raster images with AI (manual / external tool)
    ↓
[Step 1]  01_prompt_set.yaml   — define categories, names, prompts
    ↓
[Step 2]  02_vectorize.py      — raster PNG → raw SVG via VTracer
    ↓
[Step 3]  03_postprocess.py    — fix transforms, assign IDs, close paths
    ↓
[Step 4]  validate_template_svg.py — verify every SVG passes the spec
    ↓
[Step 5]  04_manifest_update.py — regenerate templates.json + Swift snippet
    ↓
[Step 6]  Move SVGs to ColorFlow/Resources/Templates/ + commit
```

---

## Step-by-step instructions

### Step 0: Generate raster images

Use an image generation tool of your choice (SDXL, Flux, Midjourney, etc.)
with the prompts from `01_prompt_set.yaml`. The `style_prefix` and
`negative_prompt` fields in the YAML are starting points — tune them for
your specific model.

**Target settings:**
- Resolution: 1024×1024 or larger
- Format: PNG (lossless, no JPEG compression artifacts)
- Style: black-and-white coloring-book line art (no fills, no color)
- Background: white

Save all raster images to a working directory, e.g.:

```
pipeline_work/
└── 01_rasters/
    ├── sunflower_mandala.png
    ├── fox_portrait.png
    └── ...
```

The filename stem should match the `name` field in `01_prompt_set.yaml`
so the manifest updater can look up display names and difficulties.

---

### Step 1: Review the prompt set

```bash
cat Scripts/pipeline/01_prompt_set.yaml
```

The YAML lists 60 prompts across 7 categories. Edit as needed for your
specific model or style preferences. The `metadata.target_count` field is
informational; it doesn't affect pipeline behavior.

---

### Step 2: Vectorize

```bash
python3 Scripts/pipeline/02_vectorize.py \
    --input  pipeline_work/01_rasters/ \
    --output pipeline_work/02_vectors/
```

This runs VTracer on every PNG in the input directory. Default VTracer
settings are tuned for coloring-book line art:
- `--colormode binary` — pure black-and-white
- `--mode spline` — cubic Bézier output (no arc commands)
- `--hierarchical stacked` — one `<path>` per region

Each input image produces:
- `<stem>.svg` — the raw VTracer SVG
- `<stem>.vtracer.json` — path count, file size, timing metadata

Files that VTracer rejects produce `<stem>.error.txt` instead.

Files with > 300 paths produce `<stem>.review_needed.txt` — open these
in Inkscape and simplify before continuing (`Path → Simplify`).

**Expected yield:** ~85–90% success rate on clean coloring-book inputs.

---

### Step 3: Post-process

```bash
python3 Scripts/pipeline/03_postprocess.py \
    --input  pipeline_work/02_vectors/ \
    --output pipeline_work/03_postprocessed/
```

For each SVG, the post-processor:
1. Pre-bakes non-translate `<g>` transforms into path coordinates
2. Assigns `id="region-N"` to any unnamed `<path>`
3. Strips forbidden elements (`<filter>`, `<mask>`, etc.)
4. Strips forbidden attributes (`stroke-dasharray`, `opacity`)
5. Appends `Z` to named-region paths that don't end with `Z`
6. Synthesizes `viewBox` from `width`/`height` if missing
7. Runs the validator and writes an `error.txt` for anything it can't fix

**Files in `03_postprocessed/` with no `.error.txt` are ready for validation.**

---

### Step 4: Validate

```bash
python3 Scripts/validate_template_svg.py pipeline_work/03_postprocessed/
```

This is the definitive gate. All passing files are safe to commit.

Files with errors need manual cleanup in Inkscape. See the common fixes
section below.

**Run the cleanup queue script (Step B3) to split pass/fail:**

```bash
# (B3 script — see Scripts/pipeline/05_cleanup_queue.py)
python3 Scripts/pipeline/05_cleanup_queue.py \
    --input   pipeline_work/03_postprocessed/ \
    --pass    pipeline_work/04_pass/ \
    --cleanup pipeline_work/04_needs_cleanup/
```

---

### Step 5: Update the manifest

Once all SVGs in the `pass/` directory are validated:

```bash
python3 Scripts/pipeline/04_manifest_update.py \
    --svgs     pipeline_work/04_pass/ \
    --prompts  Scripts/pipeline/01_prompt_set.yaml \
    --existing ColorFlow/Resources/templates.json \
    --output   ColorFlow/Resources/templates.json
```

This rewrites `templates.json` with all passing SVGs. Existing template
UUIDs are never changed.

The script also prints the Swift code to paste into the `bundledTemplates`
array in `ColorFlow/Models/Template.swift`. Update that file too.

**⚠️ Critical:** Never change existing template UUIDs. They are load-bearing:
every user's saved projects reference templates by UUID. Changing a UUID
orphans those projects.

---

### Step 6: Commit

```bash
# Copy validated SVGs to the app's Resources directory
cp pipeline_work/04_pass/*.svg ColorFlow/Resources/Templates/

# Re-run the validator on the final destination as a sanity check
python3 Scripts/validate_template_svg.py ColorFlow/Resources/Templates/

# Regenerate Xcode project (SVG resources are copied by preBuildScript,
# but a new templates.json needs to be in the resources list)
xcodegen generate

# Stage and commit
git add ColorFlow/Resources/Templates/*.svg ColorFlow/Resources/templates.json ColorFlow/Models/Template.swift
git commit -m "feat(templates): add N new templates for v1 catalog"
```

After the commit, build and run on a simulator. Open the Library tab and
verify the new templates appear and render correctly.

---

## Common Inkscape fixes

### Open path (closes-path Z missing)

The post-processor adds `Z` automatically, but if a path is genuinely
not a closed shape, add it manually:

1. Open SVG in Inkscape
2. Switch to Node editor (N)
3. Select the open node, Shift+click the first node
4. Path → Close Path

### Non-translate transform

The post-processor pre-bakes these automatically. If it fails:

1. Select all objects (Ctrl+A)
2. Object → Transform → Apply to Each Object (check "Apply to each object separately")
3. Edit → Paste in Place, then File → Clean Up Document

### Arc command (A/a)

VTracer in spline mode should not produce arcs. If an arc appears, it
likely came from a manually-edited or non-VTracer SVG.

1. Open in Inkscape
2. Extensions → Generate from Path → Interpolate Sub-paths
   Or: Extensions → Modify Path → Flatten Beziers

### Too many paths (> 300)

1. Open in Inkscape
2. Path → Simplify (Ctrl+L) — reduces node count
3. If still over 300, manually delete small decorative paths or
   merge thin strokes into regions using Union (Ctrl++).

---

## Quality targets

| Metric | Target per v1 ship |
|--------|-------------------|
| Total templates | ≥ 50 (100 stretch) |
| Category coverage | All 6 app categories |
| Validator pass rate before Inkscape | ≥ 80% |
| After Inkscape cleanup | 100% |
| File size | < 200 KB each (hard limit 500 KB) |
| Path count | < 150 (hard limit 500) |

---

## Troubleshooting

**VTracer produces a blank SVG:**
The input image may be too dark or too light. Open in a photo editor and
increase contrast before re-running Step 2.

**post-processor fails with XML parse error:**
The raw VTracer SVG has a syntax error. Open in a text editor and look
for unmatched tags. Usually caused by VTracer crashing mid-write on a
corrupt input image.

**04_manifest_update.py produces duplicate names:**
Two SVG files have the same stem. Rename one before running the script.

**Swift parity test fails after committing:**
The on-device SVGParser rejected a file the Python validator passed.
Run `python3 Scripts/validate_template_svg.py ColorFlow/Resources/Templates/`
and look for warnings that became errors in the Swift parser. Common cause:
a path attribute (`stroke-dasharray`, `opacity`) was added after post-processing.
