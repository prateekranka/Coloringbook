#!/usr/bin/env python3
"""
ColorFlow App Icon Generator
==============================
Generates all required iOS/iPadOS app icon PNGs from scratch using Pillow.
Outputs files into AppIcon.appiconset/ ready to drop into Xcode.

Usage:
    pip install Pillow
    python3 generate_icon.py

Then copy the generated AppIcon.appiconset/ into:
    YourProject/Assets.xcassets/AppIcon.appiconset/
"""

import math
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Pillow is not installed.  Run:  pip install Pillow")
    sys.exit(1)


# ── Design constants (all relative to canvas size) ──────────────────────────

BG_COLOR       = (13,  11,  34)   # #0D0B22  deep navy-indigo
WHITE          = (255, 255, 255)
CENTER_TEXT_FG = (30,  26,  78)   # #1E1A4E

# 6 segment colours, clockwise from top
SEGMENT_COLORS = [
    (255, 107, 107),   # coral red
    (255, 159,  67),   # warm orange
    (254, 202,  87),   # sunny yellow
    ( 29, 209, 161),   # mint teal
    ( 84, 160, 255),   # sky blue
    (199, 125, 255),   # soft violet
]

# Pillow arc angles (0° = 3 o'clock, clockwise).
# Six equal 60° slices starting from 12 o'clock (270°).
SEGMENT_ANGLES = [
    (270, 330),
    (330, 390),   # wraps past 0°
    ( 30,  90),
    ( 90, 150),
    (150, 210),
    (210, 270),
]

# Boundary angles between slices (used for divider lines and tip dots)
BOUNDARY_ANGLES_DEG = [270, 330, 30, 90, 150, 210]


