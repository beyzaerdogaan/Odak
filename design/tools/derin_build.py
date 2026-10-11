#!/usr/bin/env python3
"""Generates the 12 Derin screens (design/derin/*.dc.html) in the "gök atlası" visual language.

Every screen keeps the Claude Design (DC) wrapper: <x-dc>, <helmet>, {{accent}} prop.
Shared tokens live in CSS below; each file gets its own copy because DC screens are standalone.
Run: python3 design/tools/derin_build.py
"""
import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "derin"

FONTS = ("https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;"
         "1,6..72,400;1,6..72,500&amp;family=Hanken+Grotesk:wght@400;500;600;700&amp;display=swap")

CSS = """
body{margin:0;background:#090D22}
@media (prefers-color-scheme:light){body{background:#E8EBF4}}
/* Tokens. Dark is the night sky; light is a dawn star atlas printed in navy ink. */
.scr{--night:#090D22;--night-2:#0E1430;--deep:#05081A;--plate:rgba(236,230,214,.045);--plate-2:rgba(236,230,214,.08);
  --hair:rgba(236,230,214,.11);--paper:#ECE6D6;--paper-2:#A7ADC6;--paper-3:#6E7597;--paper-body:#CFCBC0;--star:#ECE6D6;
  --acc-ink:var(--accent);--acc-fill:var(--accent);--on-acc:#1C1404;--core:#FFF8E6;--shade:rgba(0,0,0,.45);
  --nebula:#E6A6C7;--ice:#A8C4FF;--aurora:#8FDCC0;--aurora-2:#B5D8C9;--meteor:#C9B8FF;--meteor-2:#D6CFF0;--ember:#F0A070;--alarm:#F2A49A;
  --ev-1:#1E1744;--ev-2:#0E0B24;--ev-3:#0A0A1C;--ev-card-1:#2A2150;--ev-card-2:#151236;--on-meteor:#18123A;--trail:#F4EEFF;
  --astro-m:-22px;--astro-bg:transparent;--astro-r:0;
  --pr-1:#2A200C;--pr-2:#140F07;--pr-3:#0E0A05;--pr-star:#F6D98E;--pr-paper:#F5EEDC;--pr-body:#E2D8BE;--pr-3txt:#B5AA8E;
  position:relative;width:390px;height:844px;box-sizing:border-box;overflow:hidden;background:var(--night);
  color:var(--paper);font:400 15px/1.4 'Hanken Grotesk',sans-serif;-webkit-font-smoothing:antialiased;
  display:flex;flex-direction:column}
@media (prefers-color-scheme:light){.scr:not([data-theme=dark]){LIGHT}}
.scr[data-theme=light]{LIGHT}
"""
LIGHT = """--night:#E8EBF4;--night-2:#F6F7FB;--deep:#CBD1E2;--plate:rgba(27,33,64,.055);--plate-2:rgba(27,33,64,.09);
  --hair:rgba(27,33,64,.13);--paper:#1B2140;--paper-2:#4F5779;--paper-3:#7D84A2;--paper-body:#353C5E;--star:#27305C;
  --acc-ink:color-mix(in srgb,var(--accent) 55%,#3D2A00);--acc-fill:color-mix(in srgb,var(--accent) 80%,#5A3D00);--core:#FFFDF5;--shade:rgba(27,33,64,.18);
  --nebula:#A8487A;--ice:#3557B8;--aurora:#1C7D60;--aurora-2:#2F6B58;--meteor:#5D47BE;--meteor-2:#463A7A;--ember:#B9582A;--alarm:#B23A30;
  --ev-1:#D9D3F2;--ev-2:#E9E5F7;--ev-3:#F2F0FA;--ev-card-1:#E4DDFA;--ev-card-2:#F1EEFC;--on-meteor:#FFFFFF;--trail:#5D47BE;
  --astro-m:0;--astro-bg:#0E1430;--astro-r:22px;
  --pr-1:#F3E2B4;--pr-2:#F7EEDA;--pr-3:#FBF6EA;--pr-star:#9A7424;--pr-paper:#2A2110;--pr-body:#4A3D22;--pr-3txt:#7A6A48;color-scheme:light"""
CSS = CSS.replace("LIGHT", LIGHT)
RULES = """
.scr *{box-sizing:border-box}
:where(.scr) a{color:inherit;text-decoration:none}
:where(.scr) button{font:inherit;color:inherit;background:none;border:0;padding:0;cursor:pointer}
.scr :focus-visible{outline:2px solid var(--accent);outline-offset:3px;border-radius:8px}
.sky{position:absolute;inset:0;pointer-events:none}
.layer{position:relative;display:flex;flex-direction:column;flex:1;min-height:0}
.layer>*{flex-shrink:0}
.serif{font-family:'Newsreader',serif;font-optical-sizing:auto;font-weight:400;letter-spacing:-.01em}
.it{font-style:italic}
.h1{margin:0;font-family:'Newsreader',serif;font-weight:400;font-size:36px;line-height:1.05;letter-spacing:-.02em}
.h2{margin:0;font-size:15px;font-weight:600;letter-spacing:-.005em}
.meta{margin:0;font-size:13px;color:var(--paper-2)}
.small{font-size:12px;color:var(--paper-3)}
.num{font-variant-numeric:tabular-nums lining-nums}
.acc{color:var(--acc-ink)}
.fa{fill:var(--acc-fill)}
.sa{stroke:var(--acc-fill)}
.rule{height:1px;background:var(--hair);border:0;margin:0}
.row{display:flex;align-items:center;gap:12px}
.between{display:flex;justify-content:space-between;align-items:baseline;gap:12px}
.btn{height:56px;border-radius:28px;display:flex;align-items:center;justify-content:center;gap:10px;
  font:600 16px 'Hanken Grotesk',sans-serif;letter-spacing:-.005em}
.btn-acc{background:var(--accent);color:#1C1404;box-shadow:0 10px 30px -12px var(--accent)}
.btn-ghost{height:50px;border:1px solid var(--hair);color:var(--paper);font-weight:500;font-size:15px}
.seg{display:grid;gap:2px;padding:3px;border-radius:999px;background:var(--plate)}
.seg>*{min-height:38px;border-radius:999px;display:flex;align-items:center;justify-content:center;font-size:14px;
  font-weight:500;color:var(--paper-2)}
.seg>[aria-pressed=true],.seg>[aria-checked=true],.seg>[aria-selected=true]{background:var(--paper);color:var(--night);font-weight:600}
.chip{display:inline-flex;align-items:center;gap:6px;height:32px;padding:0 12px;border-radius:999px;font-size:13px;
  color:var(--paper);background:var(--plate)}
.tog{flex:none;width:51px;height:31px;border-radius:999px;background:rgba(236,230,214,.16);padding:2px;display:flex}
.tog::after{content:"";width:27px;height:27px;border-radius:50%;background:#FFF;box-shadow:0 2px 6px rgba(0,0,0,.35)}
.tog[aria-pressed=true]{background:var(--accent);justify-content:flex-end}
.list>*{border-bottom:1px solid var(--hair)}
.list>*:last-child{border-bottom:0}
.bar{height:4px;border-radius:999px;background:var(--plate-2);overflow:hidden}
.bar>i{display:block;height:100%;border-radius:999px;background:var(--accent)}
.price{flex:none;display:inline-flex;align-items:center;gap:5px;height:36px;padding:0 13px;border-radius:999px;
  border:1px solid color-mix(in srgb,var(--acc-fill) 50%,transparent);color:var(--acc-ink);font-size:14px;font-weight:600}
.tabbar{position:absolute;left:0;right:0;bottom:0;height:84px;padding:8px 12px 0;display:flex;justify-content:space-around;
  align-items:flex-start;background:linear-gradient(to top,rgba(9,13,34,.98) 55%,rgba(9,13,34,0));}
.tabbar a{min-width:72px;min-height:48px;display:flex;flex-direction:column;align-items:center;gap:4px;font-size:11px;
  font-weight:500;color:var(--paper-3)}
.tabbar a[aria-current=page]{color:var(--acc-ink)}
.iconbtn{flex:none;width:44px;height:44px;border-radius:50%;background:var(--plate);display:flex;align-items:center;justify-content:center}
@keyframes ignite{0%{transform:scale(.2) rotate(-30deg);opacity:0}60%{transform:scale(1.12) rotate(4deg);opacity:1}100%{transform:scale(1) rotate(0)}}
@keyframes halo{0%{opacity:0;transform:scale(.6)}100%{opacity:1;transform:scale(1)}}
.ignite{transform-origin:center;transform-box:fill-box;animation:ignite 1.1s cubic-bezier(.2,.8,.2,1) both .2s}
.halo{transform-origin:center;transform-box:fill-box;animation:halo 1.6s ease-out both}
@keyframes beckon{0%,100%{opacity:.45;transform:scale(.85)}50%{opacity:1;transform:scale(1.15)}}
.beckon{transform-origin:center;transform-box:fill-box;animation:beckon 2.6s ease-in-out infinite}
.astro{margin:0 var(--astro-m);background:var(--astro-bg);border-radius:var(--astro-r);overflow:hidden}
.astro svg{width:100%;height:auto;margin:0!important}
@media (prefers-reduced-motion:reduce){.ignite,.halo,.beckon{animation:none}}
"""

ICON = {
    # four-point star: the app's mark for stars and Işık everywhere
    "spark": '<path d="M12 0C12.9 7.4 15.6 11 24 12 15.6 13 12.9 16.6 12 24 11.1 16.6 8.4 13 0 12 8.4 11 11.1 7.4 12 0Z"/>',
    "lock": '<rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V7.5a4 4 0 0 1 8 0V11"/>',
    "moon": '<path d="M20.5 13.2A8.5 8.5 0 1 1 10.8 3.5a6.6 6.6 0 0 0 9.7 9.7z"/>',
    "timer": '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 10v3.5l2.5 1.8M9.5 2.5h5"/>',
    "gift": '<rect x="3.5" y="9" width="17" height="11.5" rx="2"/><path d="M12 9v11.5M3.5 13h17M12 9c-1.6-3.6-5.5-3.8-5.5-1.3S12 9 12 9s5.5-.8 5.5-1.3S13.6 5.4 12 9"/>',
    "note": '<path d="M9 18V5.5l11-2V16"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>',
    "pause": '<rect x="6.5" y="5" width="3.6" height="14" rx="1.2"/><rect x="13.9" y="5" width="3.6" height="14" rx="1.2"/>',
    "play": '<path d="M8 5.5v13l10.5-6.5z"/>',
    "close": '<path d="M6 6l12 12M18 6L6 18"/>',
    "back": '<path d="M15 5l-7 7 7 7"/>',
    "chev": '<path d="M9 5l7 7-7 7"/>',
    "cloud": '<path d="M7 18.5h10a4 4 0 0 0 .5-8A6 6 0 0 0 6 10a4.3 4.3 0 0 0 1 8.5z"/>',
    "compass": '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>',
    "rain": '<path d="M7 13.5h10a3.5 3.5 0 0 0 .4-7A5 5 0 0 0 7.5 6.5 3.5 3.5 0 0 0 7 13.5z"/><path d="M8.5 16.5l-1 3M12.5 16.5l-1 3M16.5 16.5l-1 3"/>',
    "tree": '<path d="M12 3l6 9h-4l4 6H6l4-6H6z"/><path d="M12 18v3"/>',
    "wave": '<path d="M2 12c2-2 4-2 6 0s4 2 6 0 4-2 6 0M2 17c2-2 4-2 6 0s4 2 6 0 4-2 6 0"/>',
    "fire": '<path d="M12 3c3 4 5 6 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3 0-6 1-9z"/>',
    "noise": '<path d="M3 12h2M7 8v8M11 5v14M15 9v6M19 11v2"/>',
    "snow": '<path d="M12 2v20M4 6.5l16 11M20 6.5l-16 11"/>',
    "scope": '<path d="M3 15l12-6 2 4-12 6zM15 9l3-1.5 2 4-3 1.5M9 18l-2 4M9 18l3 4"/>',
    "shoot": '<path d="M20 4L9.5 14.5M14 4h6v6"/><circle cx="7" cy="17" r="3"/>',
    "sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/>',
    "sprout": '<path d="M12 21v-8M12 13c0-4 3-7 7-7 0 4-3 7-7 7zM12 15c0-3-2-5-5-5 0 3 2 5 5 5z"/>',
    "meteor": '<path d="M21 3L11 13M17 3h4v4M14 4L6 12M20 10l-8 8"/><circle cx="6" cy="18" r="2.5"/>',
    "orbit": '<circle cx="12" cy="12" r="2.6"/><ellipse cx="12" cy="12" rx="9.5" ry="4.2" transform="rotate(-24 12 12)"/><circle cx="19.6" cy="8.2" r="1.3" fill="currentColor" stroke="none"/>',
    "zenith": '<path d="M3 20h18"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0" stroke-dasharray="1.6 2.6"/><path d="M12 3l1.3 2.7 2.9.4-2.1 2 .5 2.9L12 9.6 9.4 11l.5-2.9-2.1-2 2.9-.4z"/>',
    "bell": '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
}


