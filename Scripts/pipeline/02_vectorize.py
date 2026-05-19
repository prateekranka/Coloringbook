#!/usr/bin/env python3
"""
02_vectorize.py — Batch raster-to-SVG vectorization using VTracer.

Converts PNG raster images (AI-generated coloring-book line art) into
SVG files using VTracer in spline mode. VTracer in this mode produces
cubic Bézier paths only — no arc commands — which satisfies the
ColorFlow SVG spec (docs/svg-template-spec.md).

Usage:
    python3 Scripts/pipeline/02_vectorize.py \
        --input  pipeline_work/01_rasters/ \
        --output pipeline_work/02_vectors/ \
        [--vtracer PATH_TO_VTRACER_BINARY] \
        [--filter-speckle N]    # drop paths with area < N px² (default 4)
        [--color-precision N]   # color quantization levels 1–8 (default 6)
        [--layer-difference N]  # gradient step / stacking threshold (default 16)
        [--path-precision N]    # decimal places for SVG coords (default 8)

Prerequisites:
    - VTracer binary installed: cargo install vtracer
      or download from https://github.com/visioncortex/vtracer/releases
    - PIL: pip install Pillow

VTracer settings used:
    --colormode bw              → black-and-white output (line-art only)
    --mode spline               → cubic Bézier paths (no arc commands)
    --hierarchical stacked      → paths stacked by z-order; each closed region
                                  is a separate <path> element
    --filter_speckle N          → removes small noise blobs
    --path_precision N          → keeps file size reasonable

Output per image:
    - One SVG file in --output matching the input filename stem.
    - A JSON sidecar file (<stem>.vtracer.json) with metadata:
      path_count, file_size_bytes, elapsed_seconds, vtracer_version.

On failure (non-zero VTracer exit):
    - Error is logged to stderr.
    - A <stem>.error.txt file is written so the batch doesn't stop.
    - Exit code 1 if any failures occurred.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import tempfile
from pathlib import Path

try:
    from PIL import Image, ImageOps
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

try:
    from tqdm import tqdm
    TQDM_AVAILABLE = True
except ImportError:
    TQDM_AVAILABLE = False

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

def check_image_quality(img_path: Path) -> list[str]:
    """
    Return a list of warning strings for an input image. Does not block
    processing — warnings are logged for human review.
    """
    if not PIL_AVAILABLE:
        return []

    warnings: list[str] = []
    try:
        img = Image.open(img_path).convert("L")  # grayscale
        w, h = img.size

        if w < 512 or h < 512:
            warnings.append(f"Low resolution ({w}x{h}). Recommend ≥1024×1024 for clean vectorization.")

        # Simple average brightness check — very dark or very bright images
        # won't vectorize well as line-art.
        pixels = list(img.getdata())
        avg = sum(pixels) / len(pixels)
        if avg < 30:
            warnings.append(f"Image is very dark (avg brightness {avg:.0f}/255). May produce few regions.")
        elif avg > 240:
            warnings.append(f"Image is very bright (avg brightness {avg:.0f}/255). May produce few regions.")

    except Exception as exc:
        warnings.append(f"Could not analyze image: {exc}")

    return warnings


def prepare_white_region_trace_image(img_path: Path, output_dir: Path, threshold: int) -> Path:
    """
    Convert black-on-white line art into an inverted binary mask for VTracer.

    VTracer traces dark islands. For coloring-book source art, the useful
    islands are the enclosed white cells, not the black ink strokes. Threshold
    first, then invert so VTracer emits one path per fillable region.
    """
    if not PIL_AVAILABLE:
        raise RuntimeError("Pillow is required for --trace-white-regions")

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / img_path.name
    image = Image.open(img_path).convert("L")
    binary = image.point(lambda value: 255 if value > threshold else 0).convert("L")
    ImageOps.invert(binary).save(output_path)
    return output_path


# ---------------------------------------------------------------------------
# VTracer invocation
# ---------------------------------------------------------------------------

def find_vtracer(override: str | None) -> str:
    """Return the path to the vtracer binary, or raise if not found."""
    if override:
        return override

    # Common install locations
    candidates = ["vtracer", "/usr/local/bin/vtracer", str(Path.home() / ".cargo/bin/vtracer")]
    for c in candidates:
        try:
            result = subprocess.run(
                [c, "--version"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                return c
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue

    raise RuntimeError(
        "vtracer binary not found. Install with: cargo install vtracer\n"
        "Or download from: https://github.com/visioncortex/vtracer/releases\n"
        "Then pass --vtracer /path/to/vtracer"
    )


def vectorize_one(
    vtracer: str,
    input_path: Path,
    output_path: Path,
    mode: str,
    filter_speckle: int,
    color_precision: int,
    layer_difference: int,
    path_precision: int,
) -> tuple[bool, dict]:
    """
    Run VTracer on a single image. Returns (success, metadata_dict).
    """
    cmd = [
        vtracer,
        "--input",  str(input_path),
        "--output", str(output_path),
        "--colormode",       "bw",
        "--mode",            mode,
        "--hierarchical",    "stacked",
        "--filter_speckle",  str(filter_speckle),
        "--color_precision", str(color_precision),
        "--gradient_step",   str(layer_difference),
        "--path_precision",  str(path_precision),
    ]

    start = time.monotonic()
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
        )
        elapsed = time.monotonic() - start
        success = (result.returncode == 0) and output_path.exists()

        metadata = {
            "input": str(input_path),
            "output": str(output_path),
            "mode": mode,
            "elapsed_seconds": round(elapsed, 2),
            "vtracer_exit_code": result.returncode,
            "vtracer_stdout": result.stdout.strip(),
            "vtracer_stderr": result.stderr.strip(),
        }

        if success:
            metadata["file_size_bytes"] = output_path.stat().st_size
            # Count path elements as a quick complexity proxy.
            svg_text = output_path.read_text(encoding="utf-8", errors="replace")
            metadata["path_count"] = svg_text.count("<path")

        return success, metadata

    except subprocess.TimeoutExpired:
        return False, {
            "input": str(input_path),
            "error": "VTracer timed out after 120 seconds",
        }
    except Exception as exc:
        return False, {
            "input": str(input_path),
            "error": str(exc),
        }


# ---------------------------------------------------------------------------
# Batch runner
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",  required=True,  help="Directory of input PNG files")
    parser.add_argument("--output", required=True,  help="Directory for output SVG files")
    parser.add_argument("--vtracer", default=None,  help="Path to vtracer binary (default: auto-detect)")
    parser.add_argument("--mode", choices=["spline", "polygon", "pixel"], default="spline")
    parser.add_argument("--filter-speckle",   type=int, default=4,  metavar="N")
    parser.add_argument("--color-precision",  type=int, default=6,  metavar="N")
    parser.add_argument("--layer-difference", type=int, default=16, metavar="N")
    parser.add_argument("--path-precision",   type=int, default=8,  metavar="N")
    parser.add_argument(
        "--trace-white-regions",
        action="store_true",
        help="For black line art on white paper, trace enclosed white cells instead of ink strokes.",
    )
    parser.add_argument(
        "--region-threshold",
        type=int,
        default=210,
        metavar="0-255",
        help="Threshold used with --trace-white-regions (default: 210).",
    )
    args = parser.parse_args(argv)

    input_dir  = Path(args.input)
    output_dir = Path(args.output)

    if not input_dir.is_dir():
        print(f"ERROR: Input directory '{input_dir}' does not exist.", file=sys.stderr)
        return 1
    if args.trace_white_regions and not PIL_AVAILABLE:
        print("ERROR: --trace-white-regions requires Pillow. Run: pip install -r Scripts/requirements.txt", file=sys.stderr)
        return 1
    if not 0 <= args.region_threshold <= 255:
        print("ERROR: --region-threshold must be between 0 and 255.", file=sys.stderr)
        return 1

    output_dir.mkdir(parents=True, exist_ok=True)

    # Locate vtracer
    try:
        vtracer = find_vtracer(args.vtracer)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    # Collect input images
    inputs = sorted(input_dir.glob("*.png")) + sorted(input_dir.glob("*.jpg")) + sorted(input_dir.glob("*.jpeg"))
    if not inputs:
        print(f"ERROR: No PNG/JPG images found in '{input_dir}'.", file=sys.stderr)
        return 1

    print(f"Found {len(inputs)} image(s) in '{input_dir}'.")
    print(f"VTracer: {vtracer}")
    print(f"Output:  {output_dir}")
    print()

    pass_count = 0
    fail_count = 0
    all_metadata: list[dict] = []

    iterator = tqdm(inputs) if TQDM_AVAILABLE else inputs
    temp_context = tempfile.TemporaryDirectory(prefix="gouache_region_trace_") if args.trace_white_regions else None
    try:
        region_trace_dir = Path(temp_context.name) if temp_context else None
        for img_path in iterator:
            stem = img_path.stem
            output_svg  = output_dir / f"{stem}.svg"
            sidecar     = output_dir / f"{stem}.vtracer.json"
            error_file  = output_dir / f"{stem}.error.txt"

            # Pre-flight quality warnings
            warnings = check_image_quality(img_path)
            for w in warnings:
                print(f"  WARN  {img_path.name}: {w}", file=sys.stderr)

            vector_input = img_path
            if args.trace_white_regions:
                try:
                    vector_input = prepare_white_region_trace_image(
                        img_path,
                        region_trace_dir or output_dir,
                        args.region_threshold,
                    )
                except Exception as exc:
                    fail_count += 1
                    error_file.write_text(str(exc) + "\n", encoding="utf-8")
                    print(f"  ✗  {stem}: {exc}", file=sys.stderr)
                    continue

            success, metadata = vectorize_one(
                vtracer,
                vector_input,
                output_svg,
                args.mode,
                args.filter_speckle,
                args.color_precision,
                args.layer_difference,
                args.path_precision,
            )

            if args.trace_white_regions:
                metadata["original_input"] = str(img_path)
                metadata["vectorized_input"] = str(vector_input)
                metadata["trace_mode"] = "white-regions"
                metadata["region_threshold"] = args.region_threshold

            metadata["quality_warnings"] = warnings
            all_metadata.append(metadata)
            sidecar.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

            if success:
                pass_count += 1
                path_count = metadata.get("path_count", "?")
                size_kb    = metadata.get("file_size_bytes", 0) // 1024
                elapsed    = metadata.get("elapsed_seconds", 0)
                print(f"  ✓  {stem}.svg  ({path_count} paths, {size_kb} KB, {elapsed:.1f}s)")

                # Hard limit check — flag for human review, don't delete.
                if isinstance(path_count, int) and path_count > 300:
                    review_flag = output_dir / f"{stem}.review_needed.txt"
                    review_flag.write_text(
                        f"Path count ({path_count}) exceeds the recommended limit of 300.\n"
                        "Review in Inkscape and simplify before running 03_postprocess.py.\n",
                        encoding="utf-8",
                    )
                    print(f"  ⚠️   Flagged for review: {path_count} paths > 300", file=sys.stderr)
            else:
                fail_count += 1
                error_msg = metadata.get("error") or metadata.get("vtracer_stderr") or "Unknown error"
                error_file.write_text(f"VTracer failed for {img_path.name}:\n{error_msg}\n", encoding="utf-8")
                print(f"  ✗  {stem}: {error_msg}", file=sys.stderr)
    finally:
        if temp_context:
            temp_context.cleanup()

    # Summary JSON
    summary = {
        "total": len(inputs),
        "passed": pass_count,
        "failed": fail_count,
        "files": all_metadata,
    }
    summary_path = output_dir / "_batch_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print()
    print(f"Results: {pass_count}/{len(inputs)} vectorized successfully.")
    if fail_count:
        print(f"  {fail_count} failure(s) — see *.error.txt in {output_dir}")
    print(f"Summary written to: {summary_path}")

    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
