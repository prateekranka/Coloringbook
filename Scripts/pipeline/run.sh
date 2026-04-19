#!/usr/bin/env bash
# ColorFlow template pipeline — end-to-end runner.
#
# Takes a directory of AI-generated PNG rasters and produces validated SVG
# templates + updated templates.json in one command.
#
# Usage:
#   Scripts/pipeline/run.sh --rasters pipeline_work/01_rasters
#
#   # Dry run (prints manifest diff without writing to Resources/):
#   Scripts/pipeline/run.sh --rasters pipeline_work/01_rasters --dry-run
#
#   # Strict mode (also copies validator-failing SVGs to cleanup/ for Inkscape):
#   Scripts/pipeline/run.sh --rasters pipeline_work/01_rasters --strict
#
#   # Use a custom working directory:
#   Scripts/pipeline/run.sh --rasters rasters/ --work /tmp/pipeline_run
#
# Stages (mirrors Scripts/pipeline/README.md):
#   [2] 02_vectorize.py       PNG → raw SVG via VTracer
#   [3] 03_postprocess.py     fix transforms, IDs, close paths
#   [5] 05_cleanup_queue.py   split into pass/ vs cleanup/
#   [4] 04_manifest_update.py regenerate templates.json
#   [6] Move passing SVGs to ColorFlow/Resources/Templates/
#
# On any failure, the script stops and prints which stage failed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ── Defaults ─────────────────────────────────────────────────────────────────
RASTERS=""
WORK=""
DRY_RUN=false
STRICT=false
SKIP_COMMIT=true   # we never auto-commit; operator reviews first

# ── Arg parsing ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rasters)   RASTERS="$2"; shift 2 ;;
        --work)      WORK="$2";    shift 2 ;;
        --dry-run)   DRY_RUN=true;  shift ;;
        --strict)    STRICT=true;   shift ;;
        -h|--help)
            sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown flag: $1" >&2; exit 2 ;;
    esac
done

[[ -n "$RASTERS" ]] || { echo "ERROR: --rasters <dir> is required" >&2; exit 2; }
[[ -d "$RASTERS" ]] || { echo "ERROR: rasters dir not found: $RASTERS" >&2; exit 2; }

WORK="${WORK:-pipeline_work}"
mkdir -p "$WORK"

RAW="$WORK/02_raw"
POST="$WORK/03_postprocessed"
PASS="$WORK/04_pass"
CLEANUP="$WORK/04_cleanup"

TEMPLATES_DIR="ColorFlow/Resources/Templates"
MANIFEST="ColorFlow/Resources/templates.json"
PROMPTS="Scripts/pipeline/01_prompt_set.yaml"

# ── Helpers ──────────────────────────────────────────────────────────────────
banner() { printf "\n\033[1;35m━━━ %s ━━━\033[0m\n" "$*"; }
info()   { printf "\033[1;34m[pipeline]\033[0m %s\n" "$*"; }
ok()     { printf "\033[1;32m[pipeline]\033[0m %s\n" "$*"; }
fail()   { printf "\033[1;31m[pipeline]\033[0m %s\n" "$*" >&2; exit 1; }

require() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 not found on PATH. See Scripts/pipeline/README.md."
}
require python3
require vtracer

# ── Stage 2: vectorize ───────────────────────────────────────────────────────
banner "Stage 2/5 — VTracer: PNG → SVG"
mkdir -p "$RAW"
python3 Scripts/pipeline/02_vectorize.py \
    --input  "$RASTERS" \
    --output "$RAW"
ok "Wrote raw SVGs → $RAW"

# ── Stage 3: post-process ────────────────────────────────────────────────────
banner "Stage 3/5 — Post-process (transforms, IDs, close paths)"
mkdir -p "$POST"
python3 Scripts/pipeline/03_postprocess.py \
    --input  "$RAW" \
    --output "$POST"
ok "Wrote post-processed SVGs → $POST"

# ── Stage 4: split into pass/cleanup via validator ───────────────────────────
banner "Stage 4/5 — Validate + split (pass vs cleanup)"
mkdir -p "$PASS" "$CLEANUP"
strict_flag=""
$STRICT && strict_flag="--strict"
python3 Scripts/pipeline/05_cleanup_queue.py \
    --input   "$POST" \
    --pass    "$PASS" \
    --cleanup "$CLEANUP" \
    $strict_flag

pass_count=$(find "$PASS" -maxdepth 1 -name '*.svg' | wc -l | tr -d ' ')
cleanup_count=$(find "$CLEANUP" -maxdepth 1 -name '*.svg' | wc -l | tr -d ' ')
ok "Passing: $pass_count   Need cleanup: $cleanup_count"

[[ "$pass_count" -gt 0 ]] || fail "Zero SVGs passed validation — nothing to do."

if [[ "$cleanup_count" -gt 0 ]]; then
    info "Cleanup queue at $CLEANUP — open these in Inkscape, fix, re-run."
fi

# ── Stage 5: manifest regeneration ───────────────────────────────────────────
banner "Stage 5/5 — Regenerate templates.json"
dry_flag=""
$DRY_RUN && dry_flag="--dry-run"
python3 Scripts/pipeline/04_manifest_update.py \
    --svgs     "$PASS" \
    --prompts  "$PROMPTS" \
    --existing "$MANIFEST" \
    --output   "$MANIFEST" \
    $dry_flag

if $DRY_RUN; then
    ok "Dry run complete — no files written. Review output above."
    exit 0
fi

# ── Install SVGs into the app bundle source tree ─────────────────────────────
banner "Installing passing SVGs → $TEMPLATES_DIR"
mkdir -p "$TEMPLATES_DIR"
cp "$PASS"/*.svg "$TEMPLATES_DIR/"

# Final validation — belt-and-braces check against what's now in the tree.
info "Re-validating installed templates…"
python3 Scripts/validate_template_svg.py "$TEMPLATES_DIR/" --quiet \
    || fail "Post-install validation failed. Revert templates/ before committing."

ok "All done."
cat <<EOF

Next steps:
  1. Regenerate Xcode project:   ./dev gen
  2. Build + smoke test:         ./dev test
  3. Review diff:                git diff $TEMPLATES_DIR $MANIFEST
  4. Commit when satisfied.
EOF
