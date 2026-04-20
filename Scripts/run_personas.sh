#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ColorFlow"
TEST_PLAN="ColorFlowUITests/Personas"
LOG_DIR="$REPO_ROOT/.persona_logs"
mkdir -p "$LOG_DIR"

echo "→ Finding iPad simulator..."
UDID=$(xcrun simctl list devices available | grep "iPad" | grep -v "Shutdown" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)

if [ -z "$UDID" ]; then
    UDID=$(xcrun simctl list devices available | grep "iPad" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
fi

if [ -z "$UDID" ]; then
    echo "ERROR: No iPad simulator found"
    exit 1
fi

echo "→ Booting simulator $UDID..."
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$UDID"
sleep 3

echo "→ Building..."
xcodebuild build \
    -project "$REPO_ROOT/ColorFlow.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "id=$UDID" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    | tail -5

echo "→ Running persona tests..."
xcodebuild test \
    -project "$REPO_ROOT/ColorFlow.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "id=$UDID" \
    -only-testing:"$TEST_PLAN" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    -testLaunchArguments "-personaRun -skipOnboarding" \
    2>&1 | tee "$LOG_DIR/persona_run_$(date +%Y%m%d_%H%M%S).log" | tail -20

echo "→ Persona tests complete. Logs in $LOG_DIR/"
