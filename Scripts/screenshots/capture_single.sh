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

# Convert to absolute path if relative
if [[ ! "$OUTPUT_DIR" = /* ]]; then
  OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"

SIM_UDID=$(xcrun simctl list devices available | grep "$SIM_NAME" | head -1 | grep -oE '[A-Z0-9-]{36}' | head -1)

if [[ -z "$SIM_UDID" ]]; then
  echo "  Creating simulator: $SIM_NAME"
  SIM_UDID=$(xcrun simctl create "Gouache Screenshot" "$(echo "$SIM_NAME" | sed 's/ (.*//')" 2>/dev/null || echo "")
fi

if [[ -z "$SIM_UDID" ]]; then
  echo "  Error: Could not find or create simulator" >&2
  exit 1
fi

echo "  📱 Simulator: $SIM_NAME ($SIM_UDID)"

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1

# Note: Device orientation is set via the UI test or can be controlled via device rotation
# The simctl io setOrientation command is no longer available in newer Xcode versions
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

APP_PATH=$(find "$PROJECT_ROOT/build" -name "*.app" -type d 2>/dev/null | head -1)
if [[ -z "$APP_PATH" ]]; then
  APP_PATH=$(find "$PROJECT_ROOT" -path "*/Build/Products/*" -name "*.app" -type d 2>/dev/null | head -1)
fi

if [[ -n "$APP_PATH" ]]; then
  xcrun simctl install "$SIM_UDID" "$APP_PATH"
fi

echo "  🎬 Running UI automation..."

xcodebuild test \
  -project "$PROJECT_ROOT/ColorFlow.xcodeproj" \
  -scheme "ColorFlow" \
  -destination "platform=iOS Simulator,id=$SIM_UDID" \
  -only-testing "ColorFlowUITests/ScreenshotUITests/$TEST_METHOD" \
  >/dev/null 2>&1 || echo "  ⚠️  Test may have failed, continuing..."

sleep 2

xcrun simctl io "$SIM_UDID" screenshot "$OUTPUT_PATH"

if [[ ! -f "$OUTPUT_PATH" ]]; then
  echo "  ❌ Screenshot capture failed"
  exit 1
fi

xcrun simctl status_bar "$SIM_UDID" clear 2>/dev/null || true

echo "  ✅ Captured: $OUTPUT_NAME"
