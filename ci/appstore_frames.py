#!/usr/bin/env python3
"""App Store images: each chosen screenshot under a short headline, on the app's night sky.

Usage: appstore_frames.py <screenshots dir> <out dir>
Reads <mode>-<screen>.png from screenshots.sh (6.9", 1320x2868) and writes <out>/<locale>/NN-<screen>.png at the
same size, one folder per App Store locale (asc_listing.py uploads them from there).
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Order on the store page: the screen it shows and its Turkish and English headline.
FRAMES = [
    ("home", "Kendi gökyüzünü odaklanarak kur", "Build your own sky by focusing"),
    ("active", "Odaklanırken dikkatin dağılmasın", "Focus without distractions"),
    ("reward", "Her odak gökyüzüne yeni bir yıldız ekler", "Every focus adds a new star"),
    ("constellation", "Yıldızların takımyıldız olur", "Your stars become constellations"),
    ("calendar", "Gerçek gökyüzü olaylarını kaçırma", "Never miss a night in the real sky"),
    ("lockscreen", "Kalan süreyi kilit ekranında gör", "See the time left on your Lock Screen"),
    ("journey", "Gökyüzü bitince Işık yolculuğu başlar", "When the sky is full, the journey begins"),
]
# locale: (headline column in FRAMES, file prefix of that language's screenshots)
LOCALES = {"tr": (1, "dark-"), "en-US": (2, "dark-en-")}

W, H = 1320, 2868
TOP, BOTTOM = (11, 13, 22), (24, 29, 56)
INK, GOLD = (236, 231, 220), (216, 183, 106)
SHOT_W = 1040
SERIF = [
    "/System/Library/Fonts/NewYork.ttf",
    "/Library/Fonts/NewYork.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
]


def font(size):
    for path in SERIF:
        if os.path.exists(path):
            f = ImageFont.truetype(path, size)
            text_cut(f)
            return f
    return ImageFont.load_default(size)


def text_cut(f):
    """New York is a variable font whose default is its hairline display cut, which loses the H's crossbar
    at this size. Pick the sturdier text optical size and a medium weight instead."""
    try:
        axes = f.get_variation_axes()
    except OSError:
        return
    want = {"opsz": 20, "optical": 20, "wght": 500, "weight": 500}
    values = []
    for axis in axes:
        name = axis.get("name", b"")
        name = (name.decode(errors="ignore") if isinstance(name, bytes) else str(name)).lower()
        target = next((v for k, v in want.items() if k in name), axis["default"])
        values.append(min(max(target, axis["minimum"]), axis["maximum"]))
    print(f"font axes {axes} -> {values}")
    f.set_variation_by_axes(values)


def sky():
    img = Image.new("RGB", (W, H))
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        px.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    rnd = random.Random(7)
    for _ in range(260):
        x, y, r = rnd.uniform(0, W), rnd.uniform(0, H), rnd.choice([1, 1, 1, 1.5, 2])
        a = rnd.randint(60, 180)
        px.ellipse([x - r, y - r, x + r, y + r], fill=tuple(round(c * a / 255 + bg * (1 - a / 255)) for c, bg in zip(INK, TOP)))
    return img


def sparkle(draw, cx, cy, r):
    """The app's four-pointed star, drawn so it doesn't depend on the font having the glyph."""
    t = r * 0.22
    draw.polygon([(cx, cy - r), (cx + t, cy - t), (cx + r, cy), (cx + t, cy + t),
                  (cx, cy + r), (cx - t, cy + t), (cx - r, cy), (cx - t, cy - t)], fill=GOLD)


def wrap(draw, text, f, width):
    lines, line = [], ""
    for word in text.split():
        test = f"{line} {word}".strip()
        if draw.textlength(test, font=f) <= width or not line:
            line = test
        else:
            lines.append(line)
            line = word
    return lines + [line]


def frame(shot, headline):
    img = sky()
    draw = ImageDraw.Draw(img)

    f = font(100)
    lines = wrap(draw, headline, f, W - 200)
    line_h = 122
    block = len(lines) * line_h
    top = 150 + (2 * line_h - block) // 2
    sparkle(draw, W / 2, top - 64, 26)
    for i, line in enumerate(lines):
        draw.text((W / 2, top + i * line_h + line_h / 2), line, font=f, fill=INK, anchor="mm")

    phone = shot.resize((SHOT_W, round(shot.height * SHOT_W / shot.width)), Image.LANCZOS)
    x, y = (W - SHOT_W) // 2, 520
    radius = 96
    mask = Image.new("L", phone.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *phone.size], radius=radius, fill=255)

    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).rounded_rectangle([x - 6, y - 6, x + SHOT_W + 6, y + phone.height + 6], radius=radius + 6, fill=90)
    img.paste(Image.new("RGB", (W, H), GOLD), (0, 0), glow.filter(ImageFilter.GaussianBlur(40)))
    ImageDraw.Draw(img).rounded_rectangle([x - 4, y - 4, x + SHOT_W + 4, y + phone.height + 4], radius=radius + 4, fill=(48, 52, 74))
    img.paste(phone, (x, y), mask)
    return img


def main():
    src, out = sys.argv[1], sys.argv[2]
    for locale, (column, prefix) in LOCALES.items():
        os.makedirs(os.path.join(out, locale), exist_ok=True)
        for n, row in enumerate(FRAMES, 1):
            screen = row[0]
            path = os.path.join(src, f"{prefix}{screen}.png")
            if not os.path.exists(path):
                print(f"missing {path}")
                continue
            frame(Image.open(path).convert("RGB"), row[column]).save(os.path.join(out, locale, f"{n:02d}-{screen}.png"))
            print(f"framed {locale}/{n:02d}-{screen}")


if __name__ == "__main__":
    main()
