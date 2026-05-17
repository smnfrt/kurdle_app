#!/usr/bin/env python3
"""Google Play feature graphic üretici (1024x500).

Layout: sol yarıda Peyvok app icon, sağ yarıda büyük "Peyvok" yazısı ve
tagline "Kurmancî Kelime Oyunu". Arkaplan: koyu yeşil → siyah gradient.

Çıktı: assets/branding/feature-graphic-1024x500.png
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "branding" / "feature-graphic-1024x500.png"


def _find_font(size: int) -> ImageFont.FreeTypeFont:
    for p in [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFCompactDisplay-Bold.otf",
    ]:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def _gradient_h(width: int, height: int, c1, c2) -> Image.Image:
    """Yatay gradient — soldan sağa."""
    base = Image.new("RGB", (width, 1))
    for x in range(width):
        t = x / max(1, width - 1)
        r = round(c1[0] * (1 - t) + c2[0] * t)
        g = round(c1[1] * (1 - t) + c2[1] * t)
        b = round(c1[2] * (1 - t) + c2[2] * t)
        base.putpixel((x, 0), (r, g, b))
    return base.resize((width, height))


def make_feature_graphic() -> Image.Image:
    W, H = 1024, 500
    img = _gradient_h(W, H, (15, 25, 35), (27, 94, 32))  # bg → primary green
    draw = ImageDraw.Draw(img)

    # Sol: app icon kompakt logo (P disk)
    icon_size = 280
    icon_x = 80
    icon_y = (H - icon_size) // 2
    # Disk gradient
    disk = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    dd = ImageDraw.Draw(disk)
    # Outer subtle glow
    for i in range(10):
        r = icon_size // 2 + i * 2
        cx = icon_size // 2
        dd.ellipse(
            (cx - r, cx - r, cx + r, cx + r),
            outline=(76, 175, 80, max(0, 24 - i * 2)),
            width=1,
        )
    # Yeşil disk
    grad = _gradient_h(icon_size, icon_size, (76, 175, 80), (27, 94, 32))
    mask = Image.new("L", (icon_size, icon_size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, icon_size, icon_size), fill=255)
    disk.paste(grad, (0, 0), mask)
    # "P"
    font_p = _find_font(int(icon_size * 0.7))
    p_text = "P"
    bbox = dd.textbbox((0, 0), p_text, font=font_p)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    dd.text(
        ((icon_size - tw) / 2 - bbox[0], (icon_size - th) / 2 - bbox[1] - 6),
        p_text,
        font=font_p,
        fill=(255, 255, 255, 255),
    )
    img.paste(disk, (icon_x, icon_y), disk)

    # Sağ: başlık + tagline
    text_x = icon_x + icon_size + 60
    title_font = _find_font(80)
    sub_font = _find_font(28)
    tag_font = _find_font(22)

    # Peyvok
    draw.text(
        (text_x, 130),
        "Peyvok",
        font=title_font,
        fill=(255, 255, 255, 255),
    )
    # Kurmancî Kelime Oyunu
    draw.text(
        (text_x, 230),
        "Kurmancî Kelime Oyunu",
        font=sub_font,
        fill=(200, 230, 201, 255),
    )
    # Tag — alt satırlar
    draw.text(
        (text_x, 290),
        "Wordle  ·  Scrabble  ·  216k Ferheng",
        font=tag_font,
        fill=(255, 255, 255, 220),
    )
    draw.text(
        (text_x, 325),
        "TR + KMR  ·  AI ve arkadaşlarla",
        font=tag_font,
        fill=(200, 230, 201, 220),
    )

    return img


if __name__ == "__main__":
    img = make_feature_graphic()
    img.save(OUT, "PNG", optimize=True)
    print(f"Feature graphic: {OUT}")
