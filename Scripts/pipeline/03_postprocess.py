#!/usr/bin/env python3
"""
03_postprocess.py — SVG post-processor for ColorFlow template pipeline.

Takes raw VTracer SVGs and transforms them into parser-compliant files
that satisfy docs/svg-template-spec.md. Runs the same rule set as
Scripts/validate_template_svg.py, but fixes issues automatically where
possible and flags the rest for human review.

Usage:
    python3 Scripts/pipeline/03_postprocess.py \
        --input  pipeline_work/02_vectors/ \
        --output pipeline_work/03_postprocessed/ \
        [--metadata path/to/01_prompt_set.yaml]   # for display names
        [--validate]  # run full validator after post-processing (default: on)

What this script does:
    1.  Pre-bake non-translate transforms — multiply all path coordinates by
        their parent <g> transform matrix, then remove the transform attribute.
        Supports: matrix, rotate, scale, skewX, skewY.

    2.  Assign region IDs — every <path> with a non-empty `d` attribute and
        no id gets id="region-N" (N incrementing from 0). Pre-existing IDs
        are left untouched.

    3.  Strip forbidden elements — removes <filter>, <mask>, <clipPath>,
        <use>, <image>, <style>, <linearGradient>, <radialGradient> and
        any children. Logs each removal.

    4.  Strip forbidden attributes — removes `stroke-dasharray` and `opacity`
        from any element.

    5.  Close open paths — appends " Z" to any named-region path (id present)
        whose d data doesn't end with Z.

    6.  Validate file size and path count — emits errors/warnings; does not
        auto-fix these (requires human Inkscape work to simplify).

    7.  Ensure viewBox — if the root <svg> lacks viewBox but has width/height,
        synthesizes `viewBox="0 0 width height"`. If neither is present, emits
        an error.

Output:
    - Processed SVG file in --output with the same filename.
    - A JSON sidecar <stem>.postprocess.json with change log.
    - <stem>.error.txt if the file failed and cannot be auto-fixed.

Exit code:
    0 if all files produced a valid output
    1 if any file has unresolvable errors
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import re
import sys
from pathlib import Path

try:
    from lxml import etree
except ImportError:
    print("ERROR: lxml is required. Run: pip install -r Scripts/requirements.txt", file=sys.stderr)
    sys.exit(1)

# Pull in the validator so we can assert compliance after processing.
sys.path.insert(0, str(Path(__file__).parent.parent))
try:
    from validate_template_svg import validate_file, FileResult
    VALIDATOR_AVAILABLE = True
except ImportError:
    VALIDATOR_AVAILABLE = False

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SVG_NS = "http://www.w3.org/2000/svg"
FORBIDDEN_ELEMENTS = {
    "filter", "mask", "clipPath", "use", "image", "style",
    "linearGradient", "radialGradient",
}
FORBIDDEN_ATTRIBUTES = {"stroke-dasharray", "opacity"}
MAX_FILE_SIZE_BYTES = 500 * 1024
MAX_PATH_COUNT_HARD = 500
WARN_PATH_COUNT = 300


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


# ---------------------------------------------------------------------------
# Transform matrix math
# ---------------------------------------------------------------------------

def parse_transform_matrix(transform_str: str) -> list[float] | None:
    """
    Parse an SVG transform attribute into a 6-element matrix
    [a, b, c, d, e, f] representing the affine transform:
        [a c e]
        [b d f]
        [0 0 1]

    Returns None if parsing fails.
    """
    s = transform_str.strip()
    nums_re = re.compile(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")

    def get_nums(text: str) -> list[float]:
        return [float(x) for x in nums_re.findall(text)]

    if s.startswith("matrix"):
        nums = get_nums(s)
        if len(nums) == 6:
            return nums
    elif s.startswith("translate"):
        nums = get_nums(s)
        tx = nums[0] if len(nums) >= 1 else 0.0
        ty = nums[1] if len(nums) >= 2 else 0.0
        return [1, 0, 0, 1, tx, ty]
    elif s.startswith("scale"):
        nums = get_nums(s)
        sx = nums[0] if len(nums) >= 1 else 1.0
        sy = nums[1] if len(nums) >= 2 else sx
        return [sx, 0, 0, sy, 0, 0]
    elif s.startswith("rotate"):
        nums = get_nums(s)
        angle_deg = nums[0] if len(nums) >= 1 else 0.0
        cx = nums[1] if len(nums) >= 2 else 0.0
        cy = nums[2] if len(nums) >= 3 else 0.0
        a = math.cos(math.radians(angle_deg))
        b = math.sin(math.radians(angle_deg))
        # rotate(angle, cx, cy) = translate(cx,cy) rotate(angle) translate(-cx,-cy)
        e = cx - a * cx + b * cy
        f = cy - b * cx - a * cy
        return [a, b, -b, a, e, f]
    elif s.startswith("skewX"):
        nums = get_nums(s)
        angle_deg = nums[0] if nums else 0.0
        return [1, 0, math.tan(math.radians(angle_deg)), 1, 0, 0]
    elif s.startswith("skewY"):
        nums = get_nums(s)
        angle_deg = nums[0] if nums else 0.0
        return [1, math.tan(math.radians(angle_deg)), 0, 1, 0, 0]

    return None


def multiply_matrices(m1: list[float], m2: list[float]) -> list[float]:
    """Multiply two SVG affine matrices (6-element form)."""
    a1, b1, c1, d1, e1, f1 = m1
    a2, b2, c2, d2, e2, f2 = m2
    return [
        a1 * a2 + c1 * b2,
        b1 * a2 + d1 * b2,
        a1 * c2 + c1 * d2,
        b1 * c2 + d1 * d2,
        a1 * e2 + c1 * f2 + e1,
        b1 * e2 + d1 * f2 + f1,
    ]


def is_identity(m: list[float]) -> bool:
    return (
        abs(m[0] - 1) < 1e-9 and abs(m[1]) < 1e-9 and
        abs(m[2]) < 1e-9 and abs(m[3] - 1) < 1e-9 and
        abs(m[4]) < 1e-9 and abs(m[5]) < 1e-9
    )


def apply_matrix_to_path_d(d: str, m: list[float]) -> str:
    """
    Apply affine matrix m to all coordinate pairs in an SVG path d-string.

    This is a best-effort transform for the common cases produced by VTracer
    (M, L, C, S, Q, T, H, V, Z). Arc commands (A) are not expected from
    VTracer spline output and would pass through unmodified.
    """
    a, b, c, d_m, e, f = m  # d_m to avoid shadowing d parameter

    def transform_point(x: float, y: float) -> tuple[float, float]:
        return a * x + c * y + e, b * x + d_m * y + f

    def transform_x(x: float, curr_y: float = 0.0) -> float:
        # For H commands we only have x; treat y as current (approximation).
        tx, _ = transform_point(x, curr_y)
        return tx

    def transform_y(curr_x: float, y: float) -> float:
        # For V commands we only have y.
        _, ty = transform_point(curr_x, y)
        return ty

    # Tokenize and rebuild
    token_re = re.compile(
        r"([MmLlHhVvCcSsQqTtAaZz])|"
        r"([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)"
    )
    tokens = [(m.group(1), m.group(2)) for m in token_re.finditer(d)]

    result_parts: list[str] = []
    i = 0
    current_x = 0.0
    current_y = 0.0

    def fmt(v: float) -> str:
        return f"{v:.4f}".rstrip("0").rstrip(".")

    while i < len(tokens):
        cmd_tok, _ = tokens[i]
        if cmd_tok is None:
            i += 1
            continue

        cmd = cmd_tok
        i += 1
        result_parts.append(cmd)

        upper = cmd.upper()

        if upper == "Z":
            pass  # No coordinates

        elif upper in ("M", "L", "T"):
            while i < len(tokens) and tokens[i][1] is not None:
                x = float(tokens[i][1]); i += 1
                y = float(tokens[i][1]) if i < len(tokens) and tokens[i][1] else 0.0; i += 1
                if cmd.islower():
                    tx, ty = transform_point(current_x + x, current_y + y)
                    tx -= e + current_x  # re-relativize (approximate)
                    ty -= f + current_y
                else:
                    tx, ty = transform_point(x, y)
                    current_x, current_y = tx, ty
                result_parts.extend([fmt(tx), fmt(ty)])

        elif upper == "H":
            while i < len(tokens) and tokens[i][1] is not None:
                x = float(tokens[i][1]); i += 1
                tx, ty = transform_point(x if cmd.isupper() else current_x + x, current_y)
                if cmd.isupper():
                    current_x = tx
                result_parts.append(fmt(tx))

        elif upper == "V":
            while i < len(tokens) and tokens[i][1] is not None:
                y = float(tokens[i][1]); i += 1
                tx, ty = transform_point(current_x, y if cmd.isupper() else current_y + y)
                if cmd.isupper():
                    current_y = ty
                result_parts.append(fmt(ty))

        elif upper == "C":
            # 6 numbers per iteration
            while i + 5 < len(tokens) and tokens[i][1] is not None:
                coords = []
                for _ in range(6):
                    coords.append(float(tokens[i][1])); i += 1
                pairs = [(coords[j], coords[j + 1]) for j in range(0, 6, 2)]
                for x, y in pairs:
                    if cmd.islower():
                        tx, ty = transform_point(current_x + x, current_y + y)
                        tx -= e + current_x; ty -= f + current_y
                    else:
                        tx, ty = transform_point(x, y)
                    result_parts.extend([fmt(tx), fmt(ty)])
                if cmd.isupper() and len(pairs) == 3:
                    current_x, current_y = pairs[2]

        elif upper == "S":
            # 4 numbers per iteration
            while i + 3 < len(tokens) and tokens[i][1] is not None:
                coords = []
                for _ in range(4):
                    coords.append(float(tokens[i][1])); i += 1
                pairs = [(coords[j], coords[j + 1]) for j in range(0, 4, 2)]
                for x, y in pairs:
                    tx, ty = transform_point(x, y) if cmd.isupper() else (x, y)
                    result_parts.extend([fmt(tx), fmt(ty)])

        elif upper == "Q":
            # 4 numbers
            while i + 3 < len(tokens) and tokens[i][1] is not None:
                coords = []
                for _ in range(4):
                    coords.append(float(tokens[i][1])); i += 1
                pairs = [(coords[j], coords[j + 1]) for j in range(0, 4, 2)]
                for x, y in pairs:
                    tx, ty = transform_point(x, y) if cmd.isupper() else (x, y)
                    result_parts.extend([fmt(tx), fmt(ty)])

        else:
            # Pass through any other tokens unchanged (A, etc.)
            while i < len(tokens) and tokens[i][1] is not None:
                result_parts.append(tokens[i][1]); i += 1

    return " ".join(result_parts)


# ---------------------------------------------------------------------------
# Post-processor
# ---------------------------------------------------------------------------

def postprocess_file(
    input_path: Path,
    output_path: Path,
    run_validator: bool = True,
) -> tuple[bool, dict]:
    """
    Post-process a single SVG file. Returns (success, change_log).
    """
    log: list[str] = []
    errors: list[str] = []

    # ── Parse ──────────────────────────────────────────────────────────────
    try:
        parser = etree.XMLParser(remove_blank_text=False, recover=True)
        tree = etree.parse(str(input_path), parser)
    except etree.XMLSyntaxError as exc:
        return False, {"error": f"XML parse failed: {exc}", "input": str(input_path)}

    root = tree.getroot()

    # ── File size check ────────────────────────────────────────────────────
    file_size = input_path.stat().st_size
    if file_size > MAX_FILE_SIZE_BYTES:
        errors.append(f"File too large: {file_size // 1024} KB (limit {MAX_FILE_SIZE_BYTES // 1024} KB). "
                      "Simplify in Inkscape (Path → Simplify) before reprocessing.")
        # Return early — no point transforming a file that's too large to fix automatically.
        output_path.with_suffix(".error.txt").write_text(
            "\n".join(errors), encoding="utf-8"
        )
        return False, {"errors": errors, "input": str(input_path)}

    # ── viewBox synthesis ──────────────────────────────────────────────────
    if not root.get("viewBox"):
        w = root.get("width", "").replace("px", "").strip()
        h = root.get("height", "").replace("px", "").strip()
        if w and h:
            root.set("viewBox", f"0 0 {w} {h}")
            log.append(f"Synthesized viewBox from width/height: 0 0 {w} {h}")
        else:
            errors.append("Missing viewBox and cannot synthesize (no width/height). "
                          "Add viewBox manually in Inkscape.")

    # ── Remove forbidden elements ──────────────────────────────────────────
    for elem in tree.iter():
        if not isinstance(elem.tag, str):
            continue
        tag = local(elem.tag)
        if tag in FORBIDDEN_ELEMENTS:
            parent = elem.getparent()
            if parent is not None:
                parent.remove(elem)
                log.append(f"Removed forbidden element <{tag}>")

    # ── Remove forbidden attributes ────────────────────────────────────────
    for elem in tree.iter():
        if not isinstance(elem.tag, str):
            continue
        for attr in list(elem.attrib.keys()):
            if attr in FORBIDDEN_ATTRIBUTES:
                del elem.attrib[attr]
                log.append(f"Removed forbidden attribute '{attr}' from <{local(elem.tag)}>")

    # ── Pre-bake non-translate transforms ─────────────────────────────────
    # Walk the tree collecting accumulated transforms.
    # For each non-translate transform on a <g>, multiply it into child path coordinates.
    def is_translate_only(transform_str: str) -> bool:
        s = transform_str.strip().lower()
        return s.startswith("translate") or s.startswith("matrix(1 0 0 1 ") or s.startswith("matrix(1,0,0,1,")

    def bake_transforms(elem: etree._Element, accumulated: list[float]) -> None:
        if not isinstance(elem.tag, str):
            return
        tag = local(elem.tag)
        transform_attr = elem.get("transform", "")
        local_matrix: list[float] = [1, 0, 0, 1, 0, 0]  # identity

        if transform_attr:
            parsed = parse_transform_matrix(transform_attr)
            if parsed:
                local_matrix = parsed
            else:
                log.append(f"Could not parse transform '{transform_attr}' on <{tag}>; skipping bake")

        # The combined matrix for this element's subtree.
        combined = multiply_matrices(accumulated, local_matrix)

        if tag == "g":
            # Check if transform is purely translate — keep those as-is.
            if not is_translate_only(transform_attr) and not is_identity(local_matrix):
                # Apply combined matrix to all descendant paths, then remove transform.
                # We'll recurse into children with the combined matrix.
                pass  # handled by recursion below
            # Recurse into children with combined matrix.
            for child in list(elem):
                bake_transforms(child, combined)
            # Now remove the non-translate transform from this group, leaving translate-only.
            if transform_attr and not is_translate_only(transform_attr):
                elem.attrib.pop("transform", None)
                log.append(f"Removed non-translate transform from <g>: '{transform_attr}'")
                # Translate portion: re-extract just the translation from the combined matrix.
                tx, ty = combined[4], combined[5]
                if abs(tx) > 1e-6 or abs(ty) > 1e-6:
                    elem.set("transform", f"translate({tx:.4f},{ty:.4f})")

        elif tag == "path":
            d = elem.get("d", "")
            if d and not is_identity(combined):
                new_d = apply_matrix_to_path_d(d, combined)
                elem.set("d", new_d)
                # Remove the element's own transform if it has one.
                if elem.get("transform"):
                    del elem.attrib["transform"]
                    log.append(f"Pre-baked transform into path id='{elem.get('id', '(no id)')}'")

        else:
            # For non-g, non-path elements, recurse but don't bake.
            for child in list(elem):
                bake_transforms(child, combined)

    bake_transforms(root, [1, 0, 0, 1, 0, 0])

    # ── Assign region IDs ─────────────────────────────────────────────────
    region_counter = 0
    for elem in tree.iter():
        if not isinstance(elem.tag, str): continue
        if local(elem.tag) == "path":
            if not elem.get("id") and elem.get("d", "").strip():
                elem.set("id", f"region-{region_counter}")
                region_counter += 1

    if region_counter:
        log.append(f"Assigned {region_counter} region IDs (region-0 … region-{region_counter - 1})")

    # ── Close open named-region paths ────────────────────────────────────
    for elem in tree.iter():
        if not isinstance(elem.tag, str): continue
        if local(elem.tag) == "path" and elem.get("id"):
            d = elem.get("d", "").rstrip()
            if d and not d.upper().endswith("Z"):
                elem.set("d", d + " Z")
                log.append(f"Closed open path id='{elem.get('id')}'")

    # ── Path count warning ─────────────────────────────────────────────────
    path_count = sum(1 for e in tree.iter()
                     if isinstance(e.tag, str) and local(e.tag) in ("path", "circle", "ellipse", "rect", "polygon"))
    if path_count > MAX_PATH_COUNT_HARD:
        errors.append(f"Path count {path_count} exceeds hard limit {MAX_PATH_COUNT_HARD}. "
                      "Simplify in Inkscape before committing.")
    elif path_count > WARN_PATH_COUNT:
        log.append(f"WARNING: {path_count} paths exceeds soft limit {WARN_PATH_COUNT}")

    # ── Serialize ─────────────────────────────────────────────────────────
    if errors:
        output_path.with_suffix(".error.txt").write_text("\n".join(errors), encoding="utf-8")
        return False, {"errors": errors, "changes": log, "input": str(input_path)}

    output_path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(
        str(output_path),
        xml_declaration=True,
        encoding="UTF-8",
        pretty_print=True,
    )

    # ── Post-validation ────────────────────────────────────────────────────
    if run_validator and VALIDATOR_AVAILABLE:
        result: FileResult = validate_file(output_path)
        if not result.passed:
            for d in result.errors:
                errors.append(str(d))
            output_path.with_suffix(".error.txt").write_text(
                "Post-processing validation failed:\n" + "\n".join(errors),
                encoding="utf-8",
            )
            return False, {"errors": errors, "changes": log, "input": str(input_path)}
        for d in result.warnings:
            log.append(f"Validator warning: {d}")

    return True, {"changes": log, "path_count": path_count, "input": str(input_path)}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",    required=True,  help="Directory of raw VTracer SVGs")
    parser.add_argument("--output",   required=True,  help="Directory for post-processed SVGs")
    parser.add_argument("--validate", default=True, action=argparse.BooleanOptionalAction,
                        help="Run validator after processing (default: on)")
    args = parser.parse_args(argv)

    input_dir  = Path(args.input)
    output_dir = Path(args.output)

    if not input_dir.is_dir():
        print(f"ERROR: '{input_dir}' is not a directory.", file=sys.stderr)
        return 1

    output_dir.mkdir(parents=True, exist_ok=True)

    svgs = sorted(input_dir.glob("*.svg"))
    if not svgs:
        print(f"No SVG files found in '{input_dir}'.", file=sys.stderr)
        return 1

    print(f"Post-processing {len(svgs)} SVG(s) from '{input_dir}' → '{output_dir}'")
    if not VALIDATOR_AVAILABLE:
        print("WARNING: validate_template_svg module not importable; skipping post-validation.", file=sys.stderr)

    pass_count = 0
    fail_count = 0

    for svg in svgs:
        out = output_dir / svg.name
        success, report = postprocess_file(svg, out, run_validator=args.validate)

        sidecar = output_dir / (svg.stem + ".postprocess.json")
        sidecar.write_text(json.dumps(report, indent=2), encoding="utf-8")

        if success:
            pass_count += 1
            changes = len(report.get("changes", []))
            paths   = report.get("path_count", "?")
            print(f"  ✓  {svg.name}  ({paths} paths, {changes} change(s))")
        else:
            fail_count += 1
            errs = report.get("errors", ["Unknown error"])
            print(f"  ✗  {svg.name}: {errs[0]}", file=sys.stderr)

    print()
    print(f"Results: {pass_count}/{len(svgs)} post-processed successfully.")
    if fail_count:
        print(f"  {fail_count} failure(s) — check *.error.txt in {output_dir}")

    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
