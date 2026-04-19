#!/usr/bin/env python3
"""Compare two PNG screenshots using pure stdlib (no pip deps).
Uses sips to resize to common dimensions, then zlib to decompress
PNG scanlines and compute RMS pixel difference."""

import subprocess
import struct
import zlib
import sys
import os
import tempfile
import math


def resize_png(path, w, h):
    """Use sips to resize PNG to w×h, return temp file path."""
    tmp = tempfile.mktemp(suffix=".png")
    subprocess.run(
        ["sips", "-z", str(h), str(w), path, "--out", tmp],
        capture_output=True,
        check=True,
    )
    return tmp


def read_png_pixels(path):
    """Read PNG, return (width, height, pixel_bytes as bytearray)."""
    with open(path, "rb") as f:
        data = f.read()

    # Verify PNG signature
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a valid PNG: {path}")

    pos = 8
    width = height = 0
    idat_data = b""

    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        chunk_type = data[pos + 4 : pos + 8].decode("ascii")
        chunk_data = data[pos + 8 : pos + 8 + length]

        if chunk_type == "IHDR":
            width = struct.unpack(">I", chunk_data[0:4])[0]
            height = struct.unpack(">I", chunk_data[4:8])[0]
        elif chunk_type == "IDAT":
            idat_data += chunk_data

        pos += 12 + length  # 4 (length) + 4 (type) + length + 4 (crc)

    if not idat_data:
        raise ValueError(f"No IDAT chunks found in {path}")

    # Decompress IDAT data
    raw = zlib.decompress(idat_data)

    # Remove filter bytes (first byte of each row is filter type)
    pixels = bytearray()
    row_bytes = width * 4  # RGBA = 4 bytes per pixel
    for y in range(height):
        row_start = y * (row_bytes + 1) + 1  # +1 to skip filter byte
        row_end = (y + 1) * (row_bytes + 1)
        pixels.extend(raw[row_start:row_end])

    return width, height, bytes(pixels)


def compare(baseline_path, current_path, threshold=0.03):
    """Compare two PNG screenshots. Return (passed, diff_percent, message)."""
    if not os.path.exists(baseline_path):
        return False, 0.0, f"Baseline not found: {baseline_path}"
    if not os.path.exists(current_path):
        return False, 0.0, f"Current screenshot not found: {current_path}"

    # Read baseline dimensions
    b_w, b_h, _ = read_png_pixels(baseline_path)

    # Resize current to match baseline if needed
    c_w, c_h, _ = read_png_pixels(current_path)
    effective_current = current_path
    if b_w != c_w or b_h != c_h:
        effective_current = resize_png(current_path, b_w, b_h)

    # Read pixels
    _, _, b_pixels = read_png_pixels(baseline_path)
    _, _, c_pixels = read_png_pixels(effective_current)

    n = len(b_pixels)
    if n != len(c_pixels):
        return False, 0.0, f"Pixel count mismatch: {n} vs {len(c_pixels)}"
    if n == 0:
        return True, 0.0, "Empty image"

    # Compute RMS difference
    sum_sq = sum((a - b) ** 2 for a, b in zip(b_pixels, c_pixels))
    rms = math.sqrt(sum_sq / n) / 255.0

    passed = rms <= threshold
    status = "PASS" if passed else "FAIL"
    message = f"{status}: pixel_diff={rms:.4f} (threshold={threshold})"

    # Clean up temp file
    if effective_current != current_path:
        try:
            os.unlink(effective_current)
        except OSError:
            pass

    return passed, rms, message


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: diff_screenshots.py <baseline> <current> [threshold]")
        sys.exit(1)

    baseline = sys.argv[1]
    current = sys.argv[2]
    threshold = float(sys.argv[3]) if len(sys.argv) > 3 else 0.03

    passed, diff, message = compare(baseline, current, threshold)
    print(message)
    sys.exit(0 if passed else 1)