import re

# UI colours written as literals in the screen code map to theme tokens. Lower-case hex is
# artwork (album covers, planet discs, sky previews) and stays fixed in both modes.
TOKEN = {
    "#ECE6D6": "paper", "#A7ADC6": "paper-2", "#C3C6D4": "paper-2", "#6E7597": "paper-3", "#CFCBC0": "paper-body",
    "#090D22": "night", "#0B1026": "night", "#0E1430": "night-2", "#0C1129": "night-2", "#05081A": "deep",
    "#1C1404": "on-acc", "#F2C46D": "acc-fill", "#FFF8E6": "core",
    "#A8C4FF": "ice", "#C9DAFF": "ice", "#C9B8FF": "meteor", "#D8CCFF": "meteor", "#CFC6EE": "meteor-2", "#DCD6F0": "meteor-2",
    "#8FDCC0": "aurora", "#B5D8C9": "aurora-2", "#F0A070": "ember", "#E6A6C7": "nebula", "#F0C2DC": "nebula", "#F2A49A": "alarm",
    "#1E1744": "ev-1", "#0E0B24": "ev-2", "#0A0A1C": "ev-3", "#2A2150": "ev-card-1", "#151236": "ev-card-2",
    "#18123A": "on-meteor", "#F4EEFF": "trail",
    "#2A200C": "pr-1", "#140F07": "pr-2", "#0E0A05": "pr-3", "#F6D98E": "pr-star", "#F5EEDC": "pr-paper",
    "#E2D8BE": "pr-body", "#D8CCAE": "pr-body", "#B5AA8E": "pr-3txt",
}
RGB = {(236, 230, 214): "paper", (9, 13, 34): "night", (242, 196, 109): "acc-fill", (168, 196, 255): "ice",
       (201, 184, 255): "meteor", (143, 220, 192): "aurora", (240, 160, 112): "ember", (242, 164, 154): "alarm"}


def _rgba(m):
    r, g, b, a = int(m[1]), int(m[2]), int(m[3]), float(m[4])
    tok = RGB.get((r, g, b))
    return f"color-mix(in srgb,var(--{tok}) {a * 100:g}%,transparent)" if tok else m[0]


def _tag(m):
    """SVG presentation attributes can't take var(), so token colours move into style."""
    tag = m[0]
    moved = []
    for attr in ("fill", "stroke", "stop-color"):
        a = re.search(r'\s' + attr + r'="(#[0-9A-F]{6})"', tag)
        if a and a[1] in TOKEN:
            moved.append(f"{attr}:var(--{TOKEN[a[1]]})")
            tag = tag.replace(a[0], "")
    if not moved:
        return tag
    decl = ";".join(moved)
    if ' style="' in tag:
        return tag.replace(' style="', f' style="{decl};', 1)
    if tag.endswith("/>"):
        return tag[:-2] + f' style="{decl}"/>'
    return tag[:-1] + f' style="{decl}">'


def themify(html):
    html = re.sub(r"<[a-zA-Z][^<>]*>", _tag, html)
    html = re.sub(r"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)", _rgba, html)
    html = re.sub(r"#[0-9A-F]{6}\b", lambda m: f"var(--{TOKEN[m[0]]})" if m[0] in TOKEN else m[0], html)
    # accent used as text gets the darker ink in light mode
    html = re.sub(r"(?<![-\w])color:\s*var\(--accent\)", "color:var(--acc-ink)", html)
    return html


def icon(name, size=20, color="currentColor", fill=False, sw=1.7, cls=""):
    attrs = (f'fill="{color}"' if fill else f'fill="none" stroke="{color}" stroke-width="{sw}" '
             'stroke-linecap="round" stroke-linejoin="round"')
    c = f' class="{cls}"' if cls else ""
    return f'<svg{c} width="{size}" height="{size}" viewBox="0 0 24 24" {attrs} aria-hidden="true">{ICON[name]}</svg>'


def spark(size=14, cls="fa", extra=""):
    return f'<svg class="{cls}" width="{size}" height="{size}" viewBox="0 0 24 24" aria-hidden="true" {extra}>{ICON["spark"]}</svg>'


def starfield(seed, w=390, h=844, n=90, tint="#ECE6D6", top=0, bottom=None, grid=True, gx=195, gy=1150):
    """Seeded star field with a faint celestial grid (declination arcs + hour ticks)."""
    rnd = random.Random(seed)
    bottom = h if bottom is None else bottom
    out = [f'<svg class="sky" width="{w}" height="{h}" viewBox="0 0 {w} {h}" aria-hidden="true">']
    if grid:
        out.append('<g fill="none" stroke="#ECE6D6" stroke-opacity=".045" stroke-width="1">')
        for r in (520, 640, 760, 880, 1000):
            out.append(f'<circle cx="{gx}" cy="{gy}" r="{r}"/>')
        for a in range(-60, 61, 15):
            if a == 0:
                continue
            t = math.radians(a - 90)
            x1, y1 = gx + 520 * math.cos(t), gy + 520 * math.sin(t)
            x2, y2 = gx + 1000 * math.cos(t), gy + 1000 * math.sin(t)
            out.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}"/>')
        out.append('</g>')
    out.append(f'<g fill="{tint}">')
    for _ in range(n):
        x, y = rnd.uniform(0, w), rnd.uniform(top, bottom)
        fade = 1 - (y - top) / max(1, bottom - top) * 0.75
        r = rnd.choice([0.5, 0.6, 0.7, 0.8, 0.9, 1.1, 1.3])
        o = rnd.uniform(0.25, 0.85) * fade
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" opacity="{o:.2f}"/>')
    out.append('</g>')
    for _ in range(3):  # a few brighter stars with a soft halo
        x, y = rnd.uniform(20, w - 20), rnd.uniform(top, top + (bottom - top) * 0.5)
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.5" fill="{tint}" opacity=".08"/>'
                   f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.3" fill="{tint}" opacity=".9"/>')
    out.append('</svg>')
    return "".join(out)


def flare(cx, cy, r, color_cls="fa", halo_color="var(--accent)", cls=""):
    """A lit star drawn like a photographed one: core, diffraction spikes and halo."""
    s = r * 4.2
    return (f'<g class="{cls}">'
            f'<circle cx="{cx}" cy="{cy}" r="{r*3.2}" style="fill:{halo_color}" opacity=".10"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r*1.8}" style="fill:{halo_color}" opacity=".18"/>'
            f'<path class="{color_cls}" d="M{cx} {cy-s}C{cx+r*.35} {cy-r*.9} {cx+r*.9} {cy-r*.35} {cx+s} {cy}'
            f'C{cx+r*.9} {cy+r*.35} {cx+r*.35} {cy+r*.9} {cx} {cy+s}C{cx-r*.35} {cy+r*.9} {cx-r*.9} {cy+r*.35} {cx-s} {cy}'
            f'C{cx-r*.9} {cy-r*.35} {cx-r*.35} {cy-r*.9} {cx} {cy-s}Z"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r*.55}" fill="#FFF8E6"/></g>')


TABBAR_ITEMS = [("Home.dc.html", "orbit", "Evren"), ("Main.dc.html", "timer", "Odak"), ("Sky.dc.html", "moon", "Gökyüzü"), ("Rewards.dc.html", "gift", "Ödüller")]


def tabbar(current):
    items = []
    for href, ic, label in TABBAR_ITEMS:
        cur = ' aria-current="page"' if href == current else ""
        items.append(f'<a href="{href}"{cur}>{icon(ic, 24)}{label}</a>')
    return f'<nav class="tabbar" aria-label="Ana menü">{"".join(items)}</nav>'


def page(title, body, height=844, bg="#090D22", extra_css=""):
    return f"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link href="{FONTS}" rel="stylesheet">
<style>{CSS}{themify(RULES + extra_css)}</style>
</helmet>
{themify(body)}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"accent":{{"editor":"color","default":"#F2C46D","options":["#F2C46D","#8FB3FF","#7FD6B5"]}},"theme":{{"editor":"select","default":"auto","options":["auto","light","dark"]}},"$preview":{{"width":390,"height":{height}}}}}'>
class Component extends DCLogic {{
  renderVals() {{
    return {{ accent: this.props.accent ?? '#F2C46D', theme: this.props.theme ?? 'auto' }};
  }}
}}
</script>
</body>
</html>
"""


def root(inner, style="", cls=""):
    return f'<div class="scr {cls}" data-theme="{{{{theme}}}}" style="--accent: {{{{accent}}}}; {style}">{inner}</div>'


# ---------------------------------------------------------------- 1 · Odak kurulumu
def main_screen():
    durations = [("25", False), ("45", True), ("60", False), ("90", False), ("Özel", False)]
    seg = "".join(f'<button aria-pressed="{str(p).lower()}">{d}</button>' for d, p in durations)
    toggles = [
        ("Arama ve mesajları sustur", "iOS Odak modu “Derin” açılır", True),
        ("Favoriler arayabilsin", "Acil durumlar için 3 kişi", True),
        ("Katı mod", "Süre bitmeden kilit açılmaz, Işık ×1.5", False),
    ]
    rows = "".join(
        f'<div class="row" style="min-height:58px;justify-content:space-between"><div><p style="margin:0;font-size:15px;font-weight:500">{t}</p>'
        f'<p class="small" style="margin:2px 0 0">{s}</p></div><button class="tog" aria-label="{t}" aria-pressed="{str(on).lower()}"></button></div>'
        for t, s, on in toggles)
    body = f"""
{starfield(1, n=46, bottom=230, grid=False)}
<div class="layer" style="padding:56px 22px 22px;gap:19px">
  <header style="display:flex;flex-direction:column;gap:10px">
    <p class="meta row" style="gap:8px"><span class="row acc" style="gap:5px;font-weight:600">{spark(12)}6 günlük seri</span><span>Bugün 1 sa 10 dk odaklandın</span></p>
    <h1 class="h1">Ne üzerinde<br>odaklanıyorsun?</h1>
  </header>

  <label style="display:flex;flex-direction:column;gap:4px;border-bottom:1px solid var(--hair);padding-bottom:10px">
    <span class="small">Görev</span>
    <input id="task" value="Tez · Bölüm 3 literatür" style="all:unset;font:500 19px 'Hanken Grotesk',sans-serif;color:var(--paper)">
  </label>

  <section aria-labelledby="dur" style="display:flex;flex-direction:column;gap:12px">
    <div class="between">
      <h2 id="dur" class="meta" style="font-weight:500">Odak süresi</h2>
      <p class="serif num" style="margin:0;font-size:44px;line-height:.9">45<span style="font-size:18px;color:var(--paper-2);font-family:'Hanken Grotesk'"> dk</span></p>
    </div>
    <div class="seg" style="grid-template-columns:repeat(5,minmax(0,1fr))">{seg}</div>
    <p class="row" style="margin:0;gap:8px;font-size:13px;color:var(--paper-2)">{spark(13)}Bu oturum sana 1 yıldız ve yaklaşık 54 Işık kazandırır</p>
  </section>

  <section aria-labelledby="blk" style="display:flex;flex-direction:column;gap:12px">
    <div class="between" style="align-items:center">
      <h2 id="blk" class="h2">Engellenecek uygulamalar</h2>
      <a href="#" class="acc" style="font-size:14px;font-weight:600;min-height:44px;display:flex;align-items:center">Düzenle</a>
    </div>
    <div class="seg" role="radiogroup" aria-label="Engelleme modu" style="grid-template-columns:repeat(3,minmax(0,1fr));margin-top:-6px">
      <button role="radio" aria-checked="true">Seçtiklerim</button><button role="radio" aria-checked="false">Tümü</button><button role="radio" aria-checked="false">Yok</button>
    </div>
    <div style="display:flex;flex-wrap:wrap;gap:6px">
      <span class="chip">Sosyal medya <span style="color:var(--paper-3)">4</span></span><span class="chip">Video</span><span class="chip">Oyunlar</span><span class="chip" style="background:none;border:1px dashed var(--hair);color:var(--paper-2)">+ 3 uygulama</span>
    </div>
  </section>

  <section aria-label="Bildirimler ve mod" class="list" style="margin-top:-8px">{rows}</section>

  <a href="Active.dc.html" class="btn btn-acc" style="margin-top:auto">Odaklanmaya başla</a>
