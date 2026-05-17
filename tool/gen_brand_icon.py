#!/usr/bin/env python3
"""Peyvok marka iconu üretici.

Splash ve app_theme'deki "P" logosuyla aynı görsel dilde:
- Yeşil radial gradient (#4CAF50 → #2E7D32)
- Yumuşak alt parıltısı (subtle inner shadow)
- Geniş, kalın beyaz "P" harfi merkeze

Çıktılar:
  assets/branding/icon-1024.png         (master, flutter_launcher_icons girdisi)
  assets/branding/icon-foreground.png   (adaptive icon foreground, transparan)
  assets/branding/splash-light.png      (light splash, 512x512)
  assets/branding/splash-dark.png       (dark splash — şu an aynı tasarım)

Kullanım: python3 tool/gen_brand_icon.py
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "branding"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def _find_font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFCompactDisplay-Bold.otf",
        "/Library/Fonts/Arial Bold.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def _gradient(size: int, color_top: tuple, color_bottom: tuple) -> Image.Image:
    """Topleft → bottomright lineer gradient."""
    base = Image.new("RGB", (size, size), color_top)
    top = Image.new("RGB", (size, size), color_top)
    bot = Image.new("RGB", (size, size), color_bottom)
    mask = Image.new("L", (size, size))
    md = ImageDraw.Draw(mask)
    # Diagonal gradient: pixel value = (x + y) / (2 * size) * 255
    for y in range(size):
        for x in range(size):
            md.point((x, y), int(((x + y) / (2 * size)) * 255))
    base = Image.composite(bot, top, mask)
    return base


def _gradient_fast(size: int, color_top: tuple, color_bottom: tuple) -> Image.Image:
    """Hızlı gradient (line-by-line resize trick)."""
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        r = round(color_top[0] * (1 - t) + color_bottom[0] * t)
        g = round(color_top[1] * (1 - t) + color_bottom[1] * t)
        b = round(color_top[2] * (1 - t) + color_bottom[2] * t)
        grad.putpixel((0, y), (r, g, b))
    return grad.resize((size, size))


def make_app_icon(size: int = 1024) -> Image.Image:
    """Tam dolu kare ikon — iOS için (rounded corners OS uygular)."""
    img = _gradient_fast(size, (76, 175, 80), (27, 94, 32))

    # Yumuşak iç vinyet — sol-üst parıltı, sağ-alt karanlık
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(20):
        opacity = int(180 * (1 - i / 20) * 0.10)
        if opacity <= 0:
            continue
        gd.ellipse(
            (
                -size // 3 + i * 6,
                -size // 3 + i * 6,
                size * 2 // 3 - i * 6,
                size * 2 // 3 - i * 6,
            ),
            fill=(255, 255, 255, opacity),
        )
    img = Image.alpha_composite(img.convert("RGBA"), glow)

    # "P" harfi
    draw = ImageDraw.Draw(img)
    font_size = int(size * 0.66)
    font = _find_font(font_size)
    text = "P"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    # Vertical optical center (-yt offset)
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1] - size * 0.02
    # Gölge
    shadow_offset = max(4, size // 200)
    draw.text(
        (x + shadow_offset, y + shadow_offset),
        text,
        font=font,
        fill=(0, 0, 0, 70),
    )
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    return img


def make_foreground_icon(size: int = 1024) -> Image.Image:
    """Android adaptive icon foreground — şeffaf, sadece P işareti.

    Android adaptive icons güvenli alan: merkez 66% (240x240 / 360x360 canvas
    için 264x264 logo bölgesi). flutter_launcher_icons varsayılan padding'i
    uygulayacak; biz sade ortalanmış P koymalıyız (background ayrı katman).
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Disk arkaplan
    margin = int(size * 0.15)
    grad = _gradient_fast(size - 2 * margin, (76, 175, 80), (27, 94, 32))
    mask = Image.new("L", grad.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, grad.size[0], grad.size[1]), fill=255)
    img.paste(grad, (margin, margin), mask)
    # "P"
    font_size = int(size * 0.4)
    font = _find_font(font_size)
    text = "P"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1] - size * 0.02
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    return img


def make_splash_image(size: int = 512, dark: bool = False) -> Image.Image:
    """Splash logo — transparan arkaplan, merkez yeşil dairesel logo."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Dış parıltı (subtle ring)
    for i in range(8):
        radius = int(size * (0.42 + i * 0.012))
        alpha = max(0, 50 - i * 6)
        draw.ellipse(
            (
                size // 2 - radius,
                size // 2 - radius,
                size // 2 + radius,
                size // 2 + radius,
            ),
            outline=(76, 175, 80, alpha),
            width=2,
        )
    # Yeşil daire (gradient'li disk)
    disk_size = int(size * 0.6)
    grad = _gradient_fast(disk_size, (76, 175, 80), (27, 94, 32))
    mask = Image.new("L", grad.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, grad.size[0], grad.size[1]), fill=255)
    pos = ((size - disk_size) // 2, (size - disk_size) // 2)
    img.paste(grad, pos, mask)
    # "P" harfi
    font_size = int(disk_size * 0.7)
    font = _find_font(font_size)
    text = "P"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1] - size * 0.015
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    return img


if __name__ == "__main__":
    print("Generating Peyvok brand icons...")
    icon = make_app_icon(1024)
    icon.save(OUT_DIR / "icon-1024.png", "PNG", optimize=True)
    print(f"  ✓ {OUT_DIR / 'icon-1024.png'}")

    fg = make_foreground_icon(1024)
    fg.save(OUT_DIR / "icon-foreground.png", "PNG", optimize=True)
    print(f"  ✓ {OUT_DIR / 'icon-foreground.png'}")

    splash = make_splash_image(512)
    splash.save(OUT_DIR / "splash-light.png", "PNG", optimize=True)
    splash.save(OUT_DIR / "splash-dark.png", "PNG", optimize=True)
    print(f"  ✓ {OUT_DIR / 'splash-light.png'}")
    print(f"  ✓ {OUT_DIR / 'splash-dark.png'}")
    print("\nNext: run flutter_launcher_icons + flutter_native_splash via pubspec config.")
