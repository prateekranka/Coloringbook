#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT="ColorFlow.xcodeproj"
SCHEME="ColorFlow"
CLIP_DIR="${GOUACHE_PENCIL_HID_DIR:-artifacts/pencil-hid}"
LOG_DIR="${COLORFLOW_LOG_DIR:-artifacts/canvas-diagnostics}"
DERIVED_DATA="${GOUACHE_PENCIL_HID_DERIVED_DATA:-artifacts/pencil-hid/DerivedData}"
mkdir -p "$CLIP_DIR" "$LOG_DIR" "$DERIVED_DATA"

usage() {
    cat <<'EOF'
Usage:
  Scripts/run_pencil_hid_canvas_matrix_ipad.sh probe
  Scripts/run_pencil_hid_canvas_matrix_ipad.sh record fill-tap [seconds]
  Scripts/run_pencil_hid_canvas_matrix_ipad.sh record scribble [seconds]
  Scripts/run_pencil_hid_canvas_matrix_ipad.sh record outside-erase [seconds]
  Scripts/run_pencil_hid_canvas_matrix_ipad.sh replay fill-tap|scribble|outside-erase
  Scripts/run_pencil_hid_canvas_matrix_ipad.sh matrix

This uses private XCTest HID recording/replay on a paired physical iPad. Record
each clip once with a real Apple Pencil; matrix then replays those real Pencil
digitizer events across clean/free fill, paint, and eraser scenarios.
Run probe first. If the iPad reports that its remote interface does not support
HID event recording, there is no true-Pencil software replay path for that setup.
EOF
}

info() { printf "\033[1;34m[pencil-hid]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[pencil-hid]\033[0m %s\n" "$*" >&2; }
fail() { printf "\033[1;31m[pencil-hid]\033[0m %s\n" "$*" >&2; exit 1; }

resolve_device() {
    if [[ -n "${COLORFLOW_DEVICE:-}" ]]; then
        printf "%s" "$COLORFLOW_DEVICE"
        return
    fi

    local json_file
    json_file="$(mktemp)"
    xcrun devicectl list devices --json-output "$json_file" >/dev/null
    if /usr/bin/python3 - "$json_file" <<'PY'
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
    then
        rm -f "$json_file"
        return 0
    fi
    rm -f "$json_file"
    return 1
}

validate_clip() {
    case "${1:-}" in
        fill-tap|scribble|outside-erase) return 0 ;;
        *) fail "Unknown clip '${1:-}'. Expected fill-tap, scribble, or outside-erase." ;;
    esac
}

clip_file() {
    printf "%s/%s.hidrecording" "$CLIP_DIR" "$1"
}

clip_env_key() {
    printf "%s" "$1" | tr '[:lower:]-' '[:upper:]_'
}

clip_base64() {
    local file
    file="$(clip_file "$1")"
    [[ -s "$file" ]] || fail "Missing recording: $file. Run '$0 record $1' first."
    base64 < "$file" | tr -d '\n'
}

print_recording_instructions() {
    case "$1" in
        fill-tap)
            cat <<'EOF'
[pencil-hid] When the canvas is ready, use Apple Pencil to tap a fillable region
[pencil-hid] near the center. One or two quick Pencil taps is enough.
EOF
            ;;
        scribble)
            cat <<'EOF'
[pencil-hid] When recording starts, draw at least 3 quick Apple Pencil scribble
[pencil-hid] strokes near the center of the artwork. Keep them in roughly the
[pencil-hid] same area; matrix replay reuses this clip for each brush.
EOF
            ;;
        outside-erase)
            cat <<'EOF'
[pencil-hid] When recording starts, draw Apple Pencil eraser strokes that begin
[pencil-hid] outside the fillable artwork and cross into the central colored area.
[pencil-hid] Repeat 2-3 times so replay catches the outside-start eraser case.
EOF
            ;;
    esac
}

export_recording_attachment() {
    local result_bundle="$1"
    local clip="$2"
    local output_file
    output_file="$(clip_file "$clip")"

    local attachments_dir
    attachments_dir="$(mktemp -d)"
    xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$attachments_dir" >/dev/null

    local exported
    exported="$(/usr/bin/python3 - "$attachments_dir" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
files = [
    path for path in root.rglob("*")
    if path.is_file() and path.name != "manifest.json"
]
if not files:
    sys.exit(1)
files.sort(key=lambda path: path.stat().st_size, reverse=True)
print(files[0])
PY
)" || {
        rm -rf "$attachments_dir"
        fail "Could not find a HID recording attachment in $result_bundle."
    }

    cp "$exported" "$output_file"
    rm -rf "$attachments_dir"
    info "Saved $(basename "$output_file") ($(wc -c < "$output_file" | tr -d '[:space:]') bytes)."
}