</div>"""
    return page("Odak kurulumu", root(body))


# ---------------------------------------------------------------- 2 · Odak sürüyor
def dial(size=284, minutes=45, elapsed_frac=0.709):
    c = size / 2
    r = c - 22
    ticks = []
    for i in range(minutes):
        a = math.radians(i / minutes * 360 - 90)
        major = i % 5 == 0
        r1, r2 = r + 9, r + (17 if major else 13)
        lit = i / minutes <= elapsed_frac
        col = "var(--acc-fill)" if lit else "#ECE6D6"
        op = (0.9 if major else 0.55) if lit else (0.35 if major else 0.16)
        ticks.append(f'<line x1="{c + r1*math.cos(a):.1f}" y1="{c + r1*math.sin(a):.1f}" x2="{c + r2*math.cos(a):.1f}" '
                     f'y2="{c + r2*math.sin(a):.1f}" style="stroke:{col}" stroke-opacity="{op}" stroke-width="{1.6 if major else 1}" stroke-linecap="round"/>')
    circ = 2 * math.pi * r
    head = math.radians(elapsed_frac * 360 - 90)
    hx, hy = c + r * math.cos(head), c + r * math.sin(head)
    return f"""<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" aria-hidden="true" style="position:absolute;inset:0;overflow:visible">
  <defs><radialGradient id="well"><stop offset=".55" stop-color="#0E1430"/><stop offset="1" stop-color="#0E1430" stop-opacity="0"/></radialGradient></defs>
  <circle cx="{c}" cy="{c}" r="{r+30}" fill="url(#well)"/>
  {''.join(ticks)}
  <circle cx="{c}" cy="{c}" r="{r}" fill="none" stroke="#ECE6D6" stroke-opacity=".08" stroke-width="2"/>
  <circle cx="{c}" cy="{c}" r="{r}" fill="none" class="sa" stroke-width="2.5" stroke-linecap="round" stroke-dasharray="{circ*elapsed_frac:.1f} {circ:.1f}" transform="rotate(-90 {c} {c})"/>
  {flare(round(hx,1), round(hy,1), 4.2)}
</svg>"""


def active_screen():
    body = f"""
{starfield(2, n=120, grid=True, gy=1250)}
<div class="layer" style="padding:62px 22px 26px;align-items:center;gap:22px">
  <header style="display:flex;flex-direction:column;align-items:center;gap:6px;text-align:center">
    <p class="meta row" style="gap:7px"><span style="width:6px;height:6px;border-radius:50%;background:var(--aurora);box-shadow:0 0 8px var(--aurora)"></span>Derin odak sürüyor</p>
    <h1 style="margin:0;font-size:18px;font-weight:500">Tez · Bölüm 3 literatür</h1>
  </header>

  <a href="Reward.dc.html" aria-label="Oturumu tamamla (prototip)" style="position:relative;width:284px;height:284px;display:flex;align-items:center;justify-content:center;margin-top:4px">
    {dial()}
    <div style="position:relative;display:flex;flex-direction:column;align-items:center;gap:6px">
      <p class="serif num" style="margin:0;font-size:68px;line-height:1;letter-spacing:-.03em">32:14</p>
      <p class="meta it serif" style="font-size:15px;text-align:center;line-height:1.3">Hangi yıldız?<br>Bitince göreceksin</p>
    </div>
  </a>

  <div style="display:flex;gap:8px;flex-wrap:wrap;justify-content:center">
    <span class="chip">{icon('lock', 14, '#A7ADC6', sw=2)}7 uygulama kilitli</span>
    <span class="chip">{icon('moon', 14, '#A7ADC6', sw=2)}Bildirimler susturuldu</span>
  </div>

  <div style="width:100%;display:grid;grid-template-columns:1fr 1px 1fr;align-items:center;text-align:center;padding:4px 0">
    <div><p class="serif num" style="margin:0;font-size:26px">12:46</p><p class="small" style="margin:2px 0 0">dakikadır telefona bakmadın</p></div>
    <span style="height:36px;background:var(--hair)"></span>
    <div><p class="serif num acc" style="margin:0;font-size:26px">+15</p><p class="small" style="margin:2px 0 0">Işık birikti</p></div>
  </div>

  <section aria-label="Çalan ses" class="row" style="width:100%;padding:8px 8px 8px 8px;border-radius:20px;background:var(--plate)">
    <span style="flex:none;width:44px;height:44px;border-radius:12px;background:linear-gradient(140deg,#1E4A52,#13233A);display:flex;align-items:center;justify-content:center">{icon('note', 20, '#8FDCC0')}</span>
    <a href="Sounds.dc.html" style="flex:1;min-width:0;min-height:44px;display:flex;flex-direction:column;justify-content:center">
      <span style="font-size:14px;font-weight:600">Derin Odak listesi</span>
      <span class="small">Spotify ve %30 yağmur sesi</span>
    </a>
    <button aria-label="Duraklat" class="iconbtn" style="background:var(--plate-2)">{icon('pause', 18, '#ECE6D6', fill=True)}</button>
  </section>

  <div style="margin-top:auto;width:100%;display:flex;flex-direction:column;gap:10px;align-items:center">
    <button class="btn btn-ghost" style="width:100%">5 dk mola ver <span style="color:var(--paper-3);font-weight:400">· 1 hakkın var</span></button>
    <button class="btn" style="width:100%;height:50px;font-size:15px;font-weight:500;color:var(--alarm);border:1px solid rgba(242,164,154,.28)">Vazgeçmek için basılı tut</button>
    <p class="small" style="margin:2px 0 0;text-align:center">Vazgeçersen yıldız söner, ama odakladığın dakikalar sayılır.</p>
  </div>
</div>"""
    return page("Odak sürüyor", root(body))


# ---------------------------------------------------------------- 2b · Ses ve müzik
def sounds_screen():
    tiles = [("rain", "Yağmur", "on"), ("tree", "Orman", ""), ("wave", "Dalga", ""), ("fire", "Şömine", ""),
             ("noise", "Kahverengi gürültü", ""), ("snow", "Kış gecesi", "ice"), ("lock", "Kütüphane", "locked"),
             ("lock", "Kahvehane", "locked")]
    t_html = []
    for ic, label, state in tiles:
        if state == "on":
            disc = f'<span style="width:56px;height:56px;border-radius:50%;background:rgba(143,220,192,.16);box-shadow:inset 0 0 0 1.5px var(--aurora);display:flex;align-items:center;justify-content:center">{icon(ic, 24, "#8FDCC0")}</span>'
            attr, col = 'aria-pressed="true"', "var(--paper)"
        elif state == "ice":
            disc = f'<span style="width:56px;height:56px;border-radius:50%;background:rgba(168,196,255,.10);display:flex;align-items:center;justify-content:center">{icon(ic, 24, "#A8C4FF")}</span>'
            attr, col = 'aria-pressed="false"', "var(--paper)"
        elif state == "locked":
            disc = f'<span style="width:56px;height:56px;border-radius:50%;border:1px dashed rgba(236,230,214,.22);display:flex;align-items:center;justify-content:center">{icon(ic, 20, "#6E7597", sw=2)}</span>'
            attr, col = 'aria-disabled="true"', "var(--paper-3)"
        else:
            disc = f'<span style="width:56px;height:56px;border-radius:50%;background:var(--plate);display:flex;align-items:center;justify-content:center">{icon(ic, 24, "#A7ADC6")}</span>'
            attr, col = 'aria-pressed="false"', "var(--paper)"
        t_html.append(f'<button {attr} style="display:flex;flex-direction:column;align-items:center;gap:7px;min-height:88px;font-size:12px;line-height:1.2;color:{col};text-align:center">{disc}{label}</button>')
    lists = [("Derin Odak", "Önerilen, enstrümantal", "linear-gradient(140deg,#2A6A6A,#13233A)", True),
             ("Lo-fi Çalışma", "Önerilen", "linear-gradient(140deg,#5A3E7A,#221A3A)", False),
             ("[KULLANICININ LİSTESİ]", "Senin çalma listelerin", "linear-gradient(140deg,#7A5A2A,#2A1E10)", False)]
    l_html = "".join(
        f'<button aria-pressed="{str(on).lower()}" class="row" style="min-height:62px;padding:8px 4px;text-align:left;width:100%">'
        f'<span aria-hidden="true" style="flex:none;width:44px;height:44px;border-radius:8px;background:{g}"></span>'
        f'<span style="flex:1;min-width:0"><span style="display:block;font-size:15px;font-weight:600;{"color:#8FDCC0" if on else ""}">{n}</span><span class="small" style="display:block">{s}</span></span>'
        f'{icon("play", 18, "#8FDCC0", fill=True) if on else ""}</button>' for n, s, g, on in lists)
    body = f"""
<div aria-hidden="true" style="position:absolute;inset:0;background:#05081A"></div>
<div aria-hidden="true" style="position:absolute;left:14px;right:14px;top:16px;height:40px;border-radius:24px 24px 0 0;background:#0C1129;opacity:.7"></div>
<div class="layer" style="margin-top:30px;border-radius:30px 30px 0 0;background:#0E1430;padding:10px 22px 24px;gap:24px;box-shadow:0 -20px 60px rgba(0,0,0,.5)">
  <span aria-hidden="true" style="align-self:center;width:38px;height:5px;border-radius:999px;background:rgba(236,230,214,.2)"></span>
  <header class="between" style="align-items:center">
    <h1 class="h1" style="font-size:30px">Ses ve müzik</h1>
    <a href="Active.dc.html" aria-label="Kapat" class="iconbtn">{icon('close', 18, '#A7ADC6', sw=2)}</a>
  </header>

  <section aria-labelledby="ortam" style="display:flex;flex-direction:column;gap:12px">
    <div class="between"><h2 id="ortam" class="h2">Ortam sesleri</h2><span class="small">2 sese kadar karıştır</span></div>
    <div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px 6px">{''.join(t_html)}</div>
    <div class="row" style="gap:14px">
      <label for="vol" style="font-size:13px;color:var(--paper-2);min-width:56px">Yağmur</label>
      <div style="flex:1;position:relative;height:28px;display:flex;align-items:center">
        <div class="bar" style="flex:1;height:6px"><i style="width:30%;background:var(--aurora)"></i></div>
        <span aria-hidden="true" style="position:absolute;left:calc(30% - 12px);width:24px;height:24px;border-radius:50%;background:#fff;box-shadow:0 2px 8px rgba(0,0,0,.4)"></span>
        <input id="vol" type="range" min="0" max="100" value="30" style="position:absolute;inset:0;opacity:0;width:100%">
      </div>
      <span class="num" style="font-size:13px;color:var(--paper-2);min-width:32px;text-align:right">%30</span>
    </div>
  </section>

  <hr class="rule">

  <section aria-labelledby="spot" style="display:flex;flex-direction:column;gap:4px">
    <div class="between" style="align-items:center">
      <div>
        <h2 id="spot" class="h2">Spotify</h2>
        <p class="row" style="margin:2px 0 0;gap:6px;font-size:12px;color:var(--aurora)"><span style="width:6px;height:6px;border-radius:50%;background:var(--aurora)"></span>Hesabın bağlı, odak boyunca engellenmez</p>
      </div>
      <a href="#" style="min-height:44px;display:flex;align-items:center;font-size:13px;color:var(--paper-2)">Bağlantıyı kes</a>
    </div>
    <div class="list">{l_html}</div>
  </section>

  <div class="row" style="margin-top:auto;justify-content:space-between;min-height:64px;padding:8px 16px;border-radius:20px;background:var(--plate)">
    <div><p style="margin:0;font-size:15px;font-weight:500">Bitince müziği durdur</p><p class="small" style="margin:2px 0 0">Molada ses yumuşakça azalır</p></div>
    <button class="tog" aria-label="Bitince müziği durdur" aria-pressed="true"></button>
  </div>
