#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT
DEVICES_JSON="$SCRIPT_DIR/devices.json"

OUTPUT_BASE="${PROJECT_ROOT}/Screenshots"
SCHEME="ColorFlow"
BUNDLE_ID="com.duckuwucky.sable"

usage() {
  cat <<USAGE
Usage: capture.sh [--output-dir PATH] [--scheme NAME]

Automated screenshot capture for Gouache App Store submission.

Options:
  --output-dir PATH    Output directory (default: ./Screenshots)
  --scheme NAME        Xcode scheme to build (default: ColorFlow)
  -h, --help          Show this help

Requirements:
  - Xcode 15.4+
  - iOS 18.0+ Simulator SDK
  - iPad Pro 12.9" and iPad 11" simulators
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_BASE="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

echo "🎨 Gouache Screenshot Capture Pipeline"
echo "======================================"
echo ""

command -v xcrun >/dev/null 2>&1 || { echo "Error: xcrun not found" >&2; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "Error: xcodebuild not found" >&2; exit 1; }

if [[ ! -f "$DEVICES_JSON" ]]; then
  echo "Error: devices.json not found at $DEVICES_JSON" >&2
  exit 1
fi

mkdir -p "$OUTPUT_BASE"

echo "📦 Building $SCHEME..."
cd "$PROJECT_ROOT"
./dev build >/dev/null 2>&1 || xcodebuild build -project ColorFlow.xcodeproj -scheme "$SCHEME" -sdk iphonesimulator -quiet

echo "✅ Build complete"
echo ""

TOTAL=$(python3 -c "import json; d=json.load(open('$DEVICES_JSON')); print(len(d['devices'])*len(d['orientations'])*len(d['screens']))")
CURRENT=0

echo "📸 Capturing $TOTAL screenshots..."
echo ""

# Export variables for Python script
export SCRIPT_DIR
export OUTPUT_BASE
export BUNDLE_ID
export DEVICES_JSON

python3 << PYTHON
import json
import subprocess
import sys
import os

script_dir = os.environ.get('SCRIPT_DIR', '.')
output_base = os.environ.get('OUTPUT_BASE', './Screenshots')
bundle_id = os.environ.get('BUNDLE_ID', 'com.duckuwucky.sable')
devices_json = os.environ.get('DEVICES_JSON', os.path.join(script_dir, 'devices.json'))

try:
    with open(devices_json) as f:
        config = json.load(f)
except FileNotFoundError:
    print(f"Error: devices.json not found at {devices_json}", file=sys.stderr)
    sys.exit(1)

total = len(config['devices']) * len(config['orientations']) * len(config['screens'])
current = 0

for device in config['devices']:
    for orientation in config['orientations']:
        for screen in config['screens']:
            current += 1
            
            print(f"\n[{current}/{total}] {device['name']} - {orientation['name']} - {screen['name']}")
            
            output_dir = os.path.join(output_base, device['outputDir'], orientation['name'])
            
            result = subprocess.run([
                os.path.join(script_dir, 'capture_single.sh'),
                '--bundle-id', bundle_id,
                '--sim-name', device['simulatorName'],
                '--orientation', orientation['simctlValue'],
                '--test-method', screen['testMethod'],
                '--output-dir', output_dir,
                '--output-name', screen['name'] + '.png'
            ], capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"  ⚠️  Failed: {result.stderr}", file=sys.stderr)
            else:
                print(f"  ✅ Saved to {output_dir}/{screen['name']}.png")

print("\n🎉 Screenshot capture complete!")
print(f"Output directory: {output_base}")
PYTHON
