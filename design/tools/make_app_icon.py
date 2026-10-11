#!/usr/bin/env python3
"""Draws Derin's app icons (1024×1024): the four-point star over a night or dawn sky.
Run: python3 design/tools/make_app_icon.py"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2] / "App/Resources/Assets.xcassets"
S = 1024


def gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def star_path(cx, cy, r, pinch=0.12, steps=60):
    """Four-point star with curved flanks, like the app's spark glyph."""
    pts = []
    for i in range(4):
        a0 = math.radians(i * 90 - 90)
        a1 = math.radians(i * 90)
        tip = (cx + r * math.cos(a0), cy + r * math.sin(a0))
        nxt = (cx + r * math.cos(a1), cy + r * math.sin(a1))
        ctrl = (cx + r * pinch * math.cos((a0 + a1) / 2) * 1.6, cy + r * pinch * math.sin((a0 + a1) / 2) * 1.6)
        for s in range(steps):
            t = s / steps
            x = (1 - t) ** 2 * tip[0] + 2 * (1 - t) * t * ctrl[0] + t ** 2 * nxt[0]
            y = (1 - t) ** 2 * tip[1] + 2 * (1 - t) * t * ctrl[1] + t ** 2 * nxt[1]
            pts.append((x, y))
    return pts


def icon(name, top, bottom, dots, star, halo):
    img = gradient(top, bottom).convert("RGBA")
    rnd = random.Random(12)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # faint celestial grid arcs
    for r in (620, 760, 900):
        d.ellipse([S / 2 - r, S * 1.25 - r, S / 2 + r, S * 1.25 + r], outline=dots + (22,), width=3)
    for _ in range(70):
        x, y = rnd.uniform(0, S), rnd.uniform(0, S * 0.8)
        rr = rnd.choice([2, 2.5, 3, 4])
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=dots + (rnd.randint(70, 200),))
    img = Image.alpha_composite(img, layer)
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([S / 2 - 250, S / 2 - 250, S / 2 + 250, S / 2 + 250], fill=halo + (110,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(120)))
    shape = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shape)
    sd.polygon(star_path(S / 2, S / 2, 330), fill=star + (255,))
    sd.ellipse([S / 2 - 46, S / 2 - 46, S / 2 + 46, S / 2 + 46], fill=(255, 248, 230, 255))
    img = Image.alpha_composite(img, shape)
    img.convert("RGB").save(ROOT / f"{name}.appiconset/{name}.png")


icon("AppIcon", (20, 27, 62), (9, 13, 34), (236, 230, 214), (242, 196, 109), (242, 196, 109))
icon("AppIconDawn", (246, 247, 251), (203, 209, 226), (39, 48, 92), (154, 116, 36), (242, 196, 109))