</div>"""
    return page("Ses ve müzik", root(body, style="background:#05081A"), bg="#05081A")


# ---------------------------------------------------------------- constellation drawing helper
ORION = {  # star: (x, y, radius)
    "Betelgeuse": (112, 22, 6.5), "Bellatrix": (214, 30, 4.4), "Alnitak": (150, 92, 3.6), "Alnilam": (170, 88, 3.8),
    "Mintaka": (190, 84, 3.6), "Saiph": (126, 152, 4.4), "Rigel": (226, 146, 6),
}
ORION_LINES = [("Betelgeuse", "Bellatrix"), ("Betelgeuse", "Alnitak"), ("Bellatrix", "Mintaka"), ("Alnitak", "Alnilam"),
               ("Alnilam", "Mintaka"), ("Alnitak", "Saiph"), ("Mintaka", "Rigel")]


def reward_orion():
    lines = []
    for a, b in ORION_LINES:
        (x1, y1, _), (x2, y2, _) = ORION[a], ORION[b]
        missing = "Betelgeuse" in (a, b)
        if missing:
            lines.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#ECE6D6" stroke-opacity=".22" stroke-width="1" stroke-dasharray="2 5"/>')
        else:
            lines.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" class="sa" stroke-opacity=".45" stroke-width="1.2"/>')
    stars = []
    for name, (x, y, r) in ORION.items():
        if name == "Betelgeuse":
            stars.append(f'<circle cx="{x}" cy="{y}" r="9" fill="none" stroke="#F0A070" stroke-opacity=".7" stroke-width="1.2" stroke-dasharray="2 3"/>')
        elif name == "Saiph":
            continue
        else:
            stars.append(f'<circle cx="{x}" cy="{y}" r="{r*1.9}" class="fa" opacity=".12"/><circle cx="{x}" cy="{y}" r="{r*.75}" class="fa"/>')
    sx, sy, sr = ORION["Saiph"]
    return f"""<svg width="340" height="176" viewBox="0 0 340 176" role="img" aria-label="Avcı takımyıldızı: 7 yıldızdan 6'sı yanık, Betelgeuse eksik" style="align-self:center;overflow:visible">
  {''.join(lines)}{''.join(stars)}
  {flare(sx, sy, 3.6, cls='ignite')}
  <text x="44" y="26" fill="#F0A070" font-size="12" font-style="italic" font-family="Newsreader, serif">Betelgeuse?</text>
  <text x="142" y="166" fill="#ECE6D6" font-size="13" font-style="italic" font-family="Newsreader, serif">Saiph</text>
  <text x="178" y="166" class="fa" font-size="11" font-family="Hanken Grotesk, sans-serif" font-weight="600">yeni</text>
</svg>"""


# ---------------------------------------------------------------- 3 · Ödül anı
def reward_screen():
    ledger = [("Odak süresi, 45 dk", "+45"), ("Hiç telefona bakmadın, %20", "+9"), ("Seri bonusu, 6. gün %10", "+5")]
    rows = "".join(
        f'<div class="row" style="gap:8px;font-size:14px"><span>{a}</span><span aria-hidden="true" style="flex:1;border-bottom:1px dotted rgba(236,230,214,.22);transform:translateY(-4px)"></span><span class="num">{b}</span></div>'
        for a, b in ledger)
    body = f"""
{starfield(3, n=70, bottom=420, grid=True, gy=1050)}
<div aria-hidden="true" style="position:absolute;left:50%;top:40px;width:420px;height:300px;transform:translateX(-50%);background:radial-gradient(closest-side,rgba(242,196,109,.16),transparent)"></div>
<div class="layer" style="padding:56px 22px 24px;gap:16px">
  <header style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:2px">
    <p class="meta">Yeni bir yıldız yaktın</p>
    <h1 class="serif it" style="margin:0;font-size:64px;line-height:1.05;letter-spacing:-.025em">Saiph</h1>
    <p class="meta" style="color:var(--paper)">Avcı takımyıldızında, 45 dakikalık derin odakla</p>
  </header>

  <section aria-labelledby="avci" style="display:flex;flex-direction:column;gap:6px;margin-top:2px">
    <div class="between"><h2 id="avci" class="h2">Avcı <span class="serif it" style="font-weight:400;color:var(--paper-2)">Orion</span></h2><span class="num acc" style="font-size:15px;font-weight:600">6 / 7</span></div>
    {reward_orion()}
    <p class="small" style="margin:0;color:var(--paper-2)">Son yıldız Betelgeuse parlak bir yıldız: yalnızca 60+ dk ya da katı mod oturumunda düşer.</p>
  </section>

  <hr class="rule">

  <section aria-labelledby="isik" style="display:flex;flex-direction:column;gap:8px">
    <h2 id="isik" class="meta" style="font-weight:500">Kazandığın Işık</h2>
    {rows}
    <div class="between" style="align-items:center;margin-top:2px"><span style="font-size:15px;font-weight:600">Toplam</span><span class="serif num acc row" style="font-size:34px;line-height:1;gap:6px">{spark(16)}+59</span></div>
  </section>

  <section aria-labelledby="soz" style="display:flex;flex-direction:column;gap:8px;padding:14px 16px;border-radius:20px;background:var(--plate)">
    <div class="between"><h2 id="soz" class="h2" style="font-size:14px">Söz: 10 saat sonra yeni bir kitap</h2><span class="num small" style="color:var(--paper-2)">9 / 10 sa</span></div>
    <div class="bar"><i style="width:90%"></i></div>
  </section>

  <div style="margin-top:auto;display:flex;flex-direction:column;gap:8px">
    <a href="Constellation.dc.html" class="btn btn-acc">5 dk mola ver</a>
    <a href="Sky.dc.html" class="btn btn-ghost">Gökyüzüme bak</a>
  </div>
</div>"""
    return page("Ödül anı", root(body))


# ---------------------------------------------------------------- 3b · Takımyıldız tamamlandı
def constellation_screen():
    pts = {k: (round(x * 1.2 + 2, 1), round(y * 1.2 + 6, 1), r) for k, (x, y, r) in ORION.items()}
    lines = "".join(
        f'<line x1="{pts[a][0]}" y1="{pts[a][1]}" x2="{pts[b][0]}" y2="{pts[b][1]}" class="sa" stroke-opacity=".6" stroke-width="1.4"/>'
        for a, b in ORION_LINES)
    stars = []
    for name, (x, y, r) in pts.items():
        if name == "Betelgeuse":
            stars.append(flare(x, y, 4.6, color_cls="", halo_color="#F0A070").replace('<path class=""', '<path fill="#F0A070"'))
        elif name == "Rigel":
            stars.append(flare(x, y, 4.4, color_cls="", halo_color="#A8C4FF").replace('<path class=""', '<path fill="#C9DAFF"'))
        else:
            stars.append(f'<circle cx="{x}" cy="{y}" r="{r*2}" class="fa" opacity=".14"/><circle cx="{x}" cy="{y}" r="{r*.8}" class="fa"/>')
    bx, by, _ = pts["Betelgeuse"]
    rx, ry, _ = pts["Rigel"]
    figure = f"""<svg width="346" height="196" viewBox="0 0 346 196" role="img" aria-label="Tamamlanmış Avcı takımyıldızı çizimi" style="align-self:center;overflow:visible">
  {lines}{''.join(stars)}
  <text x="{bx-80}" y="{by+5}" fill="#F0A070" font-size="13" font-style="italic" font-family="Newsreader, serif">Betelgeuse</text>
  <text x="{rx+16}" y="{ry+16}" fill="#C9DAFF" font-size="13" font-style="italic" font-family="Newsreader, serif">Rigel</text>
  <text x="{pts['Alnilam'][0]-20}" y="{pts['Alnilam'][1]+26}" fill="#A7ADC6" font-size="12" font-style="italic" font-family="Newsreader, serif">Kemer</text>
</svg>"""
    facts = ["Ortadaki üç yıldız “Avcı'nın Kemeri”. Gökyüzünde en kolay bulunan dizilimlerden biri.",
             "Betelgeuse turuncu-kırmızı bir süperdev. Rigel ise mavi-beyaz ve takımyıldızın en parlak yıldızı.",
             "Türkiye'den kış akşamları güney gökyüzünde çıplak gözle görülür."]
    f_html = "".join(f'<p style="margin:0;font-size:13.5px;line-height:1.45;color:#CFCBC0">{t}</p>' for t in facts)
    prizes = [(spark(18), "+200", "Işık", "var(--acc-ink)"),
              (icon("snow", 18, "#A8C4FF"), "Kış gecesi", "Ses paketi", "#A8C4FF"),
              (icon("sun", 18, "#C9B8FF"), "Avcı", "Rozet", "#C9B8FF")]
    p_html = "".join(
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:6px;text-align:center"><span style="width:44px;height:44px;border-radius:50%;background:var(--plate);display:flex;align-items:center;justify-content:center">{ic}</span>'
        f'<span style="font-size:14px;font-weight:600;color:{c}">{v}</span><span class="small" style="margin-top:-4px">{l}</span></div>'
        for ic, v, l, c in prizes)
    body = f"""
{starfield(4, n=130, grid=True, gy=1000)}
<div class="layer" style="padding:50px 22px 22px;gap:12px">
  <header style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:0">
    <p class="meta acc row" style="gap:6px;font-weight:600">{spark(12)}Takımyıldız tamamlandı</p>
    <h1 class="serif" style="margin:2px 0 0;font-size:64px;line-height:1;letter-spacing:-.03em">Avcı</h1>
    <p class="meta"><span class="serif it" style="font-size:16px;color:var(--paper)">Orion</span>, 7 yıldız, 23 oturumda</p>
  </header>
  {figure}
  <section aria-labelledby="bilgi" style="display:flex;flex-direction:column;gap:8px;padding-left:14px;border-left:1px solid color-mix(in srgb,var(--accent) 50%,transparent)">
    <h2 id="bilgi" class="h2">Bunları biliyor muydun?</h2>
    {f_html}
  </section>
  <section aria-labelledby="odul" style="display:flex;flex-direction:column;gap:10px">
    <h2 id="odul" class="meta" style="font-weight:500">Tamamlama ödülleri</h2>
    <div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px">{p_html}</div>
  </section>
  <div style="margin-top:auto;display:flex;flex-direction:column;gap:8px">
    <button class="btn btn-acc">{icon('compass', 19, '#1C1404', sw=2)}Gerçek gökyüzünde bul</button>
    <a href="Sky.dc.html" class="btn btn-ghost">Sıradaki takımyıldız: <span class="serif it" style="font-size:17px">Kuğu</span></a>
  </div>
