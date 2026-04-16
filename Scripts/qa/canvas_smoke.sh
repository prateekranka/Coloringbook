#!/usr/bin/env bash
set -euo pipefail

# Canvas smoke test — drives FlowDeck UI automation to verify the
# first-tap-fills-a-region golden path on a clean simulator.
#
# Usage:
#   bash Scripts/qa/canvas_smoke.sh [SIMULATOR_NAME]
#
# Default simulator: "iPad Air 11-inch (M4)"
#
# Prerequisites:
#   - flowdeck CLI installed and on PATH
#   - Xcode project built (flowdeck build or xcodegen + flowdeck run)
#
# Exit codes:
#   0 — all checks passed
#   1 — a step failed (diagnostic printed to stderr)

SIMULATOR="${1:-iPad Air 11-inch (M4)}"
APP_BUNDLE="com.prateekranka.colorflow"
TIMEOUT_SECS=10
LOG_PATTERN="\[ViewModel\] performRegionFill — hit region"

echo "=== Canvas Smoke Test ==="
echo "Simulator: $SIMULATOR"
echo ""

# Step 1: Uninstall to reset UserDefaults
echo "[1/6] Resetting app state..."
flowdeck uninstall -S "$SIMULATOR" 2>/dev/null || true

# Step 2: Build and launch
echo "[2/6] Building and launching..."
flowdeck run -w ColorFlow.xcodeproj -s ColorFlow -S "$SIMULATOR" --wait-for-launch 2>&1 | tail -3

# Step 3: Advance past onboarding
echo "[3/6] Advancing past onboarding..."
# Try by accessibility label first; fall back to coordinate tap
if flowdeck ui tap --label "Continue" -S "$SIMULATOR" 2>/dev/null; then
    echo "  Tapped 'Continue' by label"
elif flowdeck ui tap --label "Get Started" -S "$SIMULATOR" 2>/dev/null; then
    echo "  Tapped 'Get Started' by label"
else
    echo "  Label tap failed — using coordinate fallback (center-bottom)"
    flowdeck ui tap --point 512,700 -S "$SIMULATOR" 2>/dev/null || true
fi
sleep 1

# Repeat for multi-screen onboarding
for i in 1 2 3; do
    flowdeck ui tap --label "Continue" -S "$SIMULATOR" 2>/dev/null || \
    flowdeck ui tap --label "Get Started" -S "$SIMULATOR" 2>/dev/null || \
    flowdeck ui tap --label "Start Coloring" -S "$SIMULATOR" 2>/dev/null || true
    sleep 0.5
done

# Step 4: Open a template
echo "[4/6] Opening a template..."
# Tap first template in the grid (approximate coordinate for grid item)
flowdeck ui tap --point 200,400 -S "$SIMULATOR" 2>/dev/null || true
sleep 2

# Step 5: Tap the canvas center to trigger a fill
echo "[5/6] Tapping canvas center..."
flowdeck ui tap --point 512,512 -S "$SIMULATOR" 2>/dev/null || true

# Step 6: Check logs for the fill log entry
echo "[6/6] Checking for fill log entry..."
sleep 2

LOG_OUTPUT=$(flowdeck logs -S "$SIMULATOR" --last 50 2>/dev/null || echo "")

if echo "$LOG_OUTPUT" | grep -q "$LOG_PATTERN"; then
    echo ""
    echo "=== PASS ==="
    echo "Found '$LOG_PATTERN' in app logs."
    exit 0
else
    echo "" >&2
    echo "=== FAIL ===" >&2
    echo "Did not find '$LOG_PATTERN' in app logs within ${TIMEOUT_SECS}s." >&2
    echo "Recent logs:" >&2
    echo "$LOG_OUTPUT" | tail -20 >&2
    exit 1
fi
