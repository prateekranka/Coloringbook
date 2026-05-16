#!/usr/bin/env python3
"""
Generate parser-compliant fill-region SVGs from transparent line-art PNGs.

The shipped canvas displays the PNG line art directly. These SVGs provide the
matching fill regions by extracting enclosed transparent areas from the same
line-art rasters, so fill hit-testing stays aligned with the visible artwork.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Directory containing transparent PNG line art.")
    parser.add_argument("--output", required=True, type=Path, help="Directory where SVG masks should be written.")
    parser.add_argument("--alpha-threshold", type=int, default=24, help="Minimum alpha value treated as ink.")
    parser.add_argument("--min-area-ratio", type=float, default=0.00008, help="Minimum region area as a share of image area.")
    parser.add_argument("--min-area", type=int, default=64, help="Absolute minimum region area in pixels.")
    parser.add_argument("--dilate", type=int, default=1, help="Ink dilation iterations before region extraction.")
    parser.add_argument("--simplify", type=float, default=0.0015, help="Contour simplification ratio.")
    return parser.parse_args()


def make_line_mask(alpha: np.ndarray, threshold: int, dilate_iterations: int) -> np.ndarray:
    mask = (alpha > threshold).astype(np.uint8) * 255
    if dilate_iterations <= 0:
        return mask
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    return cv2.dilate(mask, kernel, iterations=dilate_iterations)


def contour_to_path(contour: np.ndarray, simplify_ratio: float) -> tuple[str, int] | None:
    if len(contour) < 3:
        return None

    perimeter = cv2.arcLength(contour, closed=True)
    epsilon = max(0.8, perimeter * simplify_ratio)
    simplified = cv2.approxPolyDP(contour, epsilon, closed=True)
    if len(simplified) < 3:
        return None

    points = simplified.reshape(-1, 2)
    commands = " L ".join(f"{int(x)} {int(y)}" for x, y in points)
    return f"M {commands} Z", len(points)


def extract_regions(
    png_path: Path,
    alpha_threshold: int,
    min_area_ratio: float,
    min_area: int,
    dilate_iterations: int,
    simplify_ratio: float,
) -> tuple[int, int, list[str], int]:
    image = Image.open(png_path).convert("RGBA")
    pixels = np.array(image)
    height, width = pixels.shape[:2]

    line_mask = make_line_mask(pixels[:, :, 3], alpha_threshold, dilate_iterations)
    fillable_mask = cv2.bitwise_not(line_mask)
    component_count, labels, stats, _ = cv2.connectedComponentsWithStats(fillable_mask, connectivity=8)
    area_floor = max(min_area, int(width * height * min_area_ratio))

    regions: list[tuple[int, int, int, str, int]] = []
    for label in range(1, component_count):
        x, y, region_width, region_height, area = stats[label]
        if area < area_floor:
            continue

        touches_border = x <= 0 or y <= 0 or x + region_width >= width or y + region_height >= height
        if touches_border:
            continue

        component = (labels == label).astype(np.uint8) * 255
        contours, _ = cv2.findContours(component, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            continue

        contour = max(contours, key=cv2.contourArea)
        path = contour_to_path(contour, simplify_ratio)
        if path is None:
            continue

        path_data, point_count = path
        regions.append((y, x, -area, path_data, point_count))

    regions.sort()
    return width, height, [region[3] for region in regions], sum(region[4] for region in regions)


def write_svg(svg_path: Path, width: int, height: int, paths: list[str]) -> None:
    with svg_path.open("w", encoding="utf-8") as svg:
        svg.write(
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'width="{width}" height="{height}" viewBox="0 0 {width} {height}">\n'
        )
        for index, path_data in enumerate(paths):
            svg.write(f'  <path id="region-{index:03d}" d="{path_data}" fill="#FFFFFF"/>\n')
        svg.write("</svg>\n")


def main() -> int:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    png_paths = sorted(args.input.glob("*.png"))
    if not png_paths:
        raise SystemExit(f"No PNG files found in {args.input}")

    for png_path in png_paths:
        width, height, paths, point_count = extract_regions(
            png_path=png_path,
            alpha_threshold=args.alpha_threshold,
            min_area_ratio=args.min_area_ratio,
            min_area=args.min_area,
            dilate_iterations=args.dilate,
            simplify_ratio=args.simplify,
        )
        svg_path = args.output / f"{png_path.stem}.svg"
        write_svg(svg_path, width, height, paths)
        print(
            f"{svg_path.name}: {len(paths)} regions, {point_count} points, "
            f"{svg_path.stat().st_size // 1024} KB"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
