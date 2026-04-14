#!/usr/bin/env python3
"""
validate_template_svg.py — ColorFlow SVG template validator.

Enforces the rules documented in docs/svg-template-spec.md.
Mirrors the constraints of ColorFlow/Services/SVGParser.swift so a file
that passes here is guaranteed to parse on-device.

Usage:
    python3 Scripts/validate_template_svg.py [path ...]

    path can be:
        - A single .svg file
        - A directory (all *.svg files inside are validated)
        - Multiple files / directories (space-separated)

    If no path is given, defaults to ColorFlow/Resources/Templates/.

Exit codes:
    0   All files passed (warnings may be present)
    1   At least one file failed
"""

from __future__ import annotations

import re
import sys
import os
import argparse
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

try:
    from lxml import etree
except ImportError:
    print("ERROR: lxml is required. Run: pip install -r Scripts/requirements.txt", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Constants (mirror SVGParser.swift)
# ---------------------------------------------------------------------------

REJECTED_ELEMENTS: set[str] = {
    "filter", "mask", "clipPath", "use", "image", "style",
    "linearGradient", "radialGradient",
}

REJECTED_ATTRIBUTES: set[str] = {
    "stroke-dasharray",
    "opacity",
}

FORBIDDEN_TRANSFORMS: list[str] = [
    "matrix", "rotate", "scale", "skewX", "skewY",
]

# Hard limits (parse failure)
MAX_FILE_SIZE_BYTES = 500 * 1024          # 500 KB
MAX_PATH_COUNT_HARD = 500
MAX_PATH_DATA_LENGTH_HARD = 10_000

# Soft limits (warning only)
WARN_FILE_SIZE_BYTES = 200 * 1024         # 200 KB
WARN_PATH_COUNT = 300
WARN_PATH_DATA_LENGTH = 2_000

# SVG namespace
SVG_NS = "http://www.w3.org/2000/svg"


# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------

@dataclass
class Diagnostic:
    level: str          # "ERROR" | "WARNING"
    rule: str           # short rule code
    message: str

    def __str__(self) -> str:
        return f"  [{self.level}] {self.rule}: {self.message}"


@dataclass
class FileResult:
    path: Path
    diagnostics: list[Diagnostic] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return all(d.level != "ERROR" for d in self.diagnostics)

    @property
    def errors(self) -> list[Diagnostic]:
        return [d for d in self.diagnostics if d.level == "ERROR"]

    @property
    def warnings(self) -> list[Diagnostic]:
        return [d for d in self.diagnostics if d.level == "WARNING"]

    def error(self, rule: str, message: str) -> None:
        self.diagnostics.append(Diagnostic("ERROR", rule, message))

    def warn(self, rule: str, message: str) -> None:
        self.diagnostics.append(Diagnostic("WARNING", rule, message))


# ---------------------------------------------------------------------------
# Validator
# ---------------------------------------------------------------------------

def validate_file(svg_path: Path) -> FileResult:
    result = FileResult(path=svg_path)

    # ── File-level checks ────────────────────────────────────────────────────

    file_size = svg_path.stat().st_size
    if file_size > MAX_FILE_SIZE_BYTES:
        result.error("file-size", f"{file_size // 1024} KB exceeds hard limit of {MAX_FILE_SIZE_BYTES // 1024} KB")
        return result  # too large to bother parsing further
    elif file_size > WARN_FILE_SIZE_BYTES:
        result.warn("file-size", f"{file_size // 1024} KB exceeds soft limit of {WARN_FILE_SIZE_BYTES // 1024} KB")

    # ── XML parse ────────────────────────────────────────────────────────────

    try:
        tree = etree.parse(str(svg_path))
    except etree.XMLSyntaxError as exc:
        result.error("xml-validity", str(exc))
        return result

    root = tree.getroot()

    # Strip namespace from tag for convenience
    def local(tag: str) -> str:
        return tag.split("}")[-1] if "}" in tag else tag

    def ns(name: str) -> str:
        """Qualify an element name with the SVG namespace."""
        return f"{{{SVG_NS}}}{name}"

    # ── viewBox ──────────────────────────────────────────────────────────────

    viewbox = root.get("viewBox")
    if not viewbox:
        result.error("viewbox", "Root <svg> is missing the viewBox attribute")
    else:
        parts = re.split(r"[\s,]+", viewbox.strip())
        if len(parts) != 4:
            result.error("viewbox", f"viewBox must have exactly 4 numbers; got: '{viewbox}'")
        else:
            try:
                nums = [float(p) for p in parts]
                if nums[2] <= 0 or nums[3] <= 0:
                    result.error("viewbox", f"viewBox width and height must be > 0; got {nums[2]}×{nums[3]}")
            except ValueError:
                result.error("viewbox", f"viewBox contains non-numeric values: '{viewbox}'")

    # ── Element + attribute traversal ────────────────────────────────────────

    total_paths = 0
    region_ids: dict[str, int] = {}   # id → occurrence count

    for elem in tree.iter():
        # Skip processing instructions, comments, and other non-element nodes.
        if not isinstance(elem.tag, str):
            continue
        tag = local(elem.tag)
        attribs = elem.attrib

        # Rejected elements
        if tag in REJECTED_ELEMENTS:
            result.error("forbidden-element", f"<{tag}> is not allowed")

        # Rejected attributes on any element
        for attr in REJECTED_ATTRIBUTES:
            if attr in attribs:
                result.error("forbidden-attribute",
                             f"<{tag}> carries forbidden attribute '{attr}'")

        # Transform constraint on <g>
        if tag == "g" and "transform" in attribs:
            transform_value = attribs["transform"].strip()
            _validate_transform(transform_value, tag, result)

        # Path-specific checks
        if tag == "path":
            total_paths += 1
            path_id = attribs.get("id")
            d = attribs.get("d", "")

            # Arc command check
            if re.search(r"(?<![a-zA-Z])[Aa](?![a-zA-Z])", d):
                result.error("arc-command",
                             f"Path id='{path_id or '(no id)'}' contains arc command A/a. "
                             "Convert to cubic Béziers.")

            # Closepath check for named (fillable) regions
            if path_id:
                d_stripped = d.rstrip()
                if not d_stripped.upper().endswith("Z"):
                    result.error("unclosed-region",
                                 f"Named region id='{path_id}' path data does not end with Z. "
                                 "Open paths produce incorrect flood-fill.")

                # Duplicate ID check
                region_ids[path_id] = region_ids.get(path_id, 0) + 1

            # Path data length
            if len(d) > MAX_PATH_DATA_LENGTH_HARD:
                result.error("path-data-length",
                             f"Path id='{path_id or '(no id)'}' has {len(d)} chars of path data "
                             f"(hard limit {MAX_PATH_DATA_LENGTH_HARD})")
            elif len(d) > WARN_PATH_DATA_LENGTH:
                result.warn("path-data-length",
                            f"Path id='{path_id or '(no id)'}' has {len(d)} chars of path data "
                            f"(soft limit {WARN_PATH_DATA_LENGTH})")

        # Also count circles/ellipses/rects/polygons toward total shape count
        if tag in ("circle", "ellipse", "rect", "polygon"):
            total_paths += 1

    # ── Duplicate region IDs ─────────────────────────────────────────────────

    for rid, count in region_ids.items():
        if count > 1:
            result.error("duplicate-id",
                         f"id='{rid}' appears {count} times. Only the first will be fillable.")

    # ── Path count ───────────────────────────────────────────────────────────

    if total_paths > MAX_PATH_COUNT_HARD:
        result.error("path-count",
                     f"{total_paths} paths exceeds hard limit of {MAX_PATH_COUNT_HARD}")
    elif total_paths > WARN_PATH_COUNT:
        result.warn("path-count",
                    f"{total_paths} paths exceeds soft limit of {WARN_PATH_COUNT}; "
                    "may cause perceptible lag on older iPads")

    # ── Warn if no fillable regions were found ───────────────────────────────

    if not region_ids:
        result.warn("no-regions",
                    "No named (id='region-N') paths found. "
                    "This file will render but produce no fillable regions.")

    return result


def _validate_transform(value: str, tag: str, result: FileResult) -> None:
    """Validate that a transform attribute is translate-only."""
    v = value.strip().lower()
    for forbidden in FORBIDDEN_TRANSFORMS:
        if v.startswith(forbidden):
            result.error("transform",
                         f"<{tag}> uses forbidden transform '{value}'. "
                         "Only translate(x, y) is supported. Pre-bake transforms in Inkscape.")
            return
    if not v.startswith("translate"):
        result.error("transform",
                     f"<{tag}> has unrecognised transform '{value}'. "
                     "Only translate(x, y) is supported.")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def collect_svg_files(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            files.extend(sorted(p.glob("*.svg")))
        elif p.suffix.lower() == ".svg":
            files.append(p)
        else:
            print(f"WARNING: Skipping '{raw}' (not an SVG file or directory)", file=sys.stderr)
    return files


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate SVG template files against the ColorFlow spec.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "paths",
        nargs="*",
        default=["ColorFlow/Resources/Templates/"],
        help="SVG files or directories to validate (default: ColorFlow/Resources/Templates/)",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Only print files with diagnostics",
    )
    args = parser.parse_args(argv)

    svg_files = collect_svg_files(args.paths)
    if not svg_files:
        print("No SVG files found.", file=sys.stderr)
        return 1

    results: list[FileResult] = [validate_file(f) for f in svg_files]

    pass_count = sum(1 for r in results if r.passed)
    fail_count = len(results) - pass_count

    for res in results:
        if not res.diagnostics and args.quiet:
            continue
        status = "✓ PASS" if res.passed else "✗ FAIL"
        print(f"{status}  {res.path.name}")
        for d in res.diagnostics:
            print(str(d))

    print()
    print(f"Results: {pass_count}/{len(results)} passed", end="")
    if fail_count:
        print(f", {fail_count} failed")
    else:
        print()

    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
