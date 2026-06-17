#!/usr/bin/env python3
"""Split delver_body.png into a bald base + hair overlay (same 389x906 canvas).

Run from repo root:
  python3 capture/split_delver_hair.py

Requires: python3 -m venv .venv && .venv/bin/pip install pillow
"""
from __future__ import annotations

from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit(
        "Pillow is required. Try: python3 -m venv .venv && .venv/bin/pip install pillow"
    ) from exc

ROOT = Path(__file__).resolve().parents[1]
BODY = ROOT / "art/portraits/delver_body.png"
HAIR_OUT = ROOT / "art/portraits/delver_hair.png"
BALD_OUT = ROOT / "art/portraits/delver_body_bald.png"


def is_skin(r: int, g: int, b: int, a: int) -> bool:
    return a > 40 and r > 125 and g > 90 and b > 70


def main() -> None:
    body = Image.open(BODY).convert("RGBA")
    w, h = body.size
    pixels = body.load()
    hair = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hair_px = hair.load()
    bald = body.copy()
    bald_px = bald.load()

    def is_hair(x: int, y: int, r: int, g: int, b: int, a: int) -> bool:
        if a < 25 or y > 268:
            return False
        if is_skin(r, g, b, a):
            return False
        if 155 <= x <= 295 and 95 <= y <= 205 and (r + g + b) < 260:
            return False
        return y < 265 and r < 145 and g < 125 and b < 110

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if is_hair(x, y, r, g, b, a):
                hair_px[x, y] = (r, g, b, a)
                bald_px[x, y] = (0, 0, 0, 0)

    hair.save(HAIR_OUT)
    bald.save(BALD_OUT)
    print(f"Wrote {HAIR_OUT.name} bbox={hair.getbbox()}")
    print(f"Wrote {BALD_OUT.name}")


if __name__ == "__main__":
    main()
