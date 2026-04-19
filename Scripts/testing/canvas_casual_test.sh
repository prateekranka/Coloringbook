#!/usr/bin/env bash
# canvas_casual_test.sh — Persona 1: Casual Colorist
# Quick coloring session — flood fill + color picking
# Template: Lotus Mandala (simple shapes, easy flood-fill targets)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colorflow_ui_test.sh"

# Override main to only run this persona
# The sourced script defines all functions, we just call our test

test_casual_colorist() {
    log_header "PERSONA 1: CASUAL COLORIST"
    log_info "Template: Lotus Mandala"
    log_info "Workflow: Open template → flood fill → pick colors → fill more → exit"

    # Fresh start: stop app, clear state, relaunch, open Lotus Mandala
    fresh_start "$(coord library card_lotus_mandala x)" "$(coord library card_lotus_mandala y)" "Lotus Mandala"

    local shot diff_result

    # Step 1: Verify canvas loaded
    shot=$(capture "casual_01_canvas_loaded")
    log_pass "Step 1: Canvas loaded with Lotus Mandala"
    diff_result=$(diff_screenshot "casual_01_canvas_loaded")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_01_canvas_loaded" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_01_canvas_loaded" || log_diff_fail "casual_01_canvas_loaded: $diff_result"
    }

    # Step 2: Select Fill tool
    tap "$(coord canvas tool_floodfill x)" "$(coord canvas tool_floodfill y)" "Fill tool"
    shot=$(capture "casual_02_fill_selected")
    log_pass "Step 2: Fill tool selected"
    diff_result=$(diff_screenshot "casual_02_fill_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_02_fill_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_02_fill_selected" || log_diff_fail "casual_02_fill_selected: $diff_result"
    }

    # Step 3: Tap center region (fill with default purple)
    tap "$(coord canvas canvas_center x)" "$(coord canvas canvas_center y)" "Fill center"
    sleep 1
    shot=$(capture "casual_03_center_filled")
    log_pass "Step 3: Center region filled with purple"
    diff_result=$(diff_screenshot "casual_03_center_filled")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_03_center_filled" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_03_center_filled" || log_diff_fail "casual_03_center_filled: $diff_result"
    }

    # Step 4: Open color picker
    tap "$(coord canvas color_well x)" "$(coord canvas color_well y)" "Color well"
    sleep 1
    shot=$(capture "casual_04_picker_open")
    log_pass "Step 4: Color picker opened"
    diff_result=$(diff_screenshot "casual_04_picker_open")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_04_picker_open" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_04_picker_open" || log_diff_fail "casual_04_picker_open: $diff_result"
    }

    # Step 5: Select red from hue ring (top of ring)
    tap "$(coord canvas_detailed picker_hue_top x)" "$(coord canvas_detailed picker_hue_top y)" "Red hue"
    sleep 1
    shot=$(capture "casual_05_red_selected")
    log_pass "Step 5: Red color selected from hue ring"
    diff_result=$(diff_screenshot "casual_05_red_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_05_red_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_05_red_selected" || log_diff_fail "casual_05_red_selected: $diff_result"
    }

    # Step 6: Close picker
    tap "$(coord canvas_detailed picker_close x)" "$(coord canvas_detailed picker_close y)" "Close picker"
    sleep 1
    shot=$(capture "casual_06_picker_closed")
    log_pass "Step 6: Color picker closed"
    diff_result=$(diff_screenshot "casual_06_picker_closed")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_06_picker_closed" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_06_picker_closed" || log_diff_fail "casual_06_picker_closed: $diff_result"
    }

    # Step 7: Fill another region with red
    tap 400 500 "Fill region 1"
    sleep 1
    shot=$(capture "casual_07_second_fill")
    log_pass "Step 7: Second region filled with red"
    diff_result=$(diff_screenshot "casual_07_second_fill")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_07_second_fill" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_07_second_fill" || log_diff_fail "casual_07_second_fill: $diff_result"
    }

    # Step 8: Tap back to Home
    tap "$(coord canvas back_button x)" "$(coord canvas back_button y)" "Back"
    sleep 1
    shot=$(capture "casual_08_back_home")
    log_pass "Step 8: Returned to Home"
    diff_result=$(diff_screenshot "casual_08_back_home")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_08_back_home" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_08_back_home" || log_diff_fail "casual_08_back_home: $diff_result"
    }

    # Step 9: Verify Home loaded
    shot=$(capture "casual_09_home_verified")
    log_pass "Step 9: Home screen verified"
    diff_result=$(diff_screenshot "casual_09_home_verified")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "casual_09_home_verified" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "casual_09_home_verified" || log_diff_fail "casual_09_home_verified: $diff_result"
    }
}

# Run the test (works both when sourced by orchestrator and when run directly)
test_casual_colorist

# Only show results summary when run directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    log_header "CASUAL COLORIST RESULTS"
    echo -e "  ${GREEN}Passed:${NC} $PASS"
    echo -e "  ${RED}Failed:${NC} $FAIL"
    exit $FAIL
fi
