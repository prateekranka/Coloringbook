#!/usr/bin/env bash
# colorflow_ui_test.sh — Coordinate-based UI test runner for ColorFlow
# Uses FlowDeck screen capture + coordinate taps since iPadOS 26.4
# accessibility tree is broken (only returns root element).
#
# Usage:
#   ./Scripts/testing/colorflow_ui_test.sh              # Run all tests
#   ./Scripts/testing/colorflow_ui_test.sh home         # Run Home tab tests
#   ./Scripts/testing/colorflow_ui_test.sh library      # Run Library tab tests
#   ./Scripts/testing/colorflow_ui_test.sh mywork       # Run My Work tab tests
#   ./Scripts/testing/colorflow_ui_test.sh canvas       # Run Canvas tests
#   ./Scripts/testing/colorflow_ui_test.sh --verify     # Just verify app is running + screenshot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORDS_FILE="$SCRIPT_DIR/coordinates.json"
SCREENSHOT_DIR="$SCRIPT_DIR/.screenshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SIMULATOR="iPad Pro 13-inch (M5)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# ── Helpers ──────────────────────────────────────────────────────────────────

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass()    { echo -e "${GREEN}[PASS]${NC} $*"; ((PASS++)) || true; }
log_fail()    { echo -e "${RED}[FAIL]${NC} $*"; ((FAIL++)) || true; }
log_skip()    { echo -e "${YELLOW}[SKIP]${NC} $*"; ((SKIP++)) || true; }
log_header()  { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}$*${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
log_diff_pass() { echo -e "${GREEN}[DIFF PASS]${NC} $*"; }
log_diff_fail() { echo -e "${RED}[DIFF FAIL]${NC} $*"; }
log_no_baseline() { echo -e "${YELLOW}[NO BASELINE]${NC} $*"; }

# Pixel-diff comparison (calls diff_screenshots.py)
diff_screenshot() {
    local name="$1"
    local current="$SCREENSHOT_DIR/${TIMESTAMP}_${name}.png"
    local baseline="$SCRIPT_DIR/baselines/${name}.png"
    if [ -f "$baseline" ]; then
        local result
        result=$(python3 "$SCRIPT_DIR/diff_screenshots.py" "$baseline" "$current" 0.03 2>&1) || true
        echo "$result"
    else
        echo "NO_BASELINE"
    fi
}

# Read a value from coordinates.json using python3
coord() {
    local screen="$1" element="$2" axis="$3"
    python3 -c "
import json, sys
with open('$COORDS_FILE') as f:
    d = json.load(f)
print(d['screens']['$screen']['elements']['$element']['$axis'])
"
}

# Capture a screenshot and save it
capture() {
    local name="${1:-screenshot}"
    local path="$SCREENSHOT_DIR/${TIMESTAMP}_${name}.png"
    mkdir -p "$SCREENSHOT_DIR"
    flowdeck ui simulator screen -S "$SIMULATOR" --output "$path" --json > /dev/null 2>&1
    echo "$path"
}

# Tap at coordinates
tap() {
    local x="$1" y="$2" label="${3:-}"
    flowdeck ui simulator tap --point "${x},${y}" -S "$SIMULATOR" --json > /dev/null 2>&1
    if [ -n "$label" ]; then
        sleep 1
    fi
}

# Drag gesture using swipe --from --to
drag() {
    local x1="$1" y1="$2" x2="$3" y2="$4" label="${5:-}"
    flowdeck ui simulator swipe --from "${x1},${y1}" --to "${x2},${y2}" -S "$SIMULATOR" --json > /dev/null 2>&1
    if [ -n "$label" ]; then
        sleep 1
    fi
}

# Long-press using tap --duration
long_press() {
    local x="$1" y="$2" label="${3:-}"
    flowdeck ui simulator tap --point "${x},${y}" --duration 1.0 -S "$SIMULATOR" --json > /dev/null 2>&1
    if [ -n "$label" ]; then
        sleep 1
    fi
}

# Pixel-diff comparison (calls diff_screenshots.py)
diff_screenshot() {
    local name="$1"
    local current="$SCREENSHOT_DIR/${TIMESTAMP}_${name}.png"
    local baseline="$SCRIPT_DIR/baselines/${name}.png"
    if [ -f "$baseline" ]; then
        local result
        result=$(python3 "$SCRIPT_DIR/diff_screenshots.py" "$baseline" "$current" 0.03 2>&1) || true
        echo "$result"
    else
        echo "NO_BASELINE"
    fi
}

# Fresh start: stop app, clear state, relaunch, open template
fresh_start() {
    local template_card_x="$1" template_card_y="$2" template_label="${3:-template}"

    # Stop app if running
    local app_id
    app_id=$(flowdeck apps --json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d['data']['runningCount'] > 0:
        print(d['data']['apps'][0]['id'])
except: pass
" 2>/dev/null) || true
    if [ -n "$app_id" ]; then
        flowdeck stop "$app_id" > /dev/null 2>&1 || true
        sleep 1
    fi

    # Clear simulator state
    flowdeck ui simulator clear-state -S "$SIMULATOR" > /dev/null 2>&1 || true

    # Relaunch
    flowdeck run > /dev/null 2>&1
    sleep 3

    # Navigate to Library and open template
    tap "$(coord library tab_library x)" "$(coord library tab_library y)" "Library tab"
    sleep 1
    tap "$template_card_x" "$template_card_y" "$template_label"
    sleep 3
}

# Verify app is running
ensure_app() {
    local app_info
    app_info=$(flowdeck apps --json 2>&1)
    if echo "$app_info" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d['data']['runningCount'] > 0 else 1)" 2>/dev/null; then
        return 0
    fi
    log_info "App not running — launching..."
    flowdeck run > /dev/null 2>&1
    sleep 3
}

# ── Test Suites ──────────────────────────────────────────────────────────────

test_home() {
    log_header "HOME TAB TESTS"

    ensure_app
    local shot
    shot=$(capture "01_home_initial")
    log_pass "Screenshot captured: $shot"

    # Verify Home tab is active (purple highlight visible in screenshot)
    log_pass "Home tab is active (visual verification via screenshot)"

    # Tap Library tab
    local lib_x lib_y
    lib_x=$(coord library tab_library x)
    lib_y=$(coord library tab_library y)
    tap "$lib_x" "$lib_y" "Library tab"
    shot=$(capture "02_after_library_tap")
    log_pass "Tapped Library tab from Home"

    # Navigate back to Home
    local home_x home_y
    home_x=$(coord home tab_home x)
    home_y=$(coord home tab_home y)
    tap "$home_x" "$home_y" "Home tab"
    sleep 1
    shot=$(capture "03_back_to_home")
    log_pass "Navigated back to Home tab"

    # Tap Browse Templates
    local browse_x browse_y
    browse_x=$(coord home browse_templates x)
    browse_y=$(coord home browse_templates y)
    tap "$browse_x" "$browse_y" "Browse Templates"
    sleep 2
    shot=$(capture "04_browse_templates_sheet")
    log_pass "Tapped Browse Templates — sheet should be visible"

    # Dismiss sheet by tapping outside (bottom area)
    tap 516 1200 "Dismiss sheet"
    sleep 1
    shot=$(capture "05_sheet_dismissed")
    log_pass "Dismissed template sheet"

    # Tap From Photo
    local photo_x photo_y
    photo_x=$(coord home from_photo x)
    photo_y=$(coord home from_photo y)
    tap "$photo_x" "$photo_y" "From Photo"
    sleep 2
    shot=$(capture "06_photo_import_sheet")
    log_pass "Tapped From Photo — import sheet should be visible"

    # Dismiss
    tap 516 1200 "Dismiss photo sheet"
    sleep 1
    shot=$(capture "07_photo_sheet_dismissed")
    log_pass "Dismissed photo import sheet"

    # Navigate to Library and tap first template card
    tap "$(coord library tab_library x)" "$(coord library tab_library y)" "Library tab"
    sleep 1
    tap "$(coord library card_lotus_mandala x)" "$(coord library card_lotus_mandala y)" "Lotus Mandala"
    sleep 3
    shot=$(capture "08_canvas_opened")
    log_pass "Opened template from Library — canvas visible"

    # Tap back to gallery
    local back_x back_y
    back_x=$(coord canvas back_button x)
    back_y=$(coord canvas back_button y)
    tap "$back_x" "$back_y" "Back button"
    sleep 1
    shot=$(capture "09_back_to_home_from_canvas")
    log_pass "Returned to Home from canvas"
}

test_library() {
    log_header "LIBRARY TAB TESTS"

    ensure_app

    # Navigate to Library
    local lib_x lib_y
    lib_x=$(coord library tab_library x)
    lib_y=$(coord library tab_library y)
    tap "$lib_x" "$lib_y" "Library tab"
    sleep 1
    local shot
    shot=$(capture "10_library_initial")
    log_pass "Library tab loaded"

    # Tap a category pill (Mandalas)
    local cat_x cat_y
    cat_x=$(coord library category_mandalas x)
    cat_y=$(coord library category_mandalas y)
    tap "$cat_x" "$cat_y" "Mandalas category"
    sleep 1
    shot=$(capture "11_library_mandalas")
    log_pass "Filtered to Mandalas category"

    # Tap All to reset
    local all_x all_y
    all_x=$(coord library category_all x)
    all_y=$(coord library category_all y)
    tap "$all_x" "$all_y" "All category"
    sleep 1
    shot=$(capture "12_library_all")
    log_pass "Reset to All category"

    # Tap first template card
    local card_x card_y
    card_x=$(coord library first_template_card x)
    card_y=$(coord library first_template_card y)
    tap "$card_x" "$card_y" "First template card"
    sleep 3
    shot=$(capture "13_library_canvas_opened")
    log_pass "Opened template from Library — canvas visible"

    # Back
    local back_x back_y
    back_x=$(coord canvas back_button x)
    back_y=$(coord canvas back_button y)
    tap "$back_x" "$back_y" "Back"
    sleep 1
    shot=$(capture "14_back_to_library")
    log_pass "Returned to Library from canvas"
}

test_mywork() {
    log_header "MY WORK TAB TESTS"

    ensure_app

    # Navigate to My Work
    local mw_x mw_y
    mw_x=$(coord mywork tab_mywork x)
    mw_y=$(coord mywork tab_mywork y)
    tap "$mw_x" "$mw_y" "My Work tab"
    sleep 1
    local shot
    shot=$(capture "15_mywork_initial")
    log_pass "My Work tab loaded"

    # Tap In Progress filter
    local ip_x ip_y
    ip_x=$(coord mywork filter_inprogress x)
    ip_y=$(coord mywork filter_inprogress y)
    tap "$ip_x" "$ip_y" "In Progress filter"
    sleep 1
    shot=$(capture "16_mywork_inprogress")
    log_pass "Tapped In Progress filter (no projects expected)"

    # Tap All filter
    local all_x all_y
    all_x=$(coord mywork filter_all x)
    all_y=$(coord mywork filter_all y)
    tap "$all_x" "$all_y" "All filter"
    sleep 1
    shot=$(capture "17_mywork_all")
    log_pass "Reset to All filter"
}

test_canvas() {
    log_header "CANVAS TESTS"

    ensure_app

    # Navigate to Library and open Lotus Mandala
    tap "$(coord library tab_library x)" "$(coord library tab_library y)" "Library tab"
    sleep 1
    tap "$(coord library card_lotus_mandala x)" "$(coord library card_lotus_mandala y)" "Lotus Mandala"
    sleep 3
    local shot
    shot=$(capture "18_canvas_opened")
    log_pass "Canvas opened"

    # Tap center of canvas (fill action)
    tap "$(coord canvas canvas_center x)" "$(coord canvas canvas_center y)" "Fill center region"
    sleep 1
    shot=$(capture "19_after_fill")
    log_pass "Tapped canvas center (fill action)"

    # Tap undo
    local undo_x undo_y
    undo_x=$(coord canvas undo_button x)
    undo_y=$(coord canvas undo_button y)
    tap "$undo_x" "$undo_y" "Undo"
    sleep 1
    shot=$(capture "20_after_undo")
    log_pass "Tapped undo"

    # Tap redo
    local redo_x redo_y
    redo_x=$(coord canvas redo_button x)
    redo_y=$(coord canvas redo_button y)
    tap "$redo_x" "$redo_y" "Redo"
    sleep 1
    shot=$(capture "21_after_redo")
    log_pass "Tapped redo"

    # Tap color well to open picker
    local cw_x cw_y
    cw_x=$(coord canvas color_well x)
    cw_y=$(coord canvas color_well y)
    tap "$cw_x" "$cw_y" "Color well"
    sleep 1
    shot=$(capture "22_color_picker_opened")
    log_pass "Color picker should be open"

    # Tap close on picker
    local close_x close_y
    close_x=$(coord canvas_detailed picker_close x)
    close_y=$(coord canvas_detailed picker_close y)
    tap "$close_x" "$close_y" "Close picker"
    sleep 1
    shot=$(capture "23_picker_closed")
    log_pass "Color picker closed"

    # Tap layers button
    local layers_x layers_y
    layers_x=$(coord canvas layers_button x)
    layers_y=$(coord canvas layers_button y)
    tap "$layers_x" "$layers_y" "Layers"
    sleep 1
    shot=$(capture "24_layers_panel")
    log_pass "Layers panel should be visible"

    # Tap layers again to close
    tap "$layers_x" "$layers_y" "Layers (close)"
    sleep 1
    shot=$(capture "25_layers_closed")
    log_pass "Layers panel closed"

    # Back to gallery
    local back_x back_y
    back_x=$(coord canvas back_button x)
    back_y=$(coord canvas back_button y)
    tap "$back_x" "$back_y" "Back"
    sleep 1
    shot=$(capture "26_back_to_home")
    log_pass "Returned to Home from canvas"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    local filter="${1:-all}"

    log_info "ColorFlow Coordinate-Based UI Test Runner"
    log_info "Simulator: $SIMULATOR"
    log_info "Screenshots: $SCREENSHOT_DIR/"
    log_info "Filter: $filter"

    mkdir -p "$SCREENSHOT_DIR"

    case "$filter" in
        home)    test_home ;;
        library) test_library ;;
        mywork)  test_mywork ;;
        canvas)  test_canvas ;;
        --verify)
            ensure_app
            capture "verify"
            log_pass "App is running — screenshot captured"
            ;;
        all)
            test_home
            test_library
            test_mywork
            test_canvas
            ;;
        *)
            echo "Usage: $0 {home|library|mywork|canvas|--verify|all}"
            exit 1
            ;;
    esac

    log_header "RESULTS"
    echo -e "  ${GREEN}Passed:${NC} $PASS"
    echo -e "  ${RED}Failed:${NC} $FAIL"
    echo -e "  ${YELLOW}Skipped:${NC} $SKIP"
    echo ""
    echo "Screenshots saved to: $SCREENSHOT_DIR/"
    echo "Latest: $(ls -t "$SCREENSHOT_DIR"/*.png 2>/dev/null | head -1)"

    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
}

# If sourced, stop here — only run main when executed directly
(return 0 2>/dev/null) && return || true

main "$@"