def hex_to_rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def point_on_circle(cx, cy, r, angle_deg):
    """Return (x, y) on a circle of radius r at Pillow-convention angle_deg."""
    a = math.radians(angle_deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def draw_icon(size: int) -> Image.Image:
    """Render the ColorFlow icon at the given pixel size."""
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = cy = size / 2
    R        = size * 0.3027   # outer mandala radius
    inner_r  = size * 0.1719   # inner decorative ring
    center_r = size * 0.0879   # white center circle
    stroke   = max(1, round(size / 342))   # line weight scales with size

    # ── Background ──────────────────────────────────────────────────────────
    bg = Image.new("RGBA", (size, size), BG_COLOR + (255,))

    # Apply rounded-corner mask (iOS icon shape ≈ superellipse r = 22.4 % of side)
    corner = round(size * 0.2197)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1],
                                           radius=corner, fill=255)
    img.paste(bg, mask=mask)
    draw = ImageDraw.Draw(img)

    # Subtle vignette rings (very faint, for depth)
    for ring_r, alpha in [(size * 0.42, 10), (size * 0.46, 6)]:
        ring_bbox = [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r]
        draw.ellipse(ring_bbox, outline=(255, 255, 255, alpha),
                     width=max(1, round(ring_r * 0.12)))

    # ── 6 pie segments ───────────────────────────────────────────────────────
    bbox = [cx - R, cy - R, cx + R, cy + R]
    for color, (start, end) in zip(SEGMENT_COLORS, SEGMENT_ANGLES):
        draw.pieslice(bbox, start=start, end=end, fill=color)

    # ── Inner decorative ring ────────────────────────────────────────────────
    iring_bbox = [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r]
    draw.ellipse(iring_bbox, outline=(255, 255, 255, 55), width=max(1, stroke))

    # Small accent dots at inner ring / boundary intersections
    for a in BOUNDARY_ANGLES_DEG:
        px, py = point_on_circle(cx, cy, inner_r, a)
        dr = max(2, round(size * 0.0098))
        draw.ellipse([px - dr, py - dr, px + dr, py + dr],
                     fill=(255, 255, 255, 76))

    # ── White divider lines (coloring-book stroke) ───────────────────────────
    lw = max(1, stroke * 2)
    for a in BOUNDARY_ANGLES_DEG:
        ex, ey = point_on_circle(cx, cy, R, a)
        draw.line([(cx, cy), (ex, ey)], fill=WHITE + (230,), width=lw)

    # ── Outer circle outline ─────────────────────────────────────────────────
    draw.ellipse(bbox, outline=WHITE + (217,), width=lw)

    # Tip accent dots at segment boundary points on outer circle
    for a in BOUNDARY_ANGLES_DEG:
        px, py = point_on_circle(cx, cy, R, a)
        dr = max(2, round(size * 0.0088))
        draw.ellipse([px - dr, py - dr, px + dr, py + dr],
                     fill=WHITE + (229,))

    # ── White center circle ───────────────────────────────────────────────────
    draw.ellipse(
        [cx - center_r, cy - center_r, cx + center_r, cy + center_r],
        fill=WHITE,
    )

    # ── "CF" monogram ─────────────────────────────────────────────────────────
    if size >= 40:
        font_size = max(8, round(center_r * 0.94))
        font = _load_font(font_size)
        text = "CF"

        # Centre the text inside the white circle
        bbox_t = draw.textbbox((0, 0), text, font=font)
        tw = bbox_t[2] - bbox_t[0]
        th = bbox_t[3] - bbox_t[1]
        tx = cx - tw / 2 - bbox_t[0]
        ty = cy - th / 2 - bbox_t[1]
        draw.text((tx, ty), text, fill=CENTER_TEXT_FG, font=font)

    # ── Tiny paintbrush accent in bottom-right segment ────────────────────────
    if size >= 200:
        _draw_brush(draw, cx, cy, size)

    return img


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """Try to load a bold system font; fall back to the PIL default."""
    candidates = [
        # macOS system fonts
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
        # Linux / CI fonts
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def _draw_brush(draw: ImageDraw.ImageDraw, cx, cy, size):
    """Draw a small stylised paintbrush in the bottom-right segment."""
    # Brush centre is at ~65 % from icon centre toward lower-right boundary
    bx = cx + size * 0.255
    by = cy + size * 0.255
    s  = size * 0.095   # scale factor

    def rot(x, y, deg):
        """Rotate point (x,y) by deg degrees around origin."""
        r = math.radians(deg)
        return (x * math.cos(r) - y * math.sin(r),
                x * math.sin(r) + y * math.cos(r))

    def tp(x, y):
        """Translate rotated brush-local point to canvas."""
        rx, ry = rot(x * s, y * s, -45)
        return (bx + rx, by + ry)

    # Handle (yellow)
    handle = [tp(-0.45, -4.5), tp(0.45, -4.5), tp(0.45, -1.1), tp(-0.45, -1.1)]
    draw.polygon(handle, fill=(254, 202, 87, 200))

    # Ferrule (light grey)
    ferrule = [tp(-0.50, -1.1), tp(0.50, -1.1), tp(0.50, -0.4), tp(-0.50, -0.4)]
    draw.polygon(ferrule, fill=(210, 210, 210, 200))

    # Bristle body (white)
    bristle = [tp(-0.42, -0.4), tp(0.42, -0.4), tp(0.28, 1.5), tp(-0.28, 1.5)]
    draw.polygon(bristle, fill=(240, 240, 240, 200))

    # Bristle tip (grey)
    tip = [tp(-0.28, 1.45), tp(0.28, 1.45), tp(0.0, 2.6)]
    draw.polygon(tip, fill=(180, 180, 180, 200))


# ── Required icon sizes ──────────────────────────────────────────────────────
#
# (pixel_size, xcode_size_label, scale, idiom)
#
ICON_SPECS = [
    # iPad notification
    (20,   "20x20",      "1x", "ipad"),
    (40,   "20x20",      "2x", "ipad"),
    # iPad settings
    (29,   "29x29",      "1x", "ipad"),
    (58,   "29x29",      "2x", "ipad"),
    # iPad spotlight
    (40,   "40x40",      "1x", "ipad"),
    (80,   "40x40",      "2x", "ipad"),
    # iPad home screen
    (76,   "76x76",      "1x", "ipad"),
    (152,  "76x76",      "2x", "ipad"),
    # iPad Pro home screen
    (167,  "83.5x83.5",  "2x", "ipad"),
    # App Store
    (1024, "1024x1024",  "1x", "ios-marketing"),
]


def main():
    out_dir = Path("AppIcon.appiconset")
    out_dir.mkdir(exist_ok=True)

    print("Rendering master icon at 1024 × 1024 …")
    master = draw_icon(1024)

    generated = []
    seen_sizes = {}   # pixel_size → filename (reuse identical sizes)

    for px, size_label, scale, idiom in ICON_SPECS:
        # Derive a unique filename
        base = f"AppIcon-{size_label}@{scale}"
        if scale == "1x" and px == int(size_label.split("x")[0]):
            base = f"AppIcon-{px}"   # cleaner name for 1× icons
        filename = f"{base}.png"

        if px not in seen_sizes:
            icon = master.resize((px, px), Image.LANCZOS)
            icon.save(out_dir / filename, "PNG", optimize=True)
            seen_sizes[px] = filename
            print(f"  ✓ {filename:36s}  ({px}×{px})")
        else:
            # Hard-link / copy already-rendered file instead of re-rendering
            existing = out_dir / seen_sizes[px]
            (out_dir / filename).write_bytes(existing.read_bytes())
            print(f"  ↳ {filename:36s}  ({px}×{px})  [reuse]")

        generated.append((filename, size_label, scale, idiom))

    # ── Write Contents.json ──────────────────────────────────────────────────
    import json
    images = []
    for filename, size_label, scale, idiom in generated:
        entry = {
            "filename": filename,
            "idiom":    idiom,
            "scale":    scale,
            "size":     size_label,
        }
        if idiom == "ios-marketing":
            entry.pop("scale")   # marketing icon has no scale key
        images.append(entry)

    contents = {
        "images": images,
        "info": {"author": "colorflow-generator", "version": 1},
    }
    (out_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n"
    )
    print(f"\n✅  Contents.json written.")
    print(f"\nDone!  Copy  {out_dir}/  →  YourProject/Assets.xcassets/AppIcon.appiconset/")


if __name__ == "__main__":
    main()
