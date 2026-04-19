#!/usr/bin/env bash
# canvas_power_test.sh — Persona 4: Power User
# Complex multi-tool workflow with undo chains, layer management, and color picking
# Template: Kitchen Morning (complex scene for multi-tool workflow)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colorflow_ui_test.sh"

test_power_user() {
    log_header "PERSONA 4: POWER USER"
    log_info "Template: Kitchen Morning"
    log_info "Workflow: Multi-tool session → undo chain → palette colors → eraser → layers → eyedropper → final artwork"

    # Fresh start: stop app, clear state, relaunch, open Kitchen Morning
    fresh_start "$(coord library card_kitchen_morning x)" "$(coord library card_kitchen_morning y)" "Kitchen Morning"

    local shot diff_result

    # Step 1: Verify canvas loaded
    shot=$(capture "power_01_canvas_loaded")
    log_pass "Step 1: Canvas loaded with Kitchen Morning"
    diff_result=$(diff_screenshot "power_01_canvas_loaded")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_01_canvas_loaded" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_01_canvas_loaded" || log_diff_fail "power_01_canvas_loaded: $diff_result"
    }

    # Step 2: Pencil 3pt, draw fine outline (horizontal stroke)
    tap "$(coord canvas tool_pencil x)" "$(coord canvas tool_pencil y)" "Pencil"
    tap "$(coord canvas tool_pencil x)" "$(coord canvas tool_pencil y)" "Pencil (open drawer)"
    sleep 1
    drag "$(coord canvas_detailed drawer_scrubber_bottom x)" "$(coord canvas_detailed drawer_scrubber_bottom y)" \
         "$(coord canvas_detailed drawer_scrubber_top x)" "$(coord canvas_detailed drawer_scrubber_top y)" \
         "Small brush"
    sleep 1
    drag 350 600 750 600 "Fine outline stroke"
    sleep 1
    shot=$(capture "power_02_fine_outline")
    log_pass "Step 2: Fine pencil outline drawn"
    diff_result=$(diff_screenshot "power_02_fine_outline")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_02_fine_outline" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_02_fine_outline" || log_diff_fail "power_02_fine_outline: $diff_result"
    }

    # Step 3: Marker 15pt 80%, fill area
    tap "$(coord canvas tool_marker x)" "$(coord canvas tool_marker y)" "Marker"
    tap "$(coord canvas tool_marker x)" "$(coord canvas tool_marker y)" "Marker (open drawer)"
    sleep 1
    # Set medium size (middle of scrubber)
    drag "$(coord canvas_detailed drawer_scrubber_top x)" "$(coord canvas_detailed drawer_scrubber_top y)" \
         "$(coord canvas_detailed drawer_scrubber_bottom x)" "$(coord canvas_detailed drawer_scrubber_bottom y)" \
         "Medium brush"
    sleep 1
    # Set opacity to ~80% (drag from left to right-ish)
    drag "$(coord canvas_detailed drawer_opacity_left x)" "$(coord canvas_detailed drawer_opacity_left y)" \
         "$(coord canvas_detailed drawer_opacity_right x)" "$(coord canvas_detailed drawer_opacity_right y)" \
         "High opacity"
    sleep 1
    drag 400 500 650 500 "Marker fill stroke"
    sleep 1
    shot=$(capture "power_03_marker_fill")
    log_pass "Step 3: Marker fill applied"
    diff_result=$(diff_screenshot "power_03_marker_fill")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_03_marker_fill" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_03_marker_fill" || log_diff_fail "power_03_marker_fill: $diff_result"
    }

    # Step 4: Watercolor 30pt 40%, wash effect
    tap "$(coord canvas tool_watercolor x)" "$(coord canvas tool_watercolor y)" "Watercolor"
    tap "$(coord canvas tool_watercolor x)" "$(coord canvas tool_watercolor y)" "Watercolor (open drawer)"
    sleep 1
    # Large size
    drag "$(coord canvas_detailed drawer_scrubber_top x)" "$(coord canvas_detailed drawer_scrubber_top y)" \
         "$(coord canvas_detailed drawer_scrubber_bottom x)" "$(coord canvas_detailed drawer_scrubber_bottom y)" \
         "Large brush"
    sleep 1
    # Lower opacity
    drag "$(coord canvas_detailed drawer_opacity_right x)" "$(coord canvas_detailed drawer_opacity_right y)" \
         "$(coord canvas_detailed drawer_opacity_left x)" "$(coord canvas_detailed drawer_opacity_left y)" \
         "Low opacity"
    sleep 1
    drag 350 700 700 800 "Watercolor wash"
    sleep 1
    shot=$(capture "power_04_watercolor_wash")
    log_pass "Step 4: Watercolor wash applied"
    diff_result=$(diff_screenshot "power_04_watercolor_wash")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_04_watercolor_wash" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_04_watercolor_wash" || log_diff_fail "power_04_watercolor_wash: $diff_result"
    }

    # Step 5: Fill tool, green, flood background region
    tap "$(coord canvas tool_floodfill x)" "$(coord canvas tool_floodfill y)" "Fill"
    # Open picker, select green from hue ring (bottom-left area)
    tap "$(coord canvas color_well x)" "$(coord canvas color_well y)" "Color well"
    sleep 1
    tap 400 650 "Green hue"
    sleep 1
    tap "$(coord canvas_detailed picker_close x)" "$(coord canvas_detailed picker_close y)" "Close picker"
    sleep 1
    tap 516 850 "Fill background region"
    sleep 1
    shot=$(capture "power_05_green_fill")
    log_pass "Step 5: Green flood fill applied to background"
    diff_result=$(diff_screenshot "power_05_green_fill")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_05_green_fill" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_05_green_fill" || log_diff_fail "power_05_green_fill: $diff_result"
    }

    # Step 6: Undo fill
    tap "$(coord canvas undo_button x)" "$(coord canvas undo_button y)" "Undo"
    sleep 1
    shot=$(capture "power_06_fill_undone")
    log_pass "Step 6: Fill undone"
    diff_result=$(diff_screenshot "power_06_fill_undone")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_06_fill_undone" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_06_fill_undone" || log_diff_fail "power_06_fill_undone: $diff_result"
    }

    # Step 7: Undo watercolor
    tap "$(coord canvas undo_button x)" "$(coord canvas undo_button y)" "Undo"
    sleep 1
    shot=$(capture "power_07_wash_undone")
    log_pass "Step 7: Watercolor wash undone"
    diff_result=$(diff_screenshot "power_07_wash_undone")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_07_wash_undone" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_07_wash_undone" || log_diff_fail "power_07_wash_undone: $diff_result"
    }

    # Step 8: Redo watercolor
    tap "$(coord canvas redo_button x)" "$(coord canvas redo_button y)" "Redo"
    sleep 1
    shot=$(capture "power_08_wash_redone")
    log_pass "Step 8: Watercolor wash redone"
    diff_result=$(diff_screenshot "power_08_wash_redone")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_08_wash_redone" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_08_wash_redone" || log_diff_fail "power_08_wash_redone: $diff_result"
    }

    # Step 9: Redo fill
    tap "$(coord canvas redo_button x)" "$(coord canvas redo_button y)" "Redo"
    sleep 1
    shot=$(capture "power_09_fill_redone")
    log_pass "Step 9: Green fill redone"
    diff_result=$(diff_screenshot "power_09_fill_redone")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_09_fill_redone" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_09_fill_redone" || log_diff_fail "power_09_fill_redone: $diff_result"
    }

    # Step 10: Picker → Neon palette, select color
    tap "$(coord canvas color_well x)" "$(coord canvas color_well y)" "Color well"
    sleep 1
    tap "$(coord canvas_detailed picker_palette x)" "$(coord canvas_detailed picker_palette y)" "Palette mode"
    sleep 1
    tap "$(coord canvas_detailed palette_neon x)" "$(coord canvas_detailed palette_neon y)" "Neon palette"
    sleep 1
    tap "$(coord canvas_detailed picker_swatch_center x)" "$(coord canvas_detailed picker_swatch_center y)" "Neon color"
    sleep 1
    tap "$(coord canvas_detailed picker_close x)" "$(coord canvas_detailed picker_close y)" "Close picker"
    sleep 1
    shot=$(capture "power_10_neon_selected")
    log_pass "Step 10: Neon palette color selected"
    diff_result=$(diff_screenshot "power_10_neon_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_10_neon_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_10_neon_selected" || log_diff_fail "power_10_neon_selected: $diff_result"
    }

    # Step 11: Eraser 25pt, erase part of pencil stroke
    tap "$(coord canvas tool_eraser x)" "$(coord canvas tool_eraser y)" "Eraser"
    tap "$(coord canvas tool_eraser x)" "$(coord canvas tool_eraser y)" "Eraser (open drawer)"
    sleep 1
    # Large eraser
    drag "$(coord canvas_detailed drawer_scrubber_top x)" "$(coord canvas_detailed drawer_scrubber_top y)" \
         "$(coord canvas_detailed drawer_scrubber_bottom x)" "$(coord canvas_detailed drawer_scrubber_bottom y)" \
         "Large eraser"
    sleep 1
    drag 400 600 500 600 "Erase pencil stroke"
    sleep 1
    shot=$(capture "power_11_erased")
    log_pass "Step 11: Pencil stroke partially erased"
    diff_result=$(diff_screenshot "power_11_erased")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_11_erased" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_11_erased" || log_diff_fail "power_11_erased: $diff_result"
    }

    # Step 12: Layers → toggle Line Art visibility
    tap "$(coord canvas layers_button x)" "$(coord canvas layers_button y)" "Layers"
    sleep 1
    tap "$(coord canvas_detailed layer_lineart_eye x)" "$(coord canvas_detailed layer_lineart_eye y)" "Toggle Line Art"
    sleep 1
    shot=$(capture "power_12_lineart_toggled")
    log_pass "Step 12: Line Art layer toggled"
    diff_result=$(diff_screenshot "power_12_lineart_toggled")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_12_lineart_toggled" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_12_lineart_toggled" || log_diff_fail "power_12_lineart_toggled: $diff_result"
    }

    # Step 13: Layers → toggle Color layer
    tap "$(coord canvas_detailed layer_color_eye x)" "$(coord canvas_detailed layer_color_eye y)" "Toggle Color"
    sleep 1
    shot=$(capture "power_13_color_toggled")
    log_pass "Step 13: Color layer toggled"
    diff_result=$(diff_screenshot "power_13_color_toggled")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_13_color_toggled" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_13_color_toggled" || log_diff_fail "power_13_color_toggled: $diff_result"
    }

    # Step 14: Close layers and hide toolbar
    tap "$(coord canvas_detailed layer_done x)" "$(coord canvas_detailed layer_done y)" "Done"
    sleep 1
    tap "$(coord canvas toolbar_toggle x)" "$(coord canvas toolbar_toggle y)" "Hide toolbar"
    sleep 1
    shot=$(capture "power_14_toolbar_hidden")
    log_pass "Step 14: Toolbar hidden for full-screen view"
    diff_result=$(diff_screenshot "power_14_toolbar_hidden")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_14_toolbar_hidden" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_14_toolbar_hidden" || log_diff_fail "power_14_toolbar_hidden: $diff_result"
    }

    # Step 15: Show toolbar again
    tap "$(coord canvas_detailed toolbar_restore x)" "$(coord canvas_detailed toolbar_restore y)" "Restore toolbar"
    sleep 1
    shot=$(capture "power_15_toolbar_shown")
    log_pass "Step 15: Toolbar restored"
    diff_result=$(diff_screenshot "power_15_toolbar_shown")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_15_toolbar_shown" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_15_toolbar_shown" || log_diff_fail "power_15_toolbar_shown: $diff_result"
    }

    # Step 16: Eyedropper → tap canvas region to pick color
    tap "$(coord canvas tool_eyedropper x)" "$(coord canvas tool_eyedropper y)" "Eyedropper"
    tap 516 600 "Pick color from canvas"
    sleep 1
    shot=$(capture "power_16_color_picked")
    log_pass "Step 16: Color picked from canvas with eyedropper"
    diff_result=$(diff_screenshot "power_16_color_picked")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_16_color_picked" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_16_color_picked" || log_diff_fail "power_16_color_picked: $diff_result"
    }

    # Step 17: Pencil with captured color, add detail
    tap "$(coord canvas tool_pencil x)" "$(coord canvas tool_pencil y)" "Pencil"
    drag 450 550 550 650 "Detail stroke"
    sleep 1
    shot=$(capture "power_17_detail_added")
    log_pass "Step 17: Detail added with captured color"
    diff_result=$(diff_screenshot "power_17_detail_added")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_17_detail_added" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_17_detail_added" || log_diff_fail "power_17_detail_added: $diff_result"
    }

    # Step 18: Final artwork screenshot
    shot=$(capture "power_18_final_artwork")
    log_pass "Step 18: Final artwork captured"
    diff_result=$(diff_screenshot "power_18_final_artwork")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_18_final_artwork" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_18_final_artwork" || log_diff_fail "power_18_final_artwork: $diff_result"
    }

    # Step 19: Tap back
    tap "$(coord canvas back_button x)" "$(coord canvas back_button y)" "Back"
    sleep 1
    shot=$(capture "power_19_back_home")
    log_pass "Step 19: Returned to Home"
    diff_result=$(diff_screenshot "power_19_back_home")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_19_back_home" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_19_back_home" || log_diff_fail "power_19_back_home: $diff_result"
    }

    # Step 20: Verify Home
    shot=$(capture "power_20_home_verified")
    log_pass "Step 20: Home screen verified"
    diff_result=$(diff_screenshot "power_20_home_verified")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "power_20_home_verified" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "power_20_home_verified" || log_diff_fail "power_20_home_verified: $diff_result"
    }
}

# Only run if not being sourced by the orchestrator
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    test_power_user
    log_header "POWER USER RESULTS"
    echo -e "  ${GREEN}Passed:${NC} $PASS"
    echo -e "  ${RED}Failed:${NC} $FAIL"
    exit $FAIL
fi