run_xcode_test() {
    local device="$1"
    local mode="$2"
    local test_name="$3"
    shift 3

    local timestamp result_bundle xctestrun_source xctestrun_patched
    timestamp="$(date -u +"%Y%m%d-%H%M%S")"
    result_bundle="$CLIP_DIR/${mode}-${timestamp}.xcresult"
    xctestrun_patched="$DERIVED_DATA/Build/Products/PencilHID-${mode}-${timestamp}.xctestrun"
    rm -rf "$result_bundle"

    xcodebuild build-for-testing \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "platform=iOS,id=$device" \
        -derivedDataPath "$DERIVED_DATA" \
        -quiet >&2

    xctestrun_source="$(find "$DERIVED_DATA/Build/Products" -maxdepth 1 -name '*.xctestrun' -type f | head -n 1)"
    [[ -n "$xctestrun_source" ]] || fail "build-for-testing did not produce an .xctestrun file."
    cp "$xctestrun_source" "$xctestrun_patched"

    /usr/bin/python3 - "$xctestrun_patched" "$mode" "$@" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
mode = sys.argv[2]
extra_pairs = sys.argv[3:]

with path.open("rb") as handle:
    data = plistlib.load(handle)

ui_tests = data["ColorFlowUITests"]
environment = ui_tests.setdefault("TestingEnvironmentVariables", {})
environment["GOUACHE_PENCIL_HID_TEST"] = "1"
environment["GOUACHE_PENCIL_HID_MODE"] = mode
for pair in extra_pairs:
    key, value = pair.split("=", 1)
    environment[key] = value

with path.open("wb") as handle:
    plistlib.dump(data, handle)
PY

    local status=0
    xcodebuild test-without-building \
        -xctestrun "$xctestrun_patched" \
        -destination "platform=iOS,id=$device" \
        -only-testing:"ColorFlowUITests/PencilHIDReplayUITests/$test_name" \
        -resultBundlePath "$result_bundle" >&2 || status=$?

    printf "%s" "$result_bundle"
    return "$status"
}

pull_canvas_log() {
    local device="$1"
    local session_id="$2"
    local timestamp="$3"
    local log_file="$LOG_DIR/pencil-hid-canvas-matrix-$timestamp.log"
    local pull_dir snapshot_dir copy_error pulled_file
    pull_dir="$(mktemp -d)"
    snapshot_dir="$pull_dir/snapshot"
    copy_error="$pull_dir/copy-error.log"
    pulled_file="$snapshot_dir/canvas-diagnostics.log"
    mkdir -p "$snapshot_dir"

    if ! xcrun devicectl device copy from \
        --device "$device" \
        --domain-type appDataContainer \
        --domain-identifier "${COLORFLOW_BUNDLE_ID:-com.duckuwucky.sable}" \
        --source "Documents" \
        --destination "$snapshot_dir" \
        --timeout 30 \
        --quiet >"$copy_error" 2>&1; then
        cat "$copy_error" >&2
        rm -rf "$pull_dir"
        fail "Could not pull canvas diagnostics from the iPad."
    fi

    [[ -f "$pulled_file" ]] || {
        rm -rf "$pull_dir"
        fail "No canvas-diagnostics.log found in the app container."
    }

    cp "$pulled_file" "$log_file"
    rm -rf "$pull_dir"
    info "Pulled canvas diagnostics: $log_file"
    Scripts/analyze_canvas_diagnostics.py --session-id "$session_id" --scenario scribble-matrix "$log_file"
}

[[ $# -gt 0 ]] || { usage; exit 2; }
command="$1"
shift

device="$(resolve_device)" || fail "No available paired physical iPad found. Connect and unlock the iPad, then retry."
info "Device: $device"

./dev gen

case "$command" in
    probe)
        info "Probing private XCTest HID record/replay hooks."
        result_bundle="$(run_xcode_test "$device" probe test_probePrivateHIDRecording)"
        info "Probe result: $result_bundle"
        ;;
    record)
        clip="${1:-}"
        validate_clip "$clip"
        seconds="${2:-}"
        print_recording_instructions "$clip"
        env_args=("GOUACHE_PENCIL_HID_CLIP=$clip")
        if [[ -n "$seconds" ]]; then
            env_args+=("GOUACHE_PENCIL_HID_RECORD_SECONDS=$seconds")
        fi
        result_bundle="$(run_xcode_test "$device" record test_recordPencilHIDClip "${env_args[@]}")"
        export_recording_attachment "$result_bundle" "$clip"
        ;;
    replay)
        clip="${1:-}"
        validate_clip "$clip"
        key="$(clip_env_key "$clip")"
        data="$(clip_base64 "$clip")"
        info "Replaying $clip on the physical iPad."
        result_bundle="$(run_xcode_test "$device" replay test_replayPencilHIDClip \
            "GOUACHE_PENCIL_HID_CLIP=$clip" \
            "GOUACHE_PENCIL_HID_${key}_BASE64=$data")"
        info "Replay result: $result_bundle"
        ;;
    matrix)
        timestamp="$(date -u +"%Y%m%d-%H%M%S")"
        session_id="$(uuidgen | tr '[:lower:]' '[:upper:]')"
        fill_data="$(clip_base64 fill-tap)"
        scribble_data="$(clip_base64 scribble)"
        outside_data="$(clip_base64 outside-erase)"
        info "Running full clean/free matrix with true Apple Pencil HID clips."
        info "Session: $session_id"

        set +e
        result_bundle="$(run_xcode_test "$device" matrix test_replayCanvasMatrixWithPencilHIDClips \
            "GOUACHE_CANVAS_DIAGNOSTICS_SESSION_ID=$session_id" \
            "GOUACHE_PENCIL_HID_FILL_TAP_BASE64=$fill_data" \
            "GOUACHE_PENCIL_HID_SCRIBBLE_BASE64=$scribble_data" \
            "GOUACHE_PENCIL_HID_OUTSIDE_ERASE_BASE64=$outside_data")"
        test_status=$?
        set -e

        info "Matrix result: $result_bundle"
        pull_canvas_log "$device" "$session_id" "$timestamp"
        exit "$test_status"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 2
        ;;
esac
