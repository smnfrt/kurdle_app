#!/usr/bin/env python3
"""Google Play feature graphic üretici (1024x500).

Layout: sol yarıda Leyar app icon, sağ yarıda büyük "Leyar" yazısı ve
tagline "Listika Peyvan". Arkaplan: eski feature graphic dilini koruyan açık
yeşil oyun tahtası yüzeyi.

Çıktı: assets/branding/feature-graphic-1024x500.png
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BRAND = ROOT / "assets" / "branding"
OUT = BRAND / "feature-graphic-1024x500.png"
ICON = BRAND / "icon-1024.png"


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
    img = _gradient_h(W, H, (223, 239, 211), (247, 244, 213)).convert("RGBA")
    draw = ImageDraw.Draw(img)

    # Hafif oyun tahtası çizgileri.
    for x in range(-80, W, 120):
        draw.line((x, 0, x + 120, H), fill=(65, 115, 68, 34), width=2)
    for y in range(60, H, 110):
        draw.line((0, y, W, y - 80), fill=(255, 255, 255, 36), width=2)

    # Sol: mevcut ana ikon.
    icon_size = 315
    icon_x = 68
    icon_y = 92
    draw.rounded_rectangle(
        (45, 70, 405, 430),
        radius=78,
        fill=(242, 247, 224, 230),
    )
    with Image.open(ICON) as source_icon:
        app_icon = source_icon.convert("RGBA").resize(
            (icon_size, icon_size), Image.LANCZOS
        )
    img.alpha_composite(app_icon, (icon_x, icon_y))

    # Sağ: başlık + tagline
    text_x = 455
    draw.rounded_rectangle(
        (420, 30, 1005, 470),
        radius=24,
        fill=(229, 242, 217, 245),
        outline=(43, 105, 51, 210),
        width=3,
    )
    title_font = _find_font(76)
    sub_font = _find_font(31)
    chip_font = _find_font(25)
    line_font = _find_font(29)

    draw.text((text_x, 92), "Leyar", font=title_font, fill=(18, 29, 29, 255))
    draw.text(
        (text_x, 178),
        "Listika Peyvan",
        font=sub_font,
        fill=(34, 112, 56, 255),
    )

    def chip(x: int, y: int, label: str, color) -> int:
        bbox = draw.textbbox((0, 0), label, font=chip_font)
        width = bbox[2] - bbox[0] + 40
        draw.rounded_rectangle(
            (x, y, x + width, y + 43),
            radius=22,
            fill=color,
            outline=(255, 255, 255, 240),
            width=2,
        )
        draw.text((x + 20, y + 6), label, font=chip_font, fill=(255, 255, 255))
        return width

    first_chip = chip(text_x, 260, "Kelime tahtası", (34, 112, 56, 255))
    chip(text_x + first_chip + 22, 260, "Ferheng", (34, 112, 56, 255))
    chip(text_x, 322, "Günün meydan okuması", (217, 156, 38, 255))
    draw.text(
        (text_x, 397),
        "TR + KMR  •  AI ve arkadaşlarla oyun",
        font=line_font,
        fill=(49, 63, 60, 255),
    )

    return img.convert("RGB")


if __name__ == "__main__":
    img = make_feature_graphic()
    img.save(OUT, "PNG", optimize=True)
    print(f"Feature graphic: {OUT}")