</div>"""
    return page("Takımyıldız tamamlandı", root(body))


# ---------------------------------------------------------------- 4 · Gökyüzüm
def sky_chart():
    # Büyük Ayı (complete), Avcı 6/7, Kassiopeia 2/5 placed on one chart
    big = [(26, 74), (44, 54), (66, 50), (88, 62), (128, 46), (132, 86), (92, 94)]
    orion = [(258, 50), (240, 112), (218, 116), (196, 120), (176, 188), (276, 182)]
    orion_miss = (164, 42)
    cas_lit = [(44, 222), (72, 250)]
    cas_miss = [(100, 226), (130, 252), (160, 224)]
    g = ['<svg width="390" height="300" viewBox="0 0 390 300" aria-hidden="true" style="position:absolute;inset:0;overflow:visible">']
    g.append('<g fill="none" stroke="#ECE6D6" stroke-opacity=".07"><circle cx="195" cy="640" r="420"/><circle cx="195" cy="640" r="520"/><circle cx="195" cy="640" r="620"/>'
             '<line x1="195" y1="0" x2="195" y2="300"/><line x1="60" y1="0" x2="120" y2="300"/><line x1="330" y1="0" x2="270" y2="300"/></g>')
    pl = " ".join(f"{x},{y}" for x, y in big[:4]) + f" {big[4][0]},{big[4][1]} {big[5][0]},{big[5][1]} {big[6][0]},{big[6][1]} {big[3][0]},{big[3][1]}"
    g.append(f'<g class="sa" stroke-opacity=".55" stroke-width="1.2" fill="none"><polyline points="{pl}"/>'
             f'<line x1="258" y1="50" x2="240" y2="112"/><line x1="196" y1="120" x2="218" y2="116"/><line x1="218" y1="116" x2="240" y2="112"/>'
             f'<line x1="196" y1="120" x2="176" y2="188"/><line x1="240" y1="112" x2="276" y2="182"/><line x1="44" y1="222" x2="72" y2="250"/></g>')
    g.append(f'<g stroke="#ECE6D6" stroke-opacity=".25" stroke-dasharray="2 5" fill="none"><line x1="{orion_miss[0]}" y1="{orion_miss[1]}" x2="196" y2="120"/>'
             f'<line x1="{orion_miss[0]}" y1="{orion_miss[1]}" x2="258" y2="50"/><polyline points="72,250 100,226 130,252 160,224"/></g>')
    for x, y in big + orion + cas_lit:
        g.append(f'<circle cx="{x}" cy="{y}" r="7" class="fa" opacity=".12"/><circle cx="{x}" cy="{y}" r="3" class="fa"/>')
    for x, y in [orion_miss] + cas_miss:
        g.append(f'<circle cx="{x}" cy="{y}" r="4.5" fill="none" stroke="#ECE6D6" stroke-opacity=".35" stroke-dasharray="2 2"/>')
    g.append('<g font-family="Newsreader, serif" font-style="italic" font-size="13" fill="#ECE6D6">'
             '<text x="26" y="124">Büyük Ayı</text><text x="236" y="212">Avcı</text><text x="62" y="282">Kassiopeia</text></g>'
             '<g font-family="Hanken Grotesk, sans-serif" font-size="11" fill="#A7ADC6"><text x="89" y="124">tamam</text>'
             '<text x="266" y="212">6/7</text><text x="129" y="282">2/5</text></g>')
    g.append('</svg>')
    return "".join(g)


def sky_screen():
    badges = [("sun", "İlk ışık", True), ("timer", "90 dk maraton", True), ("lock", "7 gün seri", False), ("lock", "Gece kuşu", False)]
    b_html = "".join(
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:7px;text-align:center">'
        + (f'<span style="width:56px;height:56px;border-radius:50%;background:radial-gradient(circle at 35% 30%,rgba(242,196,109,.32),rgba(242,196,109,.08));box-shadow:inset 0 0 0 1px rgba(242,196,109,.45);display:flex;align-items:center;justify-content:center">{icon(ic, 24, "var(--acc-ink)", sw=1.8)}</span>'
           if on else f'<span style="width:56px;height:56px;border-radius:50%;border:1px dashed rgba(236,230,214,.22);display:flex;align-items:center;justify-content:center">{icon(ic, 20, "#6E7597", sw=2)}</span>')
        + f'<span style="font-size:12px;color:{"var(--paper)" if on else "var(--paper-3)"}">{l}</span></div>'
        for ic, l, on in badges)
    stats = [("9 sa 40 dk", "bu hafta"), ("12", "yıldız"), ("6 gün", "seri")]
    s_html = '<span style="background:var(--hair)"></span>'.join(
        f'<div><p class="serif num" style="margin:0;font-size:23px;line-height:1.1;white-space:nowrap">{v}</p><p class="small" style="margin:2px 0 0">{l}</p></div>' for v, l in stats)
    body = f"""
{starfield(5, n=60, bottom=380, grid=False)}
<div class="layer" style="padding:58px 0 96px;gap:16px">
  <header class="between" style="align-items:center;padding:0 22px">
    <h1 class="h1">Gökyüzüm</h1>
    <div class="seg" role="tablist" aria-label="Dönem" style="grid-template-columns:repeat(3,auto)">
      <button role="tab" aria-selected="false" style="padding:0 12px">Gün</button><button role="tab" aria-selected="true" style="padding:0 12px">Hafta</button><button role="tab" aria-selected="false" style="padding:0 12px">Tümü</button>
    </div>
  </header>

  <figure style="margin:0;position:relative;height:300px">
    {sky_chart()}
    <figcaption class="row small" style="position:absolute;right:22px;top:4px;gap:6px"><span style="width:9px;height:9px;border-radius:50%;border:1px dashed rgba(236,230,214,.5)"></span>Kesikli: henüz yanmadı</figcaption>
  </figure>

  <div style="display:grid;grid-template-columns:auto 1px auto 1px auto;justify-content:space-between;gap:0 10px;padding:0 22px">{s_html}</div>

  <div style="display:flex;flex-direction:column;padding:0 22px" class="list">
    <a href="Map.dc.html" class="between" style="align-items:center;min-height:56px">
      <span style="font-size:15px;font-weight:600">Takımyıldız koleksiyonu</span>
      <span class="row acc" style="font-size:14px;gap:4px">1 / 16 tamam{icon('chev', 16, 'currentColor', sw=2)}</span>
    </a>
    <div class="row" style="min-height:62px">
      {icon('cloud', 26, '#A8C4FF')}
      <div style="flex:1"><h2 id="bulut" class="h2">2 seri koruyucu bulut</h2><p class="small" style="margin:2px 0 0">Odaklanamadığın bir günü otomatik kapatır</p></div>
    </div>
  </div>

  <section aria-labelledby="roz" style="display:flex;flex-direction:column;gap:12px;padding:0 22px">
    <h2 id="roz" class="h2">Rozetler</h2>
    <div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px">{b_html}</div>
  </section>
</div>
{tabbar('Sky.dc.html')}"""
    return page("Gökyüzüm", root(body))


# ---------------------------------------------------------------- 5 · Ödüller ve Işık mağazası
def mini_sky(seed, bg, tint="#ece6d6", h=64):
    rnd = random.Random(seed)
    dots = "".join(f'<circle cx="{rnd.uniform(4,156):.0f}" cy="{rnd.uniform(4,h-10):.0f}" r="{rnd.choice([.6,.8,1,1.2])}" opacity="{rnd.uniform(.4,.95):.2f}"/>' for _ in range(22))
    return (f'<svg width="100%" height="{h}" viewBox="0 0 160 {h}" preserveAspectRatio="xMidYMid slice" aria-hidden="true" style="display:block;width:100%;border-radius:14px;background:{bg}">'
            f'<g fill="{tint}">{dots}</g></svg>')


def rewards_screen():
    boosts = [("scope", "Teleskop", "Sonraki yıldızı sen seç", "400", "var(--acc-ink)", "rgba(242,196,109,.12)"),
              ("shoot", "Kayan yıldız", "Sonraki oturumda Işık ×2", "150", "var(--acc-ink)", "rgba(242,196,109,.12)"),
              ("cloud", "Seri koruyucu bulut", "En fazla 3 tane taşıyabilirsin", "250", "#A8C4FF", "rgba(168,196,255,.12)"),
              ("sun", "Parlak yıldız bileti", "Bir parlak yıldızı 45 dk'da düşür", "500", "#F0A070", "rgba(240,160,112,.12)")]
    b_html = "".join(
        f'<div class="row" style="min-height:72px"><span style="flex:none;width:46px;height:46px;border-radius:50%;background:{bg};display:flex;align-items:center;justify-content:center">{icon(ic, 22, c)}</span>'
        f'<div style="flex:1;min-width:0"><p style="margin:0;font-size:15px;font-weight:600">{t}</p><p class="small" style="margin:2px 0 0">{s}</p></div>'
        f'<button class="price num">{spark(11)}{p}</button></div>' for ic, t, s, p, c, bg in boosts)
    looks = [(mini_sky(11, "linear-gradient(180deg,#0B1A2A,#1E5A5A 85%,#5FD3A8)"), "Kutup ışığı göğü", "600"),
             (mini_sky(12, "linear-gradient(180deg,#1A1530,#6A3A3A 80%,#E59A6A)"), "Alacakaranlık göğü", "400"),
             ('<div aria-hidden="true" style="width:100%;height:64px;border-radius:14px;background:var(--plate);display:flex;align-items:center;justify-content:center">'
              '<svg width="40" height="40" viewBox="0 0 40 40" fill="none" stroke="#ECE6D6" stroke-width="1.3"><circle cx="20" cy="20" r="16" stroke-opacity=".5"/>'
              + "".join(f'<line x1="{20+13*math.cos(math.radians(a)):.1f}" y1="{20+13*math.sin(math.radians(a)):.1f}" x2="{20+16*math.cos(math.radians(a)):.1f}" y2="{20+16*math.sin(math.radians(a)):.1f}" stroke-opacity=".6"/>' for a in range(0, 360, 30))
              + '<path d="M20 9v11l6 4" stroke-linecap="round"/></svg></div>', "Analog sayaç", "200"),
             ('<div aria-hidden="true" style="width:100%;height:64px;border-radius:14px;background:var(--plate);display:flex;align-items:center;justify-content:center">'
              f'<span style="width:40px;height:40px;border-radius:11px;background:linear-gradient(160deg,#141B3E,#090D22);box-shadow:inset 0 0 0 1px rgba(242,196,109,.55);display:flex;align-items:center;justify-content:center">{spark(18)}</span></div>', "Uygulama ikonu", "150")]
    l_html = "".join(
        f'<div style="display:flex;flex-direction:column;gap:8px;align-items:flex-start">{prev}<p style="margin:0;font-size:14px;font-weight:600">{t}</p>'
        f'<button class="price num" style="height:32px;padding:0 11px;font-size:13px">{spark(10)}{p}</button></div>' for prev, t, p in looks)
    packs = [("Kütüphane", '<button class="price num" style="height:32px;padding:0 11px;font-size:13px">' + spark(10) + '300</button>', "var(--plate)", "rgba(236,230,214,.0)"),
             ("Kahvehane", '<button class="price num" style="height:32px;padding:0 11px;font-size:13px">' + spark(10) + '300</button>', "var(--plate)", "rgba(236,230,214,.0)"),
             ("Kış gecesi", '<span style="font-size:12px;color:#A8C4FF;min-height:32px;display:flex;align-items:center">Avcı ile açıldı</span>', "rgba(168,196,255,.09)", "rgba(168,196,255,.3)")]
    p_html = "".join(
        f'<div style="padding:12px;border-radius:18px;background:{bg};box-shadow:inset 0 0 0 1px {bd};display:flex;flex-direction:column;gap:10px;align-items:flex-start">'
        f'<p style="margin:0;font-size:14px;font-weight:600">{t}</p>{act}</div>' for t, act, bg, bd in packs)
    promises = [("Yeni bir kitap al", "9 / 10 sa", 90, "var(--accent)", "Hedef: toplam 10 saat odak"),
                ("Hafta sonu kahvaltıya çık", "Kuğu 3 / 9", 33, "#A8C4FF", "Hedef: Kuğu takımyıldızını tamamla")]
    pr_html = "".join(
        f'<div style="display:flex;flex-direction:column;gap:8px;padding:14px 0"><div class="between"><span style="font-size:16px;font-weight:600">{t}</span><span class="num" style="font-size:13px;color:var(--paper-2)">{v}</span></div>'
        f'<div class="bar"><i style="width:{w}%;background:{c}"></i></div><p class="small" style="margin:0">{h}</p></div>' for t, v, w, c, h in promises)
    tabs = ["Tümü", "Güçlendirici", "Sesler", "Görünüm", "Zenit"]
    t_html = "".join(
        f'<button role="tab" aria-selected="{"true" if i == 0 else "false"}" style="flex:none;min-height:38px;padding:0 15px;border-radius:999px;font-size:14px;font-weight:{600 if i == 0 else 500};'
        + ("background:var(--paper);color:#0B1026" if i == 0 else "box-shadow:inset 0 0 0 1px var(--hair);color:var(--paper-2)") + f'">{t}</button>'
        for i, t in enumerate(tabs))
    body = f"""
{starfield(6, h=1630, n=60, bottom=260, grid=False)}
<div class="layer" style="padding:58px 22px 100px;gap:22px">
  <header class="between" style="align-items:center">
    <h1 class="h1">Ödüller</h1>
    <p class="row num" style="margin:0;gap:7px;height:38px;padding:0 14px;border-radius:999px;background:rgba(242,196,109,.12);color:var(--accent);font-size:16px;font-weight:600">{spark(14)}1.440 Işık</p>
  </header>

  <section aria-labelledby="soz" style="display:flex;flex-direction:column">
    <div class="between" style="align-items:center"><h2 id="soz" class="serif" style="margin:0;font-size:24px">Kendine sözler</h2>
      <a href="#" class="acc" style="min-height:44px;display:flex;align-items:center;font-size:14px;font-weight:600">+ Yeni söz</a></div>
    <div class="list">{pr_html}</div>
  </section>

  <div role="tablist" aria-label="Mağaza kategorileri" style="display:flex;gap:6px;margin:0 -22px;padding:0 22px;overflow:hidden">{t_html}</div>

  <section aria-labelledby="guc" style="display:flex;flex-direction:column;gap:2px;margin-top:-6px">
    <h2 id="guc" class="serif" style="margin:0 0 4px;font-size:24px">Güçlendiriciler</h2>
    <div class="list">{b_html}</div>
  </section>

  <section aria-labelledby="ses" style="display:flex;flex-direction:column;gap:12px">
    <h2 id="ses" class="serif" style="margin:0;font-size:24px">Ses paketleri</h2>
    <div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px">{p_html}</div>
  </section>

  <section aria-labelledby="gor" style="display:flex;flex-direction:column;gap:12px">
    <h2 id="gor" class="serif" style="margin:0;font-size:24px">Görünüm</h2>
    <div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px 14px">{l_html}</div>
  </section>

  <section aria-labelledby="zenit" style="display:flex;flex-direction:column;gap:14px;padding:18px;border-radius:24px;background:linear-gradient(150deg,rgba(242,196,109,.16),rgba(242,196,109,.03) 70%);box-shadow:inset 0 0 0 1px rgba(242,196,109,.32)">
    <div class="row" style="align-items:flex-start;gap:14px">
      <span style="flex:none;width:46px;height:46px;border-radius:50%;background:rgba(242,196,109,.14);display:flex;align-items:center;justify-content:center">{icon('zenith', 24, 'var(--acc-ink)')}</span>
      <div style="flex:1;min-width:0"><h2 id="zenit" class="serif" style="margin:0;font-size:28px;line-height:1">Zenit</h2><p class="small" style="margin:5px 0 0;color:var(--paper-2)">Gökyüzünün en tepesi. Odak, yıldızlar ve Işık her zaman ücretsiz.</p></div>
    </div>
    <ul style="margin:0;padding:0;list-style:none;display:flex;flex-direction:column;gap:8px"><li class="row" style="gap:10px;font-size:14px">{spark(11)}Tüm ses paketleri ve gök temaları</li><li class="row" style="gap:10px;font-size:14px">{spark(11)}Ayrıntılı haftalık ve aylık istatistikler</li><li class="row" style="gap:10px;font-size:14px">{spark(11)}Sınırsız kendine söz</li></ul>
    <button class="btn btn-acc" style="height:50px">Zenit'e geç · [FİYAT] / ay</button>
  </section>
