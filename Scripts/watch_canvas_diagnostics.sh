#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BUNDLE_ID="${COLORFLOW_BUNDLE_ID:-com.duckuwucky.sable}"
ARTIFACT_DIR="${COLORFLOW_LOG_DIR:-artifacts/canvas-diagnostics}"
mkdir -p "$ARTIFACT_DIR"
mode="watch"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test|--canvas-test|--scribble-test)
            mode="scribble-test"
            shift
            ;;
        -h|--help)
            cat <<'EOF'
Usage:
  ./dev watch-canvas
  ./dev watch-canvas --test

--test runs the same real-device watcher, prints the clean/free multi-tool
Pencil checklist, and analyzes the captured log when you press Ctrl-C.
EOF
            exit 0
            ;;
        *)
            echo "Unknown watch-canvas option: $1" >&2
            exit 2
            ;;
    esac
done

resolve_device() {
    if [[ -n "${COLORFLOW_DEVICE:-}" ]]; then
        printf "%s" "$COLORFLOW_DEVICE"
        return
    fi

    local json_file
    json_file="$(mktemp)"
    xcrun devicectl list devices --json-output "$json_file" >/dev/null
    /usr/bin/python3 - "$json_file" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    devices = json.load(handle)["result"]["devices"]

for device in devices:
    hardware = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    if hardware.get("reality") != "physical":
        continue
    if hardware.get("deviceType") != "iPad":
        continue
    if connection.get("tunnelState") == "unavailable":
        continue
    print(device["identifier"])
    sys.exit(0)

sys.exit(1)
PY
    rm -f "$json_file"
}

device="$(resolve_device)" || {
    echo "No available paired physical iPad found. Connect/unlock the iPad, then retry." >&2
    exit 1
}

apps_json="$(mktemp)"
apps_error="$(mktemp)"
if ! xcrun devicectl device info apps --device "$device" --bundle-id "$BUNDLE_ID" --json-output "$apps_json" >"$apps_error" 2>&1; then
    if grep -Eqi "device is locked|DeviceLocked|kAMDMobileImageMounterDeviceLocked" "$apps_error"; then
        echo "The iPad is locked. Unlock it, leave it awake, then run './dev watch-canvas' again." >&2
    else
        cat "$apps_error" >&2
        echo "Could not query installed apps on device '$device'." >&2
    fi
    rm -f "$apps_json"
    rm -f "$apps_error"
    exit 1
fi
rm -f "$apps_error"

if ! /usr/bin/python3 - "$apps_json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    result = json.load(handle).get("result", {})

apps = result.get("apps") or result.get("appInstallationList") or []
sys.exit(0 if apps else 1)
PY
then
    rm -f "$apps_json"
    echo "Gouache is not installed on '$device' for bundle '$BUNDLE_ID'." >&2
    echo "Install a Debug build from Xcode, then run './dev watch-canvas' again." >&2
    exit 1
fi
rm -f "$apps_json"

timestamp="$(date -u +"%Y%m%d-%H%M%S")"
log_file="$ARTIFACT_DIR/canvas-diagnostics-$timestamp.log"

echo "[watch-canvas] Device: $device"
echo "[watch-canvas] Bundle: $BUNDLE_ID"
echo "[watch-canvas] Log file: $log_file"
echo "[watch-canvas] Launching with GOUACHE_CANVAS_DIAGNOSTICS=1."
echo "[watch-canvas] Waiting for canvas-diagnostics.log from the app data container."
if [[ "$mode" == "scribble-test" ]]; then
    cat <<'EOF'
[watch-canvas] Guided jitter test:
[watch-canvas]   Clean mode:
[watch-canvas]     1. Fill Bucket: tap at least 2 regions.
[watch-canvas]     2. Crayon: draw at least 3 quick scribbly strokes in succession.
[watch-canvas]     3. Colored Pencil: draw at least 3 quick scribbly strokes in succession.
[watch-canvas]     4. Watercolor: draw at least 3 quick scribbly strokes in succession.
[watch-canvas]     5. Eraser: draw at least 3 quick scribbly strokes in succession.
[watch-canvas]   Free mode:
[watch-canvas]     1. Fill Bucket: tap at least 1 region.
[watch-canvas]     2. Crayon, Colored Pencil, Watercolor, Eraser:
[watch-canvas]        draw multiple quick scribbly strokes with each tool.
[watch-canvas] Press Ctrl-C when done; analysis will run automatically.
EOF
else
    echo "[watch-canvas] Tell Codex before you start coloring; press Ctrl-C when done."
    echo "[watch-canvas] After stopping, run: Scripts/analyze_canvas_diagnostics.py $log_file"
fi

launch_error="$(mktemp)"
if ! xcrun devicectl device process launch \
    --device "$device" \
    --terminate-existing \
    --environment-variables '{"GOUACHE_CANVAS_DIAGNOSTICS":"1","GOUACHE_CANVAS_DIAGNOSTICS_PENCIL_MOVEMENT":"1","GOUACHE_CANVAS_DIAGNOSTICS_LOG_EVERY_SAMPLE":"1"}' \
    "$BUNDLE_ID" \
    --gouache-canvas-diagnostics >"$launch_error" 2>&1; then
    if grep -Eqi "device is locked|DeviceLocked|kAMDMobileImageMounterDeviceLocked" "$launch_error"; then
        echo "The iPad is locked. Unlock it, leave it awake, then run './dev watch-canvas' again." >&2
    else
        cat "$launch_error" >&2
        echo "Could not launch '$BUNDLE_ID' on device '$device'." >&2
    fi
    rm -f "$launch_error"
    exit 1
fi
cat "$launch_error"
rm -f "$launch_error"

pull_dir="$(mktemp -d)"
snapshot_dir="$pull_dir/snapshot"
pulled_file="$snapshot_dir/canvas-diagnostics.log"
copy_error="$pull_dir/copy-error.log"
last_size=0
stopping=0

cleanup() {
    rm -rf "$pull_dir"
}
trap cleanup EXIT
trap 'stopping=1' INT TERM

while [[ "$stopping" -eq 0 ]]; do
    rm -rf "$snapshot_dir"
    mkdir -p "$snapshot_dir"
    rm -f "$copy_error"
    if xcrun devicectl device copy from \
        --device "$device" \
        --domain-type appDataContainer \
        --domain-identifier "$BUNDLE_ID" \
        --source "Documents" \
        --destination "$snapshot_dir" \
        --timeout 20 \
        --quiet >"$copy_error" 2>&1; then
        if [[ -f "$pulled_file" ]]; then
            size="$(wc -c < "$pulled_file" | tr -d '[:space:]')"
            if (( size < last_size )); then
                last_size=0
            fi
            if (( size > last_size )); then
                dd if="$pulled_file" bs=1 skip="$last_size" 2>/dev/null | tee -a "$log_file"
                last_size="$size"
            fi
        fi
    elif grep -Eqi "device is locked|DeviceLocked|kAMDMobileImageMounterDeviceLocked" "$copy_error"; then
        echo "The iPad locked while watching. Unlock it to continue receiving diagnostics." >&2
    fi
    sleep 1
done

if [[ "$mode" == "scribble-test" ]]; then
    echo "[watch-canvas] Analyzing guided jitter test..."
    Scripts/analyze_canvas_diagnostics.py --scenario scribble-matrix "$log_file"
fi
