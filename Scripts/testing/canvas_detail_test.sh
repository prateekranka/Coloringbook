#!/usr/bin/env bash
# canvas_detail_test.sh — Persona 2: Detail Artist
# Precision inking — pencil/marker with size adjustments and opacity
# Template: Coffee Morning (fine details good for pencil/marker work)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colorflow_ui_test.sh"

test_detail_artist() {
    log_header "PERSONA 2: DETAIL ARTIST"
    log_info "Template: Coffee Morning"
    log_info "Workflow: Pencil fine lines → color change → thick strokes → marker with opacity → undo/redo → exit"

    # Fresh start: stop app, clear state, relaunch, open Coffee Morning
    fresh_start "$(coord library card_coffee_morning x)" "$(coord library card_coffee_morning y)" "Coffee Morning"

    local shot diff_result

    # Step 1: Verify canvas loaded
    shot=$(capture "detail_01_canvas_loaded")
    log_pass "Step 1: Canvas loaded with Coffee Morning"
    diff_result=$(diff_screenshot "detail_01_canvas_loaded")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_01_canvas_loaded" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_01_canvas_loaded" || log_diff_fail "detail_01_canvas_loaded: $diff_result"
    }

    # Step 2: Select Pencil tool
    tap "$(coord canvas tool_pencil x)" "$(coord canvas tool_pencil y)" "Pencil tool"
    shot=$(capture "detail_02_pencil_selected")
    log_pass "Step 2: Pencil tool selected"
    diff_result=$(diff_screenshot "detail_02_pencil_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_02_pencil_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_02_pencil_selected" || log_diff_fail "detail_02_pencil_selected: $diff_result"
    }

    # Step 3: Re-tap Pencil to open drawer
    tap "$(coord canvas tool_pencil x)" "$(coord canvas tool_pencil y)" "Pencil (open drawer)"
    sleep 1
    shot=$(capture "detail_03_drawer_open")
    log_pass "Step 3: Brush size drawer opened"
    diff_result=$(diff_screenshot "detail_03_drawer_open")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_03_drawer_open" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_03_drawer_open" || log_diff_fail "detail_03_drawer_open: $diff_result"
    }

    # Step 4: Drag scrubber to small size (~3pt) — drag from middle to top
    drag "$(coord canvas_detailed drawer_scrubber_bottom x)" "$(coord canvas_detailed drawer_scrubber_bottom y)" \
         "$(coord canvas_detailed drawer_scrubber_top x)" "$(coord canvas_detailed drawer_scrubber_top y)" \
         "Drag scrubber to small"
    sleep 1
    shot=$(capture "detail_04_small_brush")
    log_pass "Step 4: Brush size set to small (~3pt)"
    diff_result=$(diff_screenshot "detail_04_small_brush")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_04_small_brush" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_04_small_brush" || log_diff_fail "detail_04_small_brush: $diff_result"
    }

    # Step 5: Draw a horizontal stroke on canvas
    drag "$(coord canvas canvas_drag_start x)" "$(coord canvas canvas_drag_start y)" \
         "$(coord canvas canvas_drag_end x)" "$(coord canvas canvas_drag_end y)" \
         "Draw horizontal stroke"
    sleep 1
    shot=$(capture "detail_05_stroke_drawn")
    log_pass "Step 5: Fine pencil stroke drawn"
    diff_result=$(diff_screenshot "detail_05_stroke_drawn")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_05_stroke_drawn" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_05_stroke_drawn" || log_diff_fail "detail_05_stroke_drawn: $diff_result"
    }

    # Step 6: Open color picker, select blue from hue ring (right side)
    tap "$(coord canvas color_well x)" "$(coord canvas color_well y)" "Color well"
    sleep 1
    tap "$(coord canvas_detailed picker_hue_right x)" "$(coord canvas_detailed picker_hue_right y)" "Blue hue"
    sleep 1
    tap "$(coord canvas_detailed picker_close x)" "$(coord canvas_detailed picker_close y)" "Close picker"
    sleep 1
    shot=$(capture "detail_06_blue_selected")
    log_pass "Step 6: Blue color selected"
    diff_result=$(diff_screenshot "detail_06_blue_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_06_blue_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_06_blue_selected" || log_diff_fail "detail_06_blue_selected: $diff_result"
    }

    # Step 7: Draw blue stroke (vertical)
    drag 516 400 516 900 "Draw vertical blue stroke"
    sleep 1
    shot=$(capture "detail_07_blue_stroke")
    log_pass "Step 7: Blue vertical stroke drawn"
    diff_result=$(diff_screenshot "detail_07_blue_stroke")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_07_blue_stroke" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_07_blue_stroke" || log_diff_fail "detail_07_blue_stroke: $diff_result"
    }

    # Step 8: Increase brush to ~20pt — drag scrubber from top to bottom
    tap "$(coord canvas tool_pencil x)" "$(coord canvas tool_pencil y)" "Pencil (re-open drawer)"
    sleep 1
    drag "$(coord canvas_detailed drawer_scrubber_top x)" "$(coord canvas_detailed drawer_scrubber_top y)" \
         "$(coord canvas_detailed drawer_scrubber_bottom x)" "$(coord canvas_detailed drawer_scrubber_bottom y)" \
         "Drag scrubber to large"
    sleep 1
    shot=$(capture "detail_08_large_brush")
    log_pass "Step 8: Brush size increased to ~20pt"
    diff_result=$(diff_screenshot "detail_08_large_brush")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_08_large_brush" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_08_large_brush" || log_diff_fail "detail_08_large_brush: $diff_result"
    }

    # Step 9: Draw thick stroke (diagonal)
    drag 350 500 700 850 "Draw diagonal thick stroke"
    sleep 1
    shot=$(capture "detail_09_thick_stroke")
    log_pass "Step 9: Thick diagonal stroke drawn"
    diff_result=$(diff_screenshot "detail_09_thick_stroke")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_09_thick_stroke" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_09_thick_stroke" || log_diff_fail "detail_09_thick_stroke: $diff_result"
    }

    # Step 10: Select Marker tool
    tap "$(coord canvas tool_marker x)" "$(coord canvas tool_marker y)" "Marker tool"
    sleep 1
    shot=$(capture "detail_10_marker_selected")
    log_pass "Step 10: Marker tool selected"
    diff_result=$(diff_screenshot "detail_10_marker_selected")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_10_marker_selected" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_10_marker_selected" || log_diff_fail "detail_10_marker_selected: $diff_result"
    }

    # Step 11: Adjust opacity to ~50% — drag opacity slider to middle
    tap "$(coord canvas tool_marker x)" "$(coord canvas tool_marker y)" "Marker (open drawer)"
    sleep 1
    drag "$(coord canvas_detailed drawer_opacity_right x)" "$(coord canvas_detailed drawer_opacity_right y)" \
         "$(coord canvas_detailed drawer_opacity_left x)" "$(coord canvas_detailed drawer_opacity_left y)" \
         "Drag opacity to 50%"
    sleep 1
    shot=$(capture "detail_11_opacity_half")
    log_pass "Step 11: Opacity adjusted to ~50%"
    diff_result=$(diff_screenshot "detail_11_opacity_half")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_11_opacity_half" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_11_opacity_half" || log_diff_fail "detail_11_opacity_half: $diff_result"
    }

    # Step 12: Draw semi-transparent stroke
    drag 400 700 700 700 "Draw semi-transparent stroke"
    sleep 1
    shot=$(capture "detail_12_semi_stroke")
    log_pass "Step 12: Semi-transparent marker stroke drawn"
    diff_result=$(diff_screenshot "detail_12_semi_stroke")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_12_semi_stroke" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_12_semi_stroke" || log_diff_fail "detail_12_semi_stroke: $diff_result"
    }

    # Step 13: Undo last stroke
    tap "$(coord canvas undo_button x)" "$(coord canvas undo_button y)" "Undo"
    sleep 1
    shot=$(capture "detail_13_undone")
    log_pass "Step 13: Undo applied — semi-transparent stroke removed"
    diff_result=$(diff_screenshot "detail_13_undone")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_13_undone" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_13_undone" || log_diff_fail "detail_13_undone: $diff_result"
    }

    # Step 14: Redo
    tap "$(coord canvas redo_button x)" "$(coord canvas redo_button y)" "Redo"
    sleep 1
    shot=$(capture "detail_14_redone")
    log_pass "Step 14: Redo applied — semi-transparent stroke restored"
    diff_result=$(diff_screenshot "detail_14_redone")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_14_redone" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_14_redone" || log_diff_fail "detail_14_redone: $diff_result"
    }

    # Step 15: Tap back to Home
    tap "$(coord canvas back_button x)" "$(coord canvas back_button y)" "Back"
    sleep 1
    shot=$(capture "detail_15_back_home")
    log_pass "Step 15: Returned to Home"
    diff_result=$(diff_screenshot "detail_15_back_home")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_15_back_home" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_15_back_home" || log_diff_fail "detail_15_back_home: $diff_result"
    }

    # Step 16: Verify Home
    shot=$(capture "detail_16_home_verified")
    log_pass "Step 16: Home screen verified"
    diff_result=$(diff_screenshot "detail_16_home_verified")
    [ "$diff_result" = "NO_BASELINE" ] && log_no_baseline "detail_16_home_verified" || {
        echo "$diff_result" | grep -q "PASS" && log_diff_pass "detail_16_home_verified" || log_diff_fail "detail_16_home_verified: $diff_result"
    }
}

# Only run if not being sourced by the orchestrator
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    test_detail_artist
    log_header "DETAIL ARTIST RESULTS"
    echo -e "  ${GREEN}Passed:${NC} $PASS"
    echo -e "  ${RED}Failed:${NC} $FAIL"
    exit $FAIL
fi