</div>
{tabbar('Rewards.dc.html')}"""
    return page("Ödüller ve Işık mağazası", root(body, style="height:1630px"), height=1630)


# ---------------------------------------------------------------- 6 · Koleksiyon haritası
def map_screen():
    layers = [
        dict(n=1, title="Başlangıç göğü", right='<span class="num acc" style="font-size:14px;font-weight:600">1 / 16</span>',
             bar=('var(--accent)', 12), text="16 tanınmış takımyıldız. Şu an buradasın.", href=None, color="var(--accent)", state="here"),
        dict(n=2, title="Tüm gökyüzü", right='<span class="row small" style="gap:4px">' + icon('lock', 13, '#6E7597', sw=2) + 'Kilitli</span>',
             bar=None, text="Kalan 72 takımyıldız: Kuzey göğü, sonra Güney seferi. Başlangıç göğü bitince açılır.", href=None, color="#6E7597", state="locked"),
        dict(n=3, title="Derin gök nesneleri", right='<span class="num" style="font-size:14px;font-weight:600;color:#E6A6C7">0 / 110</span>',
             bar=None, text="Paralel ilerler. Nebulalar, galaksiler, kümeler. İlk nesne: Avcı Bulutsusu, Avcı tamamlandıktan sonra 90 dk'lık bir oturumla.",
             href="DeepSky.dc.html", color="#E6A6C7", state="parallel"),
        dict(n=4, title="Gezegenler ve Ay", right='<span class="num" style="font-size:14px;font-weight:600;color:#A8C4FF">2 / 8</span>',
             bar=("#A8C4FF", 92), text="Paralel ilerler. Sıradaki: Venüs, 25 saat (sen 23 saattesin).", href="DeepSky.dc.html", color="#A8C4FF", state="parallel"),
        dict(n=5, title="Işık yolculuğu", right='<span class="row small" style="gap:4px">' + icon('lock', 13, '#6E7597', sw=2) + 'Kilitli</span>',
             bar=None, text="88 takımyıldız bitince gerçek yıldız sistemlerine yolculuk başlar. Her odak saati 1 ışık yılı, rota hiç bitmez.",
             href="Prestige.dc.html", color="#6E7597", state="locked"),
    ]
    items = []
    for i, L in enumerate(layers):
        if L["state"] == "here":
            node = f'<span style="position:relative;z-index:1;width:30px;height:30px;border-radius:50%;background:var(--accent);color:#1C1404;font:600 14px Hanken Grotesk;display:flex;align-items:center;justify-content:center;box-shadow:0 0 0 6px rgba(242,196,109,.14),0 0 22px rgba(242,196,109,.5)">{L["n"]}</span>'
        elif L["state"] == "parallel":
            node = f'<span style="position:relative;z-index:1;width:30px;height:30px;border-radius:50%;background:#0E1430;box-shadow:inset 0 0 0 1.5px {L["color"]};color:{L["color"]};font:600 14px Hanken Grotesk;display:flex;align-items:center;justify-content:center">{L["n"]}</span>'
        else:
            node = f'<span style="position:relative;z-index:1;width:30px;height:30px;border-radius:50%;background:#0E1430;box-shadow:inset 0 0 0 1px rgba(236,230,214,.2);color:var(--paper-3);font:600 14px Hanken Grotesk;display:flex;align-items:center;justify-content:center">{L["n"]}</span>'
        bar = f'<div class="bar"><i style="width:{L["bar"][1]}%;background:{L["bar"][0]}"></i></div>' if L["bar"] else ""
        tag = "a" if L["href"] else "div"
        href = f' href="{L["href"]}"' if L["href"] else ""
        hl = "background:rgba(242,196,109,.07);box-shadow:inset 0 0 0 1px rgba(242,196,109,.35);" if L["state"] == "here" else ""
        tcol = "var(--paper)" if L["state"] != "locked" else "#C3C6D4"
        items.append(
            f'<li style="display:flex;gap:14px;align-items:flex-start">{node}'
            f'<{tag}{href} style="flex:1;min-width:0;display:flex;flex-direction:column;gap:6px;padding:12px 14px;margin-top:-8px;border-radius:18px;{hl}">'
            f'<span class="between"><span style="font-size:16px;font-weight:600;color:{tcol}">{L["title"]}</span>{L["right"]}</span>{bar}'
            f'<span style="font-size:12.5px;line-height:1.45;color:var(--paper-2)">{L["text"]}</span></{tag}></li>')
    body = f"""
{starfield(7, n=70, grid=False)}
<div class="layer" style="padding:54px 22px 22px;gap:18px">
  <header class="row" style="gap:12px">
    <a href="Sky.dc.html" aria-label="Geri" class="iconbtn">{icon('back', 18, '#A7ADC6', sw=2)}</a>
    <div style="flex:1"><h1 class="h1" style="font-size:26px;white-space:nowrap">Koleksiyon haritası</h1><p class="small serif it" style="margin:2px 0 0;font-size:14px;color:var(--paper-2)">Gökyüzün hiç bitmez</p></div>
    <span class="row acc" style="flex:none;gap:5px;font-size:13px;font-weight:600;height:30px;padding:0 11px;border-radius:999px;background:rgba(242,196,109,.12)">{spark(10)}23 sa</span>
  </header>

  <a href="Event.dc.html" class="row" style="position:relative;overflow:hidden;padding:12px 14px;border-radius:20px;background:linear-gradient(110deg,#2A2150,#151236);box-shadow:inset 0 0 0 1px rgba(201,184,255,.25)">
    <svg aria-hidden="true" width="140" height="70" viewBox="0 0 140 70" style="position:absolute;right:0;top:0;opacity:.6"><g stroke="#C9B8FF" stroke-linecap="round"><line x1="130" y1="6" x2="80" y2="36" stroke-opacity=".8"/><line x1="140" y1="30" x2="100" y2="54" stroke-opacity=".5"/><line x1="96" y1="0" x2="66" y2="18" stroke-opacity=".4"/></g></svg>
    {icon('meteor', 26, '#C9B8FF')}
    <span style="flex:1;position:relative"><span style="display:block;font-size:15px;font-weight:600">Orionid meteor yağmuru</span><span style="display:block;font-size:12px;color:#CFC6EE">Etkinlik sürüyor, zirve 21 Ekim civarı</span></span>
    {icon('chev', 18, '#C9B8FF', sw=2)}
  </a>

  <ol style="position:relative;margin:8px 0 0;padding:0;list-style:none;display:flex;flex-direction:column;gap:14px">
    <span aria-hidden="true" style="position:absolute;left:14.5px;top:14px;bottom:30px;width:1px;background:linear-gradient(var(--accent),rgba(236,230,214,.14) 18%,rgba(236,230,214,.14))"></span>
    {''.join(items)}
  </ol>

  <p class="small" style="margin:auto 0 0;line-height:1.45;text-align:center;color:var(--paper-2)">Işık, sözler ve seriler her katmanda çalışmaya devam eder.</p>
</div>"""
    return page("Koleksiyon haritası", root(body))


# ---------------------------------------------------------------- 6a · Derin gök + gezegenler
def nebula():
    rnd = random.Random(42)
    wisps = "".join(
        f'<ellipse cx="{rnd.uniform(110,240):.0f}" cy="{rnd.uniform(60,140):.0f}" rx="{rnd.uniform(30,90):.0f}" ry="{rnd.uniform(14,40):.0f}" '
        f'transform="rotate({rnd.uniform(-40,40):.0f} 175 100)" fill="url(#{rnd.choice(["n1","n2","n3"])})" opacity="{rnd.uniform(.35,.8):.2f}"/>' for _ in range(9))
    return f"""<svg width="390" height="180" viewBox="0 25 390 180" role="img" aria-label="Avcı Bulutsusu çizimi" style="display:block;margin:0 -22px;overflow:visible">
  <defs>
    <radialGradient id="n1"><stop offset="0" stop-color="#E6A6C7" stop-opacity=".9"/><stop offset="1" stop-color="#E6A6C7" stop-opacity="0"/></radialGradient>
    <radialGradient id="n2"><stop offset="0" stop-color="#7FB6E0" stop-opacity=".8"/><stop offset="1" stop-color="#7FB6E0" stop-opacity="0"/></radialGradient>
    <radialGradient id="n3"><stop offset="0" stop-color="#F2C9A0" stop-opacity=".7"/><stop offset="1" stop-color="#F2C9A0" stop-opacity="0"/></radialGradient>
    <filter id="soft"><feGaussianBlur stdDeviation="6"/></filter>
  </defs>
  <g filter="url(#soft)">{wisps}
    <ellipse cx="195" cy="110" rx="150" ry="90" fill="url(#n1)" opacity=".55"/>
    <ellipse cx="225" cy="96" rx="90" ry="60" fill="url(#n2)" opacity=".6"/>
    <ellipse cx="200" cy="112" rx="40" ry="28" fill="#FFF3E0" opacity=".35"/>
  </g>
  {flare(196, 106, 2.6, color_cls='', halo_color='#FFFFFF').replace('<path class=""', '<path fill="#FFFFFF"')}
  <g fill="#FFFFFF"><circle cx="206" cy="112" r="2"/><circle cx="190" cy="116" r="1.6"/><circle cx="203" cy="100" r="1.5"/></g>
