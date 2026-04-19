#!/usr/bin/env python3
"""
convert_informative_drawings.py
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Convert the carolineec/informative-drawings PyTorch model to CoreML format
for on-device inference in ColorFlow.

See Scripts/coreml/README.md for the full conversion runbook.

Prerequisites (install in a venv):
    pip install torch torchvision coremltools Pillow

Usage:
    python3 Scripts/coreml/convert_informative_drawings.py \
        --weights path/to/model.pth \
        --output  ColorFlow/Resources/Models/InformativeDrawings.mlpackage

The script compiles the .mlpackage to .mlmodelc in-place unless --no-compile is set.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def convert(weights_path: Path, output_path: Path, input_size: int, compile: bool) -> None:
    try:
        import torch
        import coremltools as ct
    except ImportError as e:
        print(f"ERROR: Missing dependency — {e}")
        print("Install with: pip install torch torchvision coremltools")
        sys.exit(1)

    print(f"Loading weights from: {weights_path}")

    # ── Import the model architecture ────────────────────────────────────────
    # The informative-drawings repo must be cloned alongside this script,
    # or its src/ directory must be on PYTHONPATH.
    try:
        sys.path.insert(0, str(Path(__file__).parent / "informative-drawings"))
        from model import Generator  # type: ignore
    except ImportError:
        print(
            "ERROR: Cannot import 'model.Generator'.\n"
            "Clone carolineec/informative-drawings next to this script:\n"
            "  git clone https://github.com/carolineec/informative-drawings.git Scripts/coreml/informative-drawings"
        )
        sys.exit(1)

    # ── Load model ────────────────────────────────────────────────────────────
    model = Generator(3, 1, 3)  # in_channels, out_channels, n_blocks
    state = torch.load(weights_path, map_location="cpu")
    model.load_state_dict(state)
    model.eval()

    # ── Trace ─────────────────────────────────────────────────────────────────
    example = torch.randn(1, 3, input_size, input_size)
    with torch.no_grad():
        traced = torch.jit.trace(model, example)

    # ── Convert to CoreML ─────────────────────────────────────────────────────
    print(f"Converting to CoreML (input size: {input_size}×{input_size}) …")
    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(
            name="input",
            shape=(1, 3, input_size, input_size),
            color_layout=ct.colorlayout.RGB,
            scale=1.0 / 255.0,
        )],
        outputs=[ct.ImageType(
            name="output",
            color_layout=ct.colorlayout.GRAYSCALE,
        )],
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(output_path))
    print(f"Saved: {output_path}")

    # ── Compile to .mlmodelc ──────────────────────────────────────────────────
    if compile and output_path.suffix == ".mlpackage":
        compiled = output_path.with_suffix(".mlmodelc")
        print(f"Compiling to: {compiled}")
        result = subprocess.run(
            ["xcrun", "coremlc", "compile", str(output_path), str(compiled.parent)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f"WARNING: Compilation failed:\n{result.stderr}")
            print("You can compile manually with:")
            print(f"  xcrun coremlc compile {output_path} {compiled.parent}")
        else:
            print(f"Compiled: {compiled}")

    print("\nConversion complete.")
    print("Next steps:")
    print("  1. Measure on-device latency (target: < 3s at 512×512 on A14+)")
    print("  2. If latency > 3s, re-convert at 384×384 by passing --input-size 384")
    print("  3. Copy .mlmodelc into ColorFlow/Resources/Models/")
    print("  4. Add to project.yml resources: block")
    print("  5. Run xcodegen generate")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--weights",    required=True, type=Path, help="Path to .pth weights file")
    parser.add_argument("--output",     required=True, type=Path, help="Output path (.mlpackage or .mlmodelc)")
    parser.add_argument("--input-size", type=int,  default=512, help="Model input edge size in pixels (default: 512)")
    parser.add_argument("--no-compile", action="store_true",     help="Skip xcrun coremlc compile step")
    args = parser.parse_args()

    convert(
        weights_path=args.weights,
        output_path=args.output,
        input_size=args.input_size,
        compile=not args.no_compile,
    )


if __name__ == "__main__":
    main()
