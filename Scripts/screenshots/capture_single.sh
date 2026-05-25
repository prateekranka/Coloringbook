#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

BUNDLE_ID=""
SIM_NAME=""
ORIENTATION="portrait"
TEST_METHOD=""
OUTPUT_DIR=""
OUTPUT_NAME=""

usage() {
  cat <<USAGE
Usage: capture_single.sh [options]

Options:
  --bundle-id ID        App bundle identifier
  --sim-name NAME       Simulator device name
  --orientation VALUE   portrait|landscapeRight
  --test-method NAME    XCTest method to run
  --output-dir PATH     Output directory
  --output-name NAME    Output filename
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --sim-name) SIM_NAME="$2"; shift 2 ;;
    --orientation) ORIENTATION="$2"; shift 2 ;;
    --test-method) TEST_METHOD="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --output-name) OUTPUT_NAME="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -z "$BUNDLE_ID" ]] && { echo "Missing --bundle-id" >&2; exit 1; }
[[ -z "$SIM_NAME" ]] && { echo "Missing --sim-name" >&2; exit 1; }
[[ -z "$TEST_METHOD" ]] && { echo "Missing --test-method" >&2; exit 1; }
[[ -z "$OUTPUT_DIR" ]] && { echo "Missing --output-dir" >&2; exit 1; }
[[ -z "$OUTPUT_NAME" ]] && { echo "Missing --output-name" >&2; exit 1; }

export SIM_NAME

# Convert to absolute path if relative
if [[ ! "$OUTPUT_DIR" = /* ]]; then
  OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"

resolve_sim_udid() {
  SIM_NAME="$SIM_NAME" xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, os, sys
want = os.environ["SIM_NAME"]
data = json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("name") == want:
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
'
}

resolve_device_type() {
  SIM_NAME="$SIM_NAME" xcrun simctl list devicetypes --json | /usr/bin/python3 -c '
import json, os, sys
want = os.environ["SIM_NAME"]
data = json.load(sys.stdin)
matches = [d for d in data.get("devicetypes", []) if d.get("name") == want]
if not matches:
    raise SystemExit(1)
print(matches[0]["identifier"])
'
}

resolve_runtime() {
  local device_type="$1"
  DEVICE_TYPE="$device_type"
  export DEVICE_TYPE
  xcrun simctl list runtimes --json | /usr/bin/python3 -c '
import json, os, sys
want = os.environ["DEVICE_TYPE"]
data = json.load(sys.stdin)
candidates = []
for runtime in data.get("runtimes", []):
    if not runtime.get("isAvailable", False):
        continue
    identifier = runtime.get("identifier", "")
    if "iOS" not in identifier:
        continue
    supported = runtime.get("supportedDeviceTypes", [])
    if any(device_type.get("identifier") == want for device_type in supported):
        candidates.append(runtime)
if not candidates:
    raise SystemExit(1)

def version_tuple(runtime):
    return tuple(int(part) for part in runtime.get("version", "0").split(".") if part.isdigit())

candidates.sort(key=version_tuple)
print(candidates[-1]["identifier"])
'
}

SIM_UDID=$(resolve_sim_udid || true)

if [[ -z "$SIM_UDID" ]]; then
  echo "  Creating simulator: $SIM_NAME"
  DEVICE_TYPE=$(resolve_device_type || true)
  if [[ -z "$DEVICE_TYPE" ]]; then
    echo "  Error: Could not find simulator device type '$SIM_NAME'" >&2
    exit 1
  fi
  RUNTIME=$(resolve_runtime "$DEVICE_TYPE" || true)
  if [[ -z "$RUNTIME" ]]; then
    echo "  Error: Could not find an available iOS runtime for '$SIM_NAME'" >&2
    exit 1
  fi
  SIM_UDID=$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE" "$RUNTIME" 2>/dev/null || echo "")
fi

if [[ -z "$SIM_UDID" ]]; then
  echo "  Error: Could not find or create simulator" >&2
  exit 1
fi

echo "  📱 Simulator: $SIM_NAME ($SIM_UDID)"

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1

# Note: Device orientation is set via the UI test or can be controlled via device rotation
# The simctl io setOrientation command is no longer available in newer Xcode versions.
# ScreenshotUITests reads SCREENSHOT_ORIENTATION and rotates through XCUIDevice.
echo "  📐 Orientation: $ORIENTATION"

xcrun simctl status_bar "$SIM_UDID" override \
  --time "9:41" \
  --dataNetwork "wifi" \
  --wifiMode "active" \
  --wifiBars 3 \
  --cellularMode "notSupported" \
  --batteryState "charged" \
  --batteryLevel 100 2>/dev/null || true

xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true

echo "  🎬 Running UI automation..."

LOG_PATH="${OUTPUT_PATH%.png}.xcodebuild.log"
RESULT_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gouache-screenshot.XXXXXX")
RESULT_BUNDLE="${RESULT_ROOT}/result.xcresult"
ATTACHMENTS_DIR="${RESULT_ROOT}/attachments"
if ! env \
  SCREENSHOT_ORIENTATION="$ORIENTATION" \
  SCREENSHOT_OUTPUT_PATH="$OUTPUT_PATH" \
  xcodebuild test \
    -project "$PROJECT_ROOT/ColorFlow.xcodeproj" \
    -scheme "ColorFlow" \
    -destination "platform=iOS Simulator,id=$SIM_UDID" \
    -only-testing "ColorFlowUITests/ScreenshotUITests/$TEST_METHOD" \
    -configuration Debug \
    -parallel-testing-enabled NO \
    -parallel-testing-worker-count 1 \
    -maximum-concurrent-test-simulator-destinations 1 \
    -resultBundlePath "$RESULT_BUNDLE" \
    >"$LOG_PATH" 2>&1; then
  echo "  ❌ UI automation failed. Last 80 log lines:" >&2
  tail -80 "$LOG_PATH" >&2
  rm -rf "$RESULT_ROOT"
  exit 1
fi

if [[ ! -f "$OUTPUT_PATH" ]]; then
  mkdir -p "$ATTACHMENTS_DIR"
  xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$ATTACHMENTS_DIR" \
    >/dev/null

  SCREENSHOT_SOURCE=$(find "$ATTACHMENTS_DIR" -type f -iname "*.png" | head -1)
  if [[ -z "$SCREENSHOT_SOURCE" ]]; then
    echo "  ❌ Screenshot capture failed: no PNG attachment found in $RESULT_BUNDLE" >&2
    rm -rf "$RESULT_ROOT"
    exit 1
  fi
  cp "$SCREENSHOT_SOURCE" "$OUTPUT_PATH"
fi

rm -f "$LOG_PATH"
rm -rf "$RESULT_ROOT"

xcrun simctl status_bar "$SIM_UDID" clear 2>/dev/null || true

echo "  ✅ Captured: $OUTPUT_NAME"
