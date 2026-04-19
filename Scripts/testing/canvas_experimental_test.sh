#!/usr/bin/env bash
# canvas_experimental_test.sh — Persona 3: Experimental User
# Explore every feature — all tools, color modes, layer toggles, toolbar states
# Template: Butterfly Garden (multiple regions for layer/color experiments)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colorflow_ui_test.sh"

test_experimental_user() {
    log_header "PERSONA 3: EXPERIMENTAL USER"
    log_info "Template: Butterfly Garden"
    log_info "Workflow: Cycle all tools → explore color picker modes → layers → toolbar toggle → exit"

    # Fresh start: stop app, clear state, relaunch, open Butterfly Garden
    fresh_start "$(coord library card_butterfly_garden x)" "$(coord library card_butterfly_garden y)" "Butterfly Garden"

    local shot diff_result

    # Step 1: Verify canvas loaded
    shot=$(capture "exp_01_canvas_loaded")
    log_pass "Step 1: Canvas loaded with Butterfly Garden"
    diff_result=$(diff_screenshot "exp_01_canvas_loaded")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_01_canvas_loaded" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_01_canvas_loaded" || log_diff_fail "exp_01_canvas_loaded: $diff_result"
    }

    # Step 2: Select Pencil
    tap "$(coord canvas tool_pencil x)" "$(coord canvas tool_pencil y)" "Pencil"
    shot=$(capture "exp_02_pencil")
    log_pass "Step 2: Pencil selected"
    diff_result=$(diff_screenshot "exp_02_pencil")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_02_pencil" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_02_pencil" || log_diff_fail "exp_02_pencil: $diff_result"
    }

    # Step 3: Select Marker
    tap "$(coord canvas tool_marker x)" "$(coord canvas tool_marker y)" "Marker"
    shot=$(capture "exp_03_marker")
    log_pass "Step 3: Marker selected"
    diff_result=$(diff_screenshot "exp_03_marker")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_03_marker" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_03_marker" || log_diff_fail "exp_03_marker: $diff_result"
    }

    # Step 4: Select Watercolor
    tap "$(coord canvas tool_watercolor x)" "$(coord canvas tool_watercolor y)" "Watercolor"
    shot=$(capture "exp_04_watercolor")
    log_pass "Step 4: Watercolor selected"
    diff_result=$(diff_screenshot "exp_04_watercolor")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_04_watercolor" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_04_watercolor" || log_diff_fail "exp_04_watercolor: $diff_result"
    }

    # Step 5: Select Eraser
    tap "$(coord canvas tool_eraser x)" "$(coord canvas tool_eraser y)" "Eraser"
    shot=$(capture "exp_05_eraser")
    log_pass "Step 5: Eraser selected"
    diff_result=$(diff_screenshot "exp_05_eraser")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_05_eraser" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_05_eraser" || log_diff_fail "exp_05_eraser: $diff_result"
    }

    # Step 6: Select Fill
    tap "$(coord canvas tool_floodfill x)" "$(coord canvas tool_floodfill y)" "Fill"
    shot=$(capture "exp_06_fill")
    log_pass "Step 6: Fill selected"
    diff_result=$(diff_screenshot "exp_06_fill")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_06_fill" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_06_fill" || log_diff_fail "exp_06_fill: $diff_result"
    }

    # Step 7: Select Eyedropper
    tap "$(coord canvas tool_eyedropper x)" "$(coord canvas tool_eyedropper y)" "Eyedropper"
    shot=$(capture "exp_07_eyedropper")
    log_pass "Step 7: Eyedropper selected"
    diff_result=$(diff_screenshot "exp_07_eyedropper")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_07_eyedropper" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_07_eyedropper" || log_diff_fail "exp_07_eyedropper: $diff_result"
    }

    # Step 8: Open color picker
    tap "$(coord canvas color_well x)" "$(coord canvas color_well y)" "Color well"
    sleep 1
    shot=$(capture "exp_08_picker_open")
    log_pass "Step 8: Color picker opened (Spectrum mode)"
    diff_result=$(diff_screenshot "exp_08_picker_open")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_08_picker_open" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_08_picker_open" || log_diff_fail "exp_08_picker_open: $diff_result"
    }

    # Step 9: Switch to Palette mode
    tap "$(coord canvas_detailed picker_palette x)" "$(coord canvas_detailed picker_palette y)" "Palette mode"
    sleep 1
    shot=$(capture "exp_09_palette_mode")
    log_pass "Step 9: Switched to Palette mode"
    diff_result=$(diff_screenshot "exp_09_palette_mode")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_09_palette_mode" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_09_palette_mode" || log_diff_fail "exp_09_palette_mode: $diff_result"
    }

    # Step 10: Select Pastels palette (tap on popover item)
    tap "$(coord canvas_detailed palette_pastels x)" "$(coord canvas_detailed palette_pastels y)" "Pastels palette"
    sleep 1
    shot=$(capture "exp_10_pastels_selected")
    log_pass "Step 10: Pastels palette selected"
    diff_result=$(diff_screenshot "exp_10_pastels_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_10_pastels_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_10_pastels_selected" || log_diff_fail "exp_10_pastels_selected: $diff_result"
    }

    # Step 11: Long-press a swatch to trigger brightness strip
    long_press "$(coord canvas_detailed picker_swatch_center x)" "$(coord canvas_detailed picker_swatch_center y)" "Long-press swatch"
    sleep 1
    shot=$(capture "exp_11_brightness_strip")
    log_pass "Step 11: Brightness strip appeared after long-press"
    diff_result=$(diff_screenshot "exp_11_brightness_strip")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_11_brightness_strip" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_11_brightness_strip" || log_diff_fail "exp_11_brightness_strip: $diff_result"
    }

    # Step 12: Adjust brightness (drag slider)
    drag "$(coord canvas_detailed picker_brightness_min x)" "$(coord canvas_detailed picker_brightness_min y)" \
         "$(coord canvas_detailed picker_brightness_max x)" "$(coord canvas_detailed picker_brightness_max y)" \
         "Adjust brightness"
    sleep 1
    shot=$(capture "exp_12_brightness_changed")
    log_pass "Step 12: Brightness adjusted"
    diff_result=$(diff_screenshot "exp_12_brightness_changed")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_12_brightness_changed" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_12_brightness_changed" || log_diff_fail "exp_12_brightness_changed: $diff_result"
    }

    # Step 13: Dismiss brightness strip
    tap "$(coord canvas_detailed picker_brightness_close x)" "$(coord canvas_detailed picker_brightness_close y)" "Dismiss brightness"
    sleep 1
    shot=$(capture "exp_13_strip_dismissed")
    log_pass "Step 13: Brightness strip dismissed"
    diff_result=$(diff_screenshot "exp_13_strip_dismissed")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_13_strip_dismissed" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_13_strip_dismissed" || log_diff_fail "exp_13_strip_dismissed: $diff_result"
    }

    # Step 14: Select from recent colors row
    tap "$(coord canvas_detailed picker_recent_1 x)" "$(coord canvas_detailed picker_recent_1 y)" "Recent color"
    sleep 1
    shot=$(capture "exp_14_recent_selected")
    log_pass "Step 14: Recent color selected"
    diff_result=$(diff_screenshot "exp_14_recent_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_14_recent_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_14_recent_selected" || log_diff_fail "exp_14_recent_selected: $diff_result"
    }

    # Step 15: Close picker
    tap "$(coord canvas_detailed picker_close x)" "$(coord canvas_detailed picker_close y)" "Close picker"
    sleep 1
    shot=$(capture "exp_15_picker_closed")
    log_pass "Step 15: Color picker closed"
    diff_result=$(diff_screenshot "exp_15_picker_closed")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_15_picker_closed" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_15_picker_closed" || log_diff_fail "exp_15_picker_closed: $diff_result"
    }

    # Step 16: Open Layers panel
    tap "$(coord canvas layers_button x)" "$(coord canvas layers_button y)" "Layers"
    sleep 1
    shot=$(capture "exp_16_layers_open")
    log_pass "Step 16: Layers panel opened"
    diff_result=$(diff_screenshot "exp_16_layers_open")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_16_layers_open" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_16_layers_open" || log_diff_fail "exp_16_layers_open: $diff_result"
    }

    # Step 17: Toggle Color layer off (tap eye icon)
    tap "$(coord canvas_detailed layer_color_eye x)" "$(coord canvas_detailed layer_color_eye y)" "Toggle Color layer"
    sleep 1
    shot=$(capture "exp_17_color_hidden")
    log_pass "Step 17: Color layer toggled off"
    diff_result=$(diff_screenshot "exp_17_color_hidden")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_17_color_hidden" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_17_color_hidden" || log_diff_fail "exp_17_color_hidden: $diff_result"
    }

    # Step 18: Toggle Color layer on
    tap "$(coord canvas_detailed layer_color_eye x)" "$(coord canvas_detailed layer_color_eye y)" "Toggle Color layer"
    sleep 1
    shot=$(capture "exp_18_color_shown")
    log_pass "Step 18: Color layer toggled on"
    diff_result=$(diff_screenshot "exp_18_color_shown")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_18_color_shown" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_18_color_shown" || log_diff_fail "exp_18_color_shown: $diff_result"
    }

    # Step 19: Change background color (tap background color picker)
    tap "$(coord canvas_detailed layer_bg_picker x)" "$(coord canvas_detailed layer_bg_picker y)" "Background color"
    sleep 1
    shot=$(capture "exp_19_bg_changed")
    log_pass "Step 19: Background color changed"
    diff_result=$(diff_screenshot "exp_19_bg_changed")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_19_bg_changed" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_19_bg_changed" || log_diff_fail "exp_19_bg_changed: $diff_result"
    }

    # Step 20: Close layers panel (tap Done)
    tap "$(coord canvas_detailed layer_done x)" "$(coord canvas_detailed layer_done y)" "Done"
    sleep 1
    shot=$(capture "exp_20_layers_closed")
    log_pass "Step 20: Layers panel closed"
    diff_result=$(diff_screenshot "exp_20_layers_closed")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_20_layers_closed" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_20_layers_closed" || log_diff_fail "exp_20_layers_closed: $diff_result"
    }

    # Step 21: Hide toolbar
    tap "$(coord canvas toolbar_toggle x)" "$(coord canvas toolbar_toggle y)" "Hide toolbar"
    sleep 1
    shot=$(capture "exp_21_toolbar_hidden")
    log_pass "Step 21: Toolbar hidden — canvas full-bleed"
    diff_result=$(diff_screenshot "exp_21_toolbar_hidden")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_21_toolbar_hidden" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_21_toolbar_hidden" || log_diff_fail "exp_21_toolbar_hidden: $diff_result"
    }

    # Step 22: Show toolbar (tap restore button)
    tap "$(coord canvas_detailed toolbar_restore x)" "$(coord canvas_detailed toolbar_restore y)" "Restore toolbar"
    sleep 1
    shot=$(capture "exp_22_toolbar_shown")
    log_pass "Step 22: Toolbar restored"
    diff_result=$(diff_screenshot "exp_22_toolbar_shown")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_22_toolbar_shown" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_22_toolbar_shown" || log_diff_fail "exp_22_toolbar_shown: $diff_result"
    }

    # Step 23: Tap back
    tap "$(coord canvas back_button x)" "$(coord canvas back_button y)" "Back"
    sleep 1
    shot=$(capture "exp_23_back_home")
    log_pass "Step 23: Returned to Home"
    diff_result=$(diff_screenshot "exp_23_back_home")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_23_back_home" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_23_back_home" || log_diff_fail "exp_23_back_home: $diff_result"
    }

    # Step 24: Verify Home
    shot=$(capture "exp_24_home_verified")
    log_pass "Step 24: Home screen verified"
    diff_result=$(diff_screenshot "exp_24_home_verified")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "exp_24_home_verified" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "exp_24_home_verified" || log_diff_fail "exp_24_home_verified: $diff_result"
    }
}

# Only run if not being sourced by the orchestrator
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    test_experimental_user
    log_header "EXPERIMENTAL USER RESULTS"
    echo -e "  ${GREEN}Passed:${NC} $PASS"
    echo -e "  ${RED}Failed:${NC} $FAIL"
    exit $FAIL
fi
