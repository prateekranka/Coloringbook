#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FLOW="all"
THEME="all"
ORIENTATION="all"
OUTDIR="artifacts/gouache-verification-$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'USAGE'
Usage: Scripts/record_verification_matrix.sh [--flow NAME|all] [--theme light|dark|all] [--orientation portrait|landscape|all] [--outdir DIR]

Flows:
  canvas-fast-coloring
  canvas-zoom-stress
  high-resolution-template-zoom
  focus-mode
  home
  library-masonry
  profile-theme
  all
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flow)
      FLOW="$2"; shift 2 ;;
    --theme)
      THEME="$2"; shift 2 ;;
    --orientation)
      ORIENTATION="$2"; shift 2 ;;
    --outdir)
      OUTDIR="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

case "$THEME" in
  light) THEMES=(light) ;;
  dark) THEMES=(dark) ;;
  all) THEMES=(light dark) ;;
  *) echo "Invalid theme: $THEME" >&2; exit 2 ;;
esac

case "$ORIENTATION" in
  portrait) ORIENTATIONS=(portrait) ;;
  landscape) ORIENTATIONS=(landscape) ;;
  all) ORIENTATIONS=(portrait landscape) ;;
  *) echo "Invalid orientation: $ORIENTATION" >&2; exit 2 ;;
esac

test_for_flow() {
  case "$1" in
    canvas-fast-coloring) echo "VerificationRecordingUITests/test_recordCanvasFastColoring" ;;
    canvas-zoom-stress) echo "VerificationRecordingUITests/test_recordCanvasZoomStress" ;;
    high-resolution-template-zoom) echo "VerificationRecordingUITests/test_recordHighResolutionTemplateZoom" ;;
    focus-mode) echo "VerificationRecordingUITests/test_recordFocusMode" ;;
    home) echo "VerificationRecordingUITests/test_recordHomeFlow" ;;
    library-masonry) echo "VerificationRecordingUITests/test_recordLibraryMasonry" ;;
    profile-theme) echo "VerificationRecordingUITests/test_recordProfileAndTheme" ;;
    *) return 1 ;;
  esac
}

normalize_landscape_recording() {
  local orientation="$1"
  local video="$2"
  [[ "$orientation" == "landscape" ]] || return 0
  command -v ffmpeg >/dev/null 2>&1 || return 0

  local tmp="${video%.mp4}.normalized.mp4"
  ffmpeg -hide_banner -loglevel error -y \
    -i "$video" \
    -vf "transpose=2" \
    -metadata:s:v rotate=0 \
    -movflags +faststart \
    "$tmp"
  mv "$tmp" "$video"
}

if [[ "$FLOW" == "all" ]]; then
  FLOWS=(
    canvas-fast-coloring
    canvas-zoom-stress
    high-resolution-template-zoom
    focus-mode
    home
    library-masonry
    profile-theme
  )
elif test_for_flow "$FLOW" >/dev/null; then
  FLOWS=("$FLOW")
else
  echo "Invalid flow: $FLOW" >&2
  usage
  exit 2
fi

DESTINATION="$(Scripts/resolve_sim_destination.sh)"
UDID="${DESTINATION##*id=}"
CONFIG_FILE=".gouache-recording-config"
mkdir -p "$OUTDIR/logs"
cleanup() {
  rm -f "$CONFIG_FILE"
}
trap cleanup EXIT

echo "[record] Building app before recording..."
xcodebuild build-for-testing \
  -project ColorFlow.xcodeproj \
  -scheme ColorFlow \
  -destination "$DESTINATION" \
  -configuration Debug \
  >"$OUTDIR/logs/build-for-testing.log" 2>&1

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

for flow in "${FLOWS[@]}"; do
  test_name="$(test_for_flow "$flow")"
  for theme in "${THEMES[@]}"; do
    for orientation in "${ORIENTATIONS[@]}"; do
      stem="${flow}-${orientation}-${theme}"
      video="$OUTDIR/${stem}.mp4"
      log="$OUTDIR/logs/${stem}.log"
      echo "[record] $stem"

      xcrun simctl ui "$UDID" appearance "$theme" >/dev/null 2>&1 || true
      {
        echo "theme=$theme"
        echo "orientation=$orientation"
      } >"$CONFIG_FILE"
      xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$video" >"$OUTDIR/logs/${stem}.record.log" 2>&1 &
      recorder_pid=$!

      set +e
      xcodebuild test-without-building \
        -project ColorFlow.xcodeproj \
        -scheme ColorFlow \
        -destination "$DESTINATION" \
        -only-testing:"ColorFlowUITests/$test_name" \
        -configuration Debug \
        >"$log" 2>&1
      test_status=$?
      set -e

      sleep 1
      kill -INT "$recorder_pid" >/dev/null 2>&1 || true
      wait "$recorder_pid" >/dev/null 2>&1 || true

      if [[ $test_status -ne 0 ]]; then
        echo "[record] FAILED: $stem (see $log)" >&2
        exit "$test_status"
      fi

      if grep -q "Test skipped" "$log"; then
        echo "[record] FAILED: $stem was skipped (see $log)" >&2
        exit 1
      fi

      normalize_landscape_recording "$orientation" "$video"
    done
  done
done

echo "[record] Videos written to $OUTDIR"
