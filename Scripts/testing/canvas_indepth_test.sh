#!/usr/bin/env bash
# canvas_indepth_test.sh — Master orchestrator for in-depth canvas tests
# Runs all 4 persona test suites with baseline recording or comparison.
#
# Usage:
#   ./Scripts/testing/canvas_indepth_test.sh --record-baselines   # Record baselines
#   ./Scripts/testing/canvas_indepth_test.sh all                  # Run all with comparison
#   ./Scripts/testing/canvas_indepth_test.sh casual               # Run single persona

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCREENSHOT_DIR="$SCRIPT_DIR/.screenshots"
BASELINE_DIR="$SCRIPT_DIR/baselines"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_DIFF_PASS=0
TOTAL_DIFF_FAIL=0
TOTAL_NO_BASELINE=0

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass()    { echo -e "${GREEN}[PASS]${NC} $*"; ((TOTAL_PASS++)) || true; }
log_fail()    { echo -e "${RED}[FAIL]${NC} $*"; ((TOTAL_FAIL++)) || true; }
log_diff_pass() { echo -e "${GREEN}[DIFF PASS]${NC} $*"; ((TOTAL_DIFF_PASS++)) || true; }
log_diff_fail() { echo -e "${RED}[DIFF FAIL]${NC} $*"; ((TOTAL_DIFF_FAIL++)) || true; }
log_no_baseline() { echo -e "${YELLOW}[NO BASELINE]${NC} $*"; ((TOTAL_NO_BASELINE++)) || true; }
log_header()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}$*${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Run a persona test script and collect results
run_persona() {
    local script="$1"
    local label="$2"
    local mode="${3:-test}"  # "test" or "record"

    log_header "$label"

    if [ ! -f "$script" ]; then
        log_fail "Script not found: $script"
        return 1
    fi

    chmod +x "$script"

    # Run in subshell and capture output + exit code
    local output
    output=$(CANVAS_TEST_MODE="$mode" bash "$script" 2>&1)
    local exit_code=$?

    # Print output
    echo "$output"

    # Extract counts from output (strip ANSI codes first)
    local clean_output
    clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    local p f
    p=$(echo "$clean_output" | grep 'Passed:' | tail -1 | sed 's/.*Passed:[[:space:]]*//' | tr -d '[:space:]') || p=0
    f=$(echo "$clean_output" | grep 'Failed:' | tail -1 | sed 's/.*Failed:[[:space:]]*//' | tr -d '[:space:]') || f=0
    TOTAL_PASS=$((TOTAL_PASS + ${p:-0}))
    TOTAL_FAIL=$((TOTAL_FAIL + ${f:-0}))

    # Count diff results from output
    local dp df nb
    dp=$(echo "$output" | grep -c '\[DIFF PASS\]') || dp=0
    df=$(echo "$output" | grep -c '\[DIFF FAIL\]') || df=0
    nb=$(echo "$output" | grep -c '\[NO BASELINE\]') || nb=0
    TOTAL_DIFF_PASS=$((TOTAL_DIFF_PASS + dp))
    TOTAL_DIFF_FAIL=$((TOTAL_DIFF_FAIL + df))
    TOTAL_NO_BASELINE=$((TOTAL_NO_BASELINE + nb))

    if [ $exit_code -ne 0 ]; then
        log_fail "$label exited with code $exit_code"
    fi

    return $exit_code
}

# Copy all screenshots to baselines directory
record_baselines() {
    log_header "RECORDING BASELINES"
    mkdir -p "$BASELINE_DIR"

    # Find the latest timestamp from canvas test screenshots
    local latest_ts
    latest_ts=$(ls -1t "$SCREENSHOT_DIR"/casual_*.png "$SCREENSHOT_DIR"/detail_*.png "$SCREENSHOT_DIR"/exp_*.png "$SCREENSHOT_DIR"/power_*.png 2>/dev/null | head -1 | sed 's/.*\///' | cut -d'_' -f1,2)

    if [ -z "$latest_ts" ]; then
        log_info "No canvas test screenshots found"
        return 0
    fi

    local count=0
    for shot in "$SCREENSHOT_DIR"/${latest_ts}_*.png; do
        [ -f "$shot" ] || continue
        local basename
        basename=$(basename "$shot" | sed "s/^${latest_ts}_//")
        cp "$shot" "$BASELINE_DIR/$basename"
        echo -e "  ${GREEN}→${NC} $basename"
        ((count++)) || true
    done

    log_info "Recorded $count baseline screenshots to $BASELINE_DIR/"
}

# Main
main() {
    local mode="${1:-all}"

    log_header "ColorFlow Canvas In-Depth Test Runner"
    log_info "Mode: $mode"
    log_info "Screenshots: $SCREENSHOT_DIR/"
    log_info "Baselines: $BASELINE_DIR/"

    mkdir -p "$SCREENSHOT_DIR" "$BASELINE_DIR"

    case "$mode" in
        --record-baselines)
            run_persona "$SCRIPT_DIR/canvas_casual_test.sh" "Persona 1: Casual Colorist" "record" || true
            run_persona "$SCRIPT_DIR/canvas_detail_test.sh" "Persona 2: Detail Artist" "record" || true
            run_persona "$SCRIPT_DIR/canvas_experimental_test.sh" "Persona 3: Experimental User" "record" || true
            run_persona "$SCRIPT_DIR/canvas_power_test.sh" "Persona 4: Power User" "record" || true
            record_baselines
            ;;
        casual)
            run_persona "$SCRIPT_DIR/canvas_casual_test.sh" "Persona 1: Casual Colorist"
            ;;
        detail)
            run_persona "$SCRIPT_DIR/canvas_detail_test.sh" "Persona 2: Detail Artist"
            ;;
        experimental)
            run_persona "$SCRIPT_DIR/canvas_experimental_test.sh" "Persona 3: Experimental User"
            ;;
        power)
            run_persona "$SCRIPT_DIR/canvas_power_test.sh" "Persona 4: Power User"
            ;;
        all)
            run_persona "$SCRIPT_DIR/canvas_casual_test.sh" "Persona 1: Casual Colorist" || true
            run_persona "$SCRIPT_DIR/canvas_detail_test.sh" "Persona 2: Detail Artist" || true
            run_persona "$SCRIPT_DIR/canvas_experimental_test.sh" "Persona 3: Experimental User" || true
            run_persona "$SCRIPT_DIR/canvas_power_test.sh" "Persona 4: Power User" || true
            ;;
        *)
            echo "Usage: $0 {--record-baselines|all|casual|detail|experimental|power}"
            exit 1
            ;;
    esac

    log_header "FINAL RESULTS"
    echo -e "  ${GREEN}Steps Passed:${NC} $TOTAL_PASS"
    echo -e "  ${RED}Steps Failed:${NC} $TOTAL_FAIL"
    echo -e "  ${GREEN}Pixel-Diff Pass:${NC} $TOTAL_DIFF_PASS"
    echo -e "  ${RED}Pixel-Diff Fail:${NC} $TOTAL_DIFF_FAIL"
    echo -e "  ${YELLOW}No Baseline:${NC} $TOTAL_NO_BASELINE"
    echo ""
    echo "Screenshots saved to: $SCREENSHOT_DIR/"
    echo "Latest: $(ls -t "$SCREENSHOT_DIR"/*.png 2>/dev/null | head -1)"

    if [ "$TOTAL_FAIL" -gt 0 ] || [ "$TOTAL_DIFF_FAIL" -gt 0 ]; then
        exit 1
    fi
}

main "$@"
