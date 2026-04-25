#!/usr/bin/env python3
"""
Generates Radcap AppIcon PNGs.
Design: dark charcoal field · silver-rimmed camera lens · deep blue glass
        with concentric aperture rings · four teleprompter text lines
        centered in the glass · specular arc highlight upper-left.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ICONSET = Path(__file__).parent.parent / "Assets.xcassets/AppIcon.appiconset"

SIZES = [
    (16,   1, "icon_16x16.png"),
    (16,   2, "icon_16x16@2x.png"),
    (32,   1, "icon_32x32.png"),
    (32,   2, "icon_32x32@2x.png"),
    (128,  1, "icon_128x128.png"),
    (128,  2, "icon_128x128@2x.png"),
    (256,  1, "icon_256x256.png"),
    (256,  2, "icon_256x256@2x.png"),
    (512,  1, "icon_512x512.png"),
    (512,  2, "icon_512x512@2x.png"),
]


def circ(draw, cx, cy, r, fill=None, outline=None, width=1):
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=fill, outline=outline, width=width)


def make_icon(px: int) -> Image.Image:
    img  = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = cy = px // 2

    # ── Background ───────────────────────────────────────────────────────────
    draw.rectangle([0, 0, px, px], fill=(22, 22, 34, 255))

    # ── Outer silver bezel ───────────────────────────────────────────────────
    circ(draw, cx, cy, int(px * 0.455), fill=(72, 78, 98, 255))
    circ(draw, cx, cy, int(px * 0.436), fill=(32, 36, 52, 255))

    # ── Lens glass (deep navy) ───────────────────────────────────────────────
    r_glass = int(px * 0.388)
    circ(draw, cx, cy, r_glass, fill=(14, 26, 66, 255))

    # Gradient illusion: slightly lighter off-center fill
    if px >= 32:
        ox, oy = int(px * 0.03), int(px * 0.04)
        circ(draw, cx - ox, cy - oy, int(px * 0.305), fill=(20, 38, 80, 255))

    # ── Aperture ring engravings ─────────────────────────────────────────────
    if px >= 32:
        sw = max(1, int(px * 0.004))
        for rf, alpha in [(0.388, 70), (0.352, 50), (0.288, 45)]:
            circ(draw, cx, cy, int(px * rf),
                 outline=(55, 88, 160, alpha), width=sw)

    # ── Deep center element ──────────────────────────────────────────────────
    r_ctr = int(px * 0.170)
    circ(draw, cx, cy, r_ctr, fill=(8, 14, 38, 255))
    if px >= 48:
        circ(draw, cx, cy, r_ctr,
             outline=(45, 72, 140, 55), width=max(1, int(px * 0.004)))

    # ── Text lines (teleprompter script reflected in glass) ──────────────────
    # Four lines of varying width, centered vertically, clearly inside the glass.
    line_specs = [
        (0.27, (148, 182, 236, 215)),   # medium
        (0.36, (128, 165, 220, 200)),   # longest
        (0.30, (112, 150, 205, 182)),   # medium-long
        (0.19, ( 94, 133, 188, 162)),   # short
    ]
    n        = len(line_specs)
    spacing  = int(px * 0.053)
    line_h   = max(1, int(px * 0.011))
    y0       = cy - int((n - 1) * spacing / 2)

    # Draw lines onto a separate RGBA layer, then alpha-composite onto img.
    # DO NOT use img.paste(layer, mask=…) — that replaces existing pixels
    # with the (mostly transparent) layer, wiping out the glass.
    lines_layer = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    ldraw       = ImageDraw.Draw(lines_layer)

    for i, (w_frac, color) in enumerate(line_specs):
        lw = int(r_glass * w_frac * 2)
        ly = y0 + i * spacing
        bb = [cx - lw // 2, ly - line_h, cx + lw // 2, ly + line_h]
        if line_h >= 2:
            ldraw.rounded_rectangle(bb, radius=line_h, fill=color)
        else:
            ldraw.rectangle(bb, fill=color)

    # Alpha-composite: only touches pixels where lines_layer has alpha > 0.
    img = Image.alpha_composite(img, lines_layer)
    draw = ImageDraw.Draw(img)   # re-bind after composite

    # ── Specular arc highlight (upper-left, like studio glass) ───────────────
    if px >= 64:
        hl_r  = int(r_glass * 0.58)
        hl_ox = int(px * 0.055)
        hl_oy = int(px * 0.080)
        hl_bb = [cx - hl_r + hl_ox, cy - hl_r - hl_oy,
                 cx + hl_r + hl_ox, cy + hl_r - hl_oy]
        draw.arc(hl_bb, start=215, end=308,
                 fill=(185, 215, 255, 105),
                 width=max(1, int(px * 0.015)))

    # Small catch-light dot (upper-left of glass)
    if px >= 128:
        dl_r = max(2, int(px * 0.022))
        dl_x = cx - int(r_glass * 0.42)
        dl_y = cy - int(r_glass * 0.48)
        for rr, aa in [(dl_r * 2, 28), (dl_r, 65)]:
            circ(draw, dl_x, dl_y, rr, fill=(215, 232, 255, aa))

    return img


def main():
    ICONSET.mkdir(parents=True, exist_ok=True)

    generated = []
    for pt, scale, fname in SIZES:
        px  = pt * scale
        img = make_icon(px)
        out = ICONSET / fname
        img.save(out, "PNG", optimize=True)
        generated.append((pt, scale, fname))
        print(f"  ✓  {fname}  ({px}×{px})")

    contents = {
        "images": [
            {"idiom": "mac", "scale": f"{sc}x", "size": f"{pt}x{pt}", "filename": fn}
            for pt, sc, fn in generated
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print("\nContents.json updated ✓")


if __name__ == "__main__":
    main()