</svg>"""


def deepsky_screen():
    planets = [("Ay", "5 sa", 18, "radial-gradient(circle at 35% 35%,#F2EFE8,#9C988F)", "done"),
               ("Merkür", "10 sa", 14, "radial-gradient(circle at 35% 35%,#C9C3BA,#6E6A64)", "done"),
               ("Venüs", "25 sa", 20, "", "next"),
               ("Mars", "50 sa", 16, "", ""), ("Jüpiter", "100 sa", 26, "", ""), ("Satürn", "250 sa", 22, "", ""),
               ("Uranüs", "500 sa", 18, "", ""), ("Neptün", "1000 sa", 18, "", "")]
    p_html = []
    for name, hrs, d, grad, st in planets:
        if st == "done":
            disc = f'<span aria-hidden="true" style="width:{d}px;height:{d}px;border-radius:50%;background:{grad}"></span>'
            lc, hc = "var(--paper)", "var(--paper-3)"
        elif st == "next":
            disc = f'<span aria-hidden="true" style="width:{d}px;height:{d}px;border-radius:50%;background:conic-gradient(var(--accent) 0 92%,rgba(236,230,214,.12) 0);padding:2px;display:block"><span style="display:block;width:100%;height:100%;border-radius:50%;background:radial-gradient(circle at 35% 35%,#F6E2B0,#B48A4A)"></span></span>'
            lc, hc = "var(--paper)", "var(--acc-ink)"
        else:
            disc = f'<span aria-hidden="true" style="width:{d}px;height:{d}px;border-radius:50%;border:1px dashed rgba(236,230,214,.25)"></span>'
            lc, hc = "var(--paper-3)", "var(--paper-3)"
        w = "font-weight:600;" if st == "next" else ""
        p_html.append(f'<div style="display:flex;flex-direction:column;align-items:center;gap:5px"><span style="height:28px;display:flex;align-items:center">{disc}</span>'
                      f'<span style="font-size:10.5px;color:{lc};{w}">{name}</span><span class="num" style="font-size:10px;color:{hc};margin-top:-3px">{hrs}</span></div>')
    body = f"""
{starfield(8, n=110, grid=False)}
<div class="layer" style="padding:52px 22px 24px;gap:12px">
  <header style="display:flex;flex-direction:column;align-items:center;text-align:center">
    <p class="meta" style="color:#E6A6C7;font-weight:600">Derin gök nesnesi keşfettin</p>
    <h1 class="serif" style="margin:2px 0 0;font-size:44px;line-height:1.05;letter-spacing:-.025em">Avcı Bulutsusu</h1>
    <p class="meta num">M42, 110 nesnenin ilki</p>
  </header>
  <div class="astro">{nebula()}</div>
  <section aria-labelledby="nedir" style="display:flex;flex-direction:column;gap:8px;margin-top:-6px">
    <h2 id="nedir" class="h2">Bu ne?</h2>
    <p style="margin:0;font-size:14px;line-height:1.5;color:#CFCBC0">Yeni yıldızların doğduğu dev bir gaz ve toz bulutu. Avcı'nın Kemeri'nin hemen altında, “kılıç” bölgesinde.</p>
    <p style="margin:0;font-size:14px;line-height:1.5;color:#CFCBC0">Karanlık bir gecede çıplak gözle bulanık bir leke gibi görünür. Dürbünle çok daha belirgindir.</p>
    <p class="small" style="margin:0">Açılma koşulu: Avcı tamamlandıktan sonra 90 dk'lık oturum</p>
  </section>
  <div class="row" style="gap:18px;padding:4px 0">
    <span class="row" style="gap:8px"><span class="serif num acc row" style="font-size:24px;gap:5px">{spark(13)}+300</span><span class="small">Işık</span></span>
    <span style="width:1px;height:28px;background:var(--hair)"></span>
    <span class="row" style="gap:8px"><span class="serif it" style="font-size:20px;color:#F0C2DC">Bulutsu göğü</span><span class="small">gök teması</span></span>
  </div>
  <section aria-labelledby="gez" style="display:flex;flex-direction:column;gap:10px;padding:14px 12px;border-radius:20px;background:var(--plate)">
    <div class="between" style="padding:0 4px"><h2 id="gez" class="h2">Gezegenler ve Ay</h2><span class="small">toplam odak saatiyle</span></div>
    <div style="display:grid;grid-template-columns:repeat(8,minmax(0,1fr));gap:2px;text-align:center">{''.join(p_html)}</div>
  </section>
  <div style="margin-top:auto;display:flex;flex-direction:column;gap:8px">
    <button class="btn btn-acc">Temayı uygula</button>
    <a href="Map.dc.html" class="btn btn-ghost">Koleksiyon haritası</a>
  </div>
</div>"""
    return page("Derin gök nesnesi", root(body))


# ---------------------------------------------------------------- 6b · Meteor yağmuru
def meteors():
    rnd = random.Random(9)
    out = ['<svg width="390" height="250" viewBox="0 0 390 250" aria-hidden="true" class="sky" style="height:250px"><defs>'
           '<linearGradient id="trail" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C9B8FF" stop-opacity="0"/><stop offset="1" stop-color="#F4EEFF"/></linearGradient></defs>']
    for x, y, L, w in [(370, 10, 150, 2.2), (300, -10, 110, 1.6), (395, 80, 120, 1.6), (210, 20, 80, 1.2), (340, 140, 60, 1)]:
        dx, dy = -L * 0.86, L * 0.5
        out.append(f'<line x1="{x}" y1="{y}" x2="{x+dx:.0f}" y2="{y+dy:.0f}" stroke="url(#trail)" stroke-width="{w}" stroke-linecap="round"/>'
                   f'<circle cx="{x+dx:.0f}" cy="{y+dy:.0f}" r="{w*1.3}" fill="#FFF8E6"/>')
    # radiant: Avcı direction, lower right
    out.append('<g fill="#C9B8FF" opacity=".55">' + "".join(
        f'<circle cx="{rnd.uniform(0,390):.0f}" cy="{rnd.uniform(0,240):.0f}" r="{rnd.choice([.6,.8,1])}"/>' for _ in range(50)) + '</g></svg>')
    return "".join(out)


def event_screen():
    upcoming = [("Leonidler", "Kasım ortası"), ("Geminidler (İkizler)", "Aralık ortası"), ("Perseidler", "Ağustos ortası")]
    u_html = "".join(f'<div class="between" style="min-height:40px;align-items:center;font-size:15px"><span>{a}</span><span class="small" style="font-size:13px;color:var(--paper-2)">{b}</span></div>' for a, b in upcoming)
    body = f"""
<div aria-hidden="true" style="position:absolute;inset:0;background:linear-gradient(180deg,#1E1744 0%,#0E0B24 40%,#0A0A1C 100%)"></div>
{meteors()}
<div class="layer" style="padding:54px 22px 24px;gap:16px">
  <header class="row" style="gap:12px">
    <a href="Map.dc.html" aria-label="Geri" class="iconbtn" style="background:rgba(201,184,255,.12)">{icon('back', 18, '#D8CCFF', sw=2)}</a>
    <p class="meta" style="color:#D8CCFF;font-weight:600">Gökyüzü etkinliği</p>
  </header>
  <div style="margin-top:34px;display:flex;flex-direction:column;gap:6px">
    <h1 class="serif" style="margin:0;font-size:42px;line-height:1.02;letter-spacing:-.025em">Orionid<br>meteor yağmuru</h1>
    <p class="meta" style="color:#CFC6EE">Ekim başından Kasım başına, zirve 21–22 Ekim civarı</p>
  </div>
  <section aria-labelledby="kur" style="display:flex;flex-direction:column;gap:10px;padding:16px;border-radius:22px;background:rgba(201,184,255,.08);box-shadow:inset 0 0 0 1px rgba(201,184,255,.18)">
    <h2 id="kur" class="h2">Etkinlik boyunca</h2>
    <p style="margin:0;font-size:14px;line-height:1.45;color:#DCD6F0">Her oturumda %25 şansla kayan yıldız düşer: o oturumun Işığı ×2.</p>
    <p style="margin:0;font-size:14px;line-height:1.45;color:#DCD6F0">10 oturum tamamla, Orionid rozetini ve “Meteor izi” sayaç stilini kazan.</p>
    <div class="between" style="margin-top:4px;font-size:13px"><span style="color:#CFC6EE">İlerleme</span><span class="num" style="font-weight:600">4 / 10 oturum</span></div>
    <div style="display:grid;grid-template-columns:repeat(10,1fr);gap:4px" aria-hidden="true">{''.join(f'<span style="height:6px;border-radius:3px;background:{"#C9B8FF" if i < 4 else "rgba(201,184,255,.16)"}"></span>' for i in range(10))}</div>
  </section>
  <section aria-labelledby="gercek" style="display:flex;flex-direction:column;gap:8px">
    <h2 id="gercek" class="h2">Gerçekte de izle</h2>
    <p style="margin:0;font-size:14px;line-height:1.45;color:#CFCBC0">Meteorlar Avcı yönünden geliyor gibi görünür. En iyi zaman gece yarısından sonra, şehir ışıklarından uzakta.</p>
    <button class="row" style="align-self:flex-start;gap:8px;min-height:44px;padding:0 16px;border-radius:999px;box-shadow:inset 0 0 0 1px rgba(201,184,255,.35);color:#D8CCFF;font-size:14px;font-weight:600">{icon('bell', 16, '#D8CCFF', sw=1.8)}Zirve gecesi için hatırlat</button>
  </section>
  <section aria-labelledby="takvim" style="display:flex;flex-direction:column">
    <h2 id="takvim" class="meta" style="font-weight:500;margin-bottom:2px">Sıradaki etkinlikler</h2>
    <div class="list">{u_html}</div>
  </section>
  <a href="Main.dc.html" class="btn" style="margin-top:auto;background:#C9B8FF;color:#18123A;box-shadow:0 10px 30px -12px #C9B8FF">Odaklanmaya başla</a>
</div>"""
    return page("Meteor yağmuru", root(body, style="background:#0A0A1C"), bg="#0A0A1C")


# ---------------------------------------------------------------- 6c · Işık yolculuğu
STOPS = [("Alfa Centauri", 4.4, "Üçlü yıldız sisteminin hikâyesi, Proxima rozeti"),
         ("Sirius", 8.6, "Gecenin en parlak yıldızı, +300 Işık"),
         ("Vega", 25, "Lir'in kalbi, yeni bir ses paketi"),
         ("TRAPPIST-1", 41, "Yedi gezegenli sistem, “Kırmızı cüce” gök teması"),
         ("Ülker", 444, "Yedi Kız Kardeş kümesi, özel rozet")]
TRAVELED = 2.6


def fmt_ly(d):
    return f"{d:g}".replace(".", ",")


def route_chart():
    """Sun → stops as a voyage line across the sky. Spacing is schematic; the labels carry the real distances."""
    xs = [34 + i * (322 / len(STOPS)) for i in range(len(STOPS) + 1)]

    def y(x):
        return 112 - 62 * math.sin((x - 34) / 322 * math.pi * 0.7)

    def line(x_from, x_to, n=40):
        return " ".join(f"{'M' if i == 0 else 'L'}{x:.1f} {y(x):.1f}" for i, x in
                        ((i, x_from + (x_to - x_from) * i / n) for i in range(n + 1)))

    ship = xs[0] + (xs[1] - xs[0]) * TRAVELED / STOPS[0][1]
    stops = []
    for i, (name, d, _) in enumerate(STOPS):
        x = xs[i + 1]
        up = i % 2 == 0
        anchor = "end" if i == len(STOPS) - 1 else "middle"
        tx = x + 6 if anchor == "end" else x
        ny, dy = (y(x) - 14, y(x) - 30) if up else (y(x) + 24, y(x) + 38)
        stops.append(f'<circle cx="{x:.1f}" cy="{y(x):.1f}" r="4.5" style="fill:var(--night)" stroke="#ECE6D6" stroke-opacity=".7" stroke-width="1.2"/>'
                     f'<text x="{tx:.1f}" y="{ny:.1f}" text-anchor="{anchor}" font-family="Newsreader,serif" font-style="italic" font-size="14" fill="#ECE6D6">{name}</text>'
                     f'<text x="{tx:.1f}" y="{dy:.1f}" text-anchor="{anchor}" font-family="Hanken Grotesk,sans-serif" font-size="10.5" fill="#6E7597">{fmt_ly(d)} ı.y.</text>')
    sx = xs[0]
    return f"""<svg width="390" height="150" viewBox="0 0 390 150" role="img" aria-label="Güneş'ten Ülker'e uzanan yolculuk rotası" style="display:block;margin:0 -22px;overflow:visible">
  <path d="{line(sx, xs[-1] + 18)}" fill="none" stroke="#ECE6D6" stroke-opacity=".28" stroke-width="1.2" stroke-dasharray="2 5" stroke-linecap="round"/>
  <path d="{line(sx, ship, 12)}" fill="none" class="sa" stroke-width="2.2" stroke-linecap="round"/>
  {flare(round(sx, 1), round(y(sx), 1), 3.2, color_cls='', halo_color='#F0A070').replace('<path class=""', '<path fill="#F0A070"')}
  <text x="{sx:.1f}" y="{y(sx) + 26:.1f}" text-anchor="middle" font-family="Newsreader,serif" font-style="italic" font-size="14" fill="#ECE6D6">Güneş</text>
  {''.join(stops)}
  {flare(round(ship, 1), round(y(ship), 1), 2.4, cls='halo')}
