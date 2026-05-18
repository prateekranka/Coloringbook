#!/usr/bin/env python3
import argparse
import json
import math
import re
from pathlib import Path
from xml.etree import ElementTree


STANDARD_LONGEST_SIDE = 3000
PREMIUM_LONGEST_SIDE = 4096
COMPLEX_LONGEST_SIDE = 8000
IPAD_REFERENCE_POINTS = 1024


def parse_view_box(root):
    raw = root.attrib.get("viewBox") or root.attrib.get("viewbox")
    if not raw:
        return None
    values = [float(value) for value in re.split(r"[\s,]+", raw.strip()) if value]
    if len(values) != 4 or values[2] <= 0 or values[3] <= 0:
        return None
    return {
        "x": values[0],
        "y": values[1],
        "width": values[2],
        "height": values[3],
    }


def parse_path_bounds(path_data):
    numbers = [float(value) for value in re.findall(r"[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?", path_data)]
    if len(numbers) < 2:
        return None
    xs = numbers[0::2]
    ys = numbers[1::2]
    return {
        "x": min(xs),
        "y": min(ys),
        "width": max(xs) - min(xs),
        "height": max(ys) - min(ys),
    }


def union_bounds(bounds):
    valid = [bound for bound in bounds if bound and bound["width"] > 0 and bound["height"] > 0]
    if not valid:
        return None
    min_x = min(bound["x"] for bound in valid)
    min_y = min(bound["y"] for bound in valid)
    max_x = max(bound["x"] + bound["width"] for bound in valid)
    max_y = max(bound["y"] + bound["height"] for bound in valid)
    return {
        "x": min_x,
        "y": min_y,
        "width": max_x - min_x,
        "height": max_y - min_y,
    }


def classify(longest_side, smallest_region_side, pyramid_available):
    if longest_side >= PREMIUM_LONGEST_SIDE and (pyramid_available or longest_side < COMPLEX_LONGEST_SIDE):
        if smallest_region_side >= 24:
            return "PASS"
        return "WARN"
    if longest_side >= STANDARD_LONGEST_SIDE:
        return "WARN"
    return "FAIL"


def premium_render_size(view_box):
    longest_side = max(view_box["width"], view_box["height"])
    if longest_side <= 0:
        return view_box["width"], view_box["height"], 1
    scale = max(1, PREMIUM_LONGEST_SIDE / longest_side)
    return view_box["width"] * scale, view_box["height"] * scale, scale


def inspect_svg(path, pyramid_dir=None):
    root = ElementTree.parse(path).getroot()
    view_box = parse_view_box(root)
    if not view_box:
        raise ValueError(f"{path} has no valid viewBox")

    namespace = {"svg": "http://www.w3.org/2000/svg"}
    paths = root.findall(".//svg:path", namespace) + root.findall(".//path")
    region_bounds = [
        parse_path_bounds(node.attrib.get("d", ""))
        for node in paths
        if node.attrib.get("id")
    ]
    content_bounds = union_bounds(region_bounds) or view_box
    smallest_document_side = min(
        (min(bound["width"], bound["height"]) for bound in region_bounds if bound),
        default=0,
    )
    render_width, render_height, render_scale = premium_render_size(view_box)
    longest_side = max(render_width, render_height)
    smallest = smallest_document_side * render_scale
    aspect_ratio = view_box["width"] / view_box["height"]
    safe_zoom = max(1, min(6, longest_side / IPAD_REFERENCE_POINTS))
    pyramid_available = bool(pyramid_dir and (pyramid_dir / path.stem).exists())
    status = classify(longest_side, smallest, pyramid_available)

    return {
        "template": path.name,
        "status": status,
        "sourceKind": "vector-svg",
        "sourceCoordinateWidth": int(round(view_box["width"])),
        "sourceCoordinateHeight": int(round(view_box["height"])),
        "originalPixelWidth": None,
        "originalPixelHeight": None,
        "renderPixelWidth": int(round(render_width)),
        "renderPixelHeight": int(round(render_height)),
        "aspectRatio": round(aspect_ratio, 4),
        "contentBounds": content_bounds,
        "smallestFillableRegionBounds": {
            "estimatedDocumentSmallestSide": round(smallest_document_side, 2),
            "estimatedMaskSmallestSide": round(smallest, 2),
        },
        "recommendedInitialFitScale": 1,
        "maximumSafeZoomScale": round(safe_zoom, 2),
        "vectorSourceExists": True,
        "highResRasterSourceExists": False,
        "maskResolution": f"{int(round(render_width))}x{int(round(render_height))}",
        "tilePyramidAvailability": pyramid_available,
        "notes": quality_notes(longest_side, smallest, pyramid_available),
    }


def quality_notes(longest_side, smallest_region_side, pyramid_available):
    notes = []
    if longest_side < STANDARD_LONGEST_SIDE:
        notes.append("source below 3000 px longest side")
    elif longest_side < PREMIUM_LONGEST_SIDE:
        notes.append("acceptable source, below preferred 4096 px premium tier")
    if longest_side > COMPLEX_LONGEST_SIDE and not pyramid_available:
        notes.append("complex source should use a tile pyramid")
    if smallest_region_side < 24:
        notes.append("smallest estimated region may be difficult to color at practical zoom")
    if not notes:
        notes.append("suitable for premium zoom validation")
    return notes


def main():
    parser = argparse.ArgumentParser(description="Validate Gouache template zoom readiness.")
    parser.add_argument("templates", nargs="?", default="ColorFlow/Resources/Templates")
    parser.add_argument("--pyramids", type=Path, default=None)
    parser.add_argument("--json", type=Path, default=None)
    args = parser.parse_args()

    template_dir = Path(args.templates)
    reports = [inspect_svg(path, args.pyramids) for path in sorted(template_dir.glob("*.svg"))]

    for report in reports:
        print(
            f"{report['status']:4} {report['template']:36} "
            f"render={report['renderPixelWidth']}x{report['renderPixelHeight']} "
            f"mask={report['maskResolution']} "
            f"maxZoom={report['maximumSafeZoomScale']} "
            f"tiles={'yes' if report['tilePyramidAvailability'] else 'no'}"
        )
        for note in report["notes"]:
            print(f"     - {note}")

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")

    if any(report["status"] == "FAIL" for report in reports):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
