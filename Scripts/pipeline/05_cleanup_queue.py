#!/usr/bin/env python3
"""
05_cleanup_queue.py — Split validated pipeline output into pass/ and needs-cleanup/ directories.

Runs the ColorFlow SVG validator against every SVG in the input directory and
routes each file:
  - PASS (no errors)   → --pass directory
  - FAIL (any errors)  → --cleanup directory

WARNING-only files are treated as passing unless --strict is given.

Usage:
    python3 Scripts/pipeline/05_cleanup_queue.py \\
        --input   pipeline_work/03_postprocessed/ \\
        --pass    pipeline_work/04_pass/ \\
        --cleanup pipeline_work/04_needs_cleanup/

    Dry-run (print routing, copy nothing):
        python3 Scripts/pipeline/05_cleanup_queue.py ... --dry-run

    Treat warnings as failures:
        python3 Scripts/pipeline/05_cleanup_queue.py ... --strict

Re-running is safe (idempotent): files already present in the destination
are overwritten in-place; the source file is never deleted.

Exit codes:
    0   All files passed (nothing routed to --cleanup)
    1   At least one file routed to --cleanup
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Inline import of the validator so this script has no extra install step
# (validate_template_svg.py lives two directories up at Scripts/)
# ---------------------------------------------------------------------------

def _import_validator():
    """Import validate_file from Scripts/validate_template_svg.py."""
    scripts_dir = str(Path(__file__).parent.parent)
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)
    try:
        import validate_template_svg as _v
        return _v.validate_file
    except ImportError:
        print(
            "ERROR: Scripts/validate_template_svg.py not found.\n"
            "Make sure it exists at the repo's Scripts/ directory.",
            file=sys.stderr,
        )
        sys.exit(1)


validate_file = _import_validator()


# ---------------------------------------------------------------------------
# Queue logic
# ---------------------------------------------------------------------------

def route_svgs(
    input_dir: Path,
    pass_dir: Path,
    cleanup_dir: Path,
    strict: bool,
    dry_run: bool,
) -> tuple[list[Path], list[Path]]:
    """
    Validate every SVG in input_dir and sort into pass/cleanup lists.
    Returns (passed, failed) path lists (source paths).
    """
    svg_files = sorted(input_dir.glob("*.svg"))
    if not svg_files:
        print(f"WARNING: No SVG files found in '{input_dir}'.", file=sys.stderr)
        return [], []

    passed: list[Path] = []
    failed: list[Path] = []
    results_log: list[dict] = []

    for svg in svg_files:
        result = validate_file(svg)
        ok = result.passed if not strict else (result.passed and not result.warnings)

        summary = {
            "file": svg.name,
            "status": "pass" if ok else "fail",
            "errors":   [str(d) for d in result.errors],
            "warnings": [str(d) for d in result.warnings],
        }
        results_log.append(summary)

        if ok:
            passed.append(svg)
            dest = pass_dir / svg.name
            if not dry_run:
                pass_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(svg, dest)
            tag = "✓ pass"
        else:
            failed.append(svg)
            dest = cleanup_dir / svg.name
            if not dry_run:
                cleanup_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(svg, dest)
            tag = "✗ cleanup"

        error_summary = ""
        if result.errors:
            codes = ", ".join(d.rule for d in result.errors)
            error_summary = f"  errors: {codes}"
        elif result.warnings:
            codes = ", ".join(d.rule for d in result.warnings)
            error_summary = f"  warnings: {codes}"

        print(f"  {tag:<12} {svg.name}{error_summary}")

    # Write a sidecar JSON so the operator has a machine-readable routing log.
    if not dry_run and svg_files:
        log_path = input_dir / "_queue_routing.json"
        log_path.write_text(
            json.dumps(
                {
                    "pass_dir":    str(pass_dir),
                    "cleanup_dir": str(cleanup_dir),
                    "strict":      strict,
                    "files":       results_log,
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        print(f"\nRouting log written to: {log_path}")

    return passed, failed


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",   required=True, help="Directory of post-processed SVGs (Step 3 output)")
    parser.add_argument("--pass",    required=True, dest="pass_dir",    help="Destination for validator-passing SVGs")
    parser.add_argument("--cleanup", required=True, dest="cleanup_dir", help="Destination for SVGs that need Inkscape fixes")
    parser.add_argument("--strict",  action="store_true",
                        help="Treat WARNING-only files as failures (routes them to --cleanup)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print routing decisions without copying any files")
    args = parser.parse_args(argv)

    input_dir   = Path(args.input)
    pass_dir    = Path(args.pass_dir)
    cleanup_dir = Path(args.cleanup_dir)

    if not input_dir.is_dir():
        print(f"ERROR: '{input_dir}' is not a directory.", file=sys.stderr)
        return 1

    if args.dry_run:
        print(f"DRY RUN — no files will be copied.\n")

    print(f"Input:   {input_dir}")
    print(f"Pass:    {pass_dir}")
    print(f"Cleanup: {cleanup_dir}")
    print(f"Strict:  {args.strict}")
    print()

    passed, failed = route_svgs(
        input_dir, pass_dir, cleanup_dir,
        strict=args.strict,
        dry_run=args.dry_run,
    )

    total = len(passed) + len(failed)
    print()
    print(f"Results: {len(passed)}/{total} passed → {pass_dir}")
    if failed:
        print(f"         {len(failed)}/{total} need cleanup → {cleanup_dir}")
        print()
        print("Next step: open flagged SVGs in Inkscape and follow")
        print("  docs/contributors/svg-cleanup-brief.md for fix instructions.")
        print("  Then re-run this script to re-route cleaned files.")
    else:
        print("All files passed — ready for manifest update (Step 5).")

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