</svg>"""


def prestige_screen():
    nxt_name, nxt_d, _ = STOPS[0]
    pct = TRAVELED / nxt_d * 100
    rows = "".join(
        f'<div class="between" style="min-height:48px;align-items:center;padding:4px 0"><div style="min-width:0">'
        f'<p class="serif it" style="margin:0;font-size:19px;line-height:1.15{";color:var(--acc-ink)" if i == 0 else ""}">{n}</p>'
        f'<p class="small" style="margin:1px 0 0">{r}</p></div><span class="num" style="flex:none;font-size:13px;color:var(--paper-2)">{fmt_ly(d)} ı.y.</span></div>'
        for i, (n, d, r) in enumerate(STOPS))
    body = f"""
{starfield(10, n=120, grid=False)}
<div class="layer" style="padding:50px 22px 22px;gap:10px">
  <header class="row" style="gap:12px">
    <a href="Map.dc.html" aria-label="Geri" class="iconbtn">{icon('back', 18, '#A7ADC6', sw=2)}</a>
    <div style="flex:1"><p class="meta num acc" style="font-weight:600">88 / 88 takımyıldız</p><h1 class="h1" style="font-size:32px;white-space:nowrap">Işık yolculuğu</h1></div>
  </header>
  <p style="margin:0;font-size:15px;line-height:1.45;color:var(--paper-body)">Gökyüzünü yaktın, şimdi oraya gitme zamanı. Her odak saatin seni <span class="serif it" style="font-size:17px">1 ışık yılı</span> ileri taşır.</p>
  {route_chart()}
  <section aria-labelledby="durak" style="display:flex;flex-direction:column;gap:8px;padding:14px 16px;border-radius:20px;background:rgba(242,196,109,.07);box-shadow:inset 0 0 0 1px rgba(242,196,109,.32)">
    <div class="between"><h2 id="durak" class="h2">Sıradaki durak: {nxt_name}</h2><span class="num acc" style="font-size:13px;font-weight:600">{fmt_ly(TRAVELED)} / {fmt_ly(nxt_d)} ı.y.</span></div>
    <div class="bar"><i style="width:{pct:.0f}%"></i></div>
    <p class="small" style="margin:0">Güneş'e en yakın yıldız sistemi. 2 saatlik odak kaldı.</p>
  </section>
  <section aria-labelledby="rota" style="display:flex;flex-direction:column">
    <h2 id="rota" class="meta" style="font-weight:500;margin-bottom:2px">Rota</h2>
    <div class="list">{rows}</div>
  </section>
  <p class="small" style="margin:auto 0 0;line-height:1.45;text-align:center;color:var(--paper-2)">Mesafeler gerçek, rota hiç bitmez. Koleksiyonun ve Işık bakiyen olduğu gibi kalır.</p>
  <a href="Main.dc.html" class="btn btn-acc">Yolculuğa devam et</a>
</div>"""
    return page("Işık yolculuğu", root(body))


# ---------------------------------------------------------------- 0 · Evrenim (giriş)
def planisphere():
    """The user's own sky as a planisphere: north celestial pole in the centre, hour ring on the rim."""
    cx, cy, R = 195, 186, 166
    out = [f'<svg width="390" height="372" viewBox="0 0 390 372" role="img" aria-label="Senin gökyüzün: Büyük Ayı tamam, Avcı 7 yıldızdan 6, Kassiopeia 5 yıldızdan 2, Ay ve Merkür açıldı" style="display:block;overflow:visible">']
    out.append('<defs><radialGradient id="disk"><stop offset="0" stop-color="#0E1430"/><stop offset="1" stop-color="#090D22"/></radialGradient>'
               f'<clipPath id="inner"><circle cx="{cx}" cy="{cy}" r="{R}"/></clipPath></defs>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{R + 20}" fill="none" stroke="#ECE6D6" stroke-opacity=".14"/>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="url(#disk)" stroke="#ECE6D6" stroke-opacity=".22"/>')
    # hour ring: 24 hours of right ascension, labelled every 2
    for h in range(24):
        a = math.radians(h * 15 - 90)
        r1, r2 = R + 2, R + (8 if h % 2 == 0 else 5)
        out.append(f'<line x1="{cx + r1*math.cos(a):.1f}" y1="{cy + r1*math.sin(a):.1f}" x2="{cx + r2*math.cos(a):.1f}" y2="{cy + r2*math.sin(a):.1f}" stroke="#ECE6D6" stroke-opacity=".4"/>')
        if h % 2 == 0:
            tx, ty = cx + (R + 14) * math.cos(a), cy + (R + 14) * math.sin(a) + 3.5
            out.append(f'<text x="{tx:.1f}" y="{ty:.1f}" text-anchor="middle" font-size="9.5" font-family="Hanken Grotesk, sans-serif" fill="#6E7597">{h}s</text>')
    out.append(f'<g clip-path="url(#inner)">')
    # declination circles and hour lines, like a printed chart
    out.append('<g fill="none" stroke="#ECE6D6" stroke-opacity=".07">' + "".join(f'<circle cx="{cx}" cy="{cy}" r="{r}"/>' for r in (42, 84, 126)) +
               "".join(f'<line x1="{cx}" y1="{cy}" x2="{cx + R*math.cos(math.radians(a)):.1f}" y2="{cy + R*math.sin(math.radians(a)):.1f}"/>' for a in range(0, 360, 30)) + '</g>')
    # catalogue stars not lit yet: faint
    rnd = random.Random(77)
    dots = []
    for _ in range(150):
        rr, aa = R * math.sqrt(rnd.random()), rnd.uniform(0, 2 * math.pi)
        dots.append(f'<circle cx="{cx + rr*math.cos(aa):.1f}" cy="{cy + rr*math.sin(aa):.1f}" r="{rnd.choice([.6, .8, 1, 1.2])}" opacity="{rnd.uniform(.18, .5):.2f}"/>')
    out.append('<g fill="#ECE6D6">' + "".join(dots) + '</g>')
    # ecliptic with the Moon and planets placed on it
    out.append(f'<ellipse cx="{cx + 10}" cy="{cy + 34}" rx="{R + 30}" ry="92" transform="rotate(-16 {cx} {cy})" fill="none" stroke="#A8C4FF" stroke-opacity=".35" stroke-dasharray="3 5"/>')
    out.append('</g>')

    def lit(pts, lines, missing=(), miss_lines=()):
        g = []
        for a, b in lines:
            g.append(f'<line x1="{pts[a][0]}" y1="{pts[a][1]}" x2="{pts[b][0]}" y2="{pts[b][1]}" class="sa" stroke-opacity=".6" stroke-width="1.2"/>')
        for a, b in miss_lines:
            g.append(f'<line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" stroke="#ECE6D6" stroke-opacity=".3" stroke-dasharray="2 4"/>')
        for x, y in pts:
            g.append(f'<circle cx="{x}" cy="{y}" r="6" class="fa" opacity=".14"/><circle cx="{x}" cy="{y}" r="2.6" class="fa"/>')
        for x, y in missing:
            g.append(f'<circle cx="{x}" cy="{y}" r="4" fill="none" stroke="#ECE6D6" stroke-opacity=".45" stroke-dasharray="2 2"/>')
        return "".join(g)

    # Büyük Ayı (complete), north-west of the pole
    ursa = [(86, 120), (104, 104), (124, 100), (144, 110), (180, 98), (184, 132), (148, 138)]
    out.append(lit(ursa, [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 3)]))
    # Kassiopeia 2/5 across the pole from the Bear
    cas = [(232, 128), (252, 148)]
    cas_m = [(270, 126), (290, 146), (306, 122)]
    out.append(lit(cas, [(0, 1)], cas_m, [((252, 148), (270, 126)), ((270, 126), (290, 146)), ((290, 146), (306, 122))]))
    # Avcı 6/7 down on the ecliptic side
    ori = [(258, 238), (236, 290), (220, 292), (204, 294), (190, 340), (262, 334)]
    bet = (184, 232)
    out.append(lit(ori, [(0, 1), (1, 2), (2, 3), (3, 4), (1, 5)], [], [(bet, (204, 294)), (bet, (258, 238))]))
    out.append(f'<circle cx="{bet[0]}" cy="{bet[1]}" r="7" fill="none" stroke="#F0A070" stroke-width="1.3" stroke-dasharray="2 3" class="beckon"/>')
    # pole star
    out.append(flare(cx, cy, 2.2, color_cls='', halo_color='#ECE6D6').replace('<path class=""', '<path fill="#ECE6D6"'))
    # Moon and Mercury unlocked; the rest wait on the ecliptic
    out.append('<circle cx="70" cy="226" r="9" fill="url(#moon)"/><defs><radialGradient id="moon" cx=".35" cy=".35"><stop offset="0" stop-color="#f2efe8"/><stop offset="1" stop-color="#9c988f"/></radialGradient></defs>')
    out.append('<circle cx="118" cy="262" r="5" fill="#b8b2a8"/>')
    for x, y in [(150, 282), (306, 252), (336, 222)]:
        out.append(f'<circle cx="{x}" cy="{y}" r="4" fill="none" stroke="#A8C4FF" stroke-opacity=".55" stroke-dasharray="2 2"/>')
    # labels
    lab = 'font-family="Newsreader, serif" font-style="italic" font-size="12.5" fill="#ECE6D6"'
    small = 'font-family="Hanken Grotesk, sans-serif" font-size="10" fill="#A7ADC6"'
    out.append(f'<text x="92" y="160" {lab}>Büyük Ayı</text><text x="156" y="160" {small}>tamam</text>'
               f'<text x="246" y="174" {lab}>Kassiopeia</text><text x="314" y="174" {small}>2/5</text>'
               f'<text x="272" y="300" {lab}>Avcı</text><text x="272" y="312" {small}>6/7</text>'
               f'<text x="203" y="{cy + 16}" {small}>Kutup Yıldızı</text>'
               f'<text x="52" y="250" {lab} font-size="11.5">Ay</text><text x="98" y="280" {lab} font-size="11.5">Merkür</text>'
               f'<text x="128" y="226" font-family="Newsreader, serif" font-style="italic" font-size="11.5" fill="#F0A070">Betelgeuse?</text>')
    out.append('</svg>')
    return "".join(out)


def home_screen():
    stats = [("12", "yıldız yaktın"), ("1", "takımyıldız bitti"), ("2", "gök cismi açıldı")]
    s_html = '<span style="background:var(--hair)"></span>'.join(
        f'<div><p class="serif num" style="margin:0;font-size:26px;line-height:1.05">{v}</p><p class="small" style="margin:2px 0 0">{l}</p></div>' for v, l in stats)
    body = f"""
{starfield(12, n=40, bottom=200, grid=False)}
<div class="layer" style="padding:54px 22px 96px;gap:12px">
  <header class="between" style="align-items:flex-end">
    <div>
      <p class="meta">İyi akşamlar</p>
      <h1 class="h1" style="font-size:38px">Evrenin</h1>
    </div>
    <div class="row" style="gap:6px;padding-bottom:4px">
      <span class="chip num" style="height:30px">23 sa odak</span>
      <span class="row num acc" style="gap:5px;height:30px;padding:0 11px;border-radius:999px;background:rgba(242,196,109,.12);font-size:13px;font-weight:600">{spark(11)}1.440</span>
    </div>
  </header>

  <a href="Sky.dc.html" aria-label="Gökyüzüme git" style="margin:0 -22px;display:block">{planisphere()}</a>

  <div style="display:grid;grid-template-columns:auto 1px auto 1px auto;justify-content:space-between;gap:0 10px">{s_html}</div>

  <section aria-labelledby="sonraki" style="display:flex;flex-direction:column;gap:12px;padding:16px;border-radius:24px;background:var(--plate)">
    <div class="row" style="align-items:flex-start;gap:12px">
      <span style="flex:none;width:40px;height:40px;border-radius:50%;background:rgba(240,160,112,.12);display:flex;align-items:center;justify-content:center">{spark(16, cls='', extra='style="fill:#F0A070"')}</span>
      <div>
        <h2 id="sonraki" class="h2">Avcı'yı bitirmene bir yıldız kaldı</h2>
        <p class="small" style="margin:3px 0 0;color:var(--paper-2)">Betelgeuse parlak bir yıldız: yalnızca 60+ dk ya da katı mod oturumunda düşer.</p>
      </div>
    </div>
    <a href="Main.dc.html" class="btn btn-acc" style="height:50px">Odaklanmaya başla</a>
  </section>
</div>
{tabbar('Home.dc.html')}"""
    return page("Evrenim", root(body))


SCREENS = {
    "Home": home_screen, "Main": main_screen, "Active": active_screen, "Sounds": sounds_screen, "Reward": reward_screen,
    "Constellation": constellation_screen, "Sky": sky_screen, "Rewards": rewards_screen, "Map": map_screen,
    "DeepSky": deepsky_screen, "Event": event_screen, "Prestige": prestige_screen,
}

if __name__ == "__main__":
    for name, fn in SCREENS.items():
        (OUT / f"{name}.dc.html").write_text(fn(), encoding="utf-8")
        print("wrote", name)
