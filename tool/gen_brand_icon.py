#!/usr/bin/env python3
"""Leyar marka varlıklarını ana sembolden türetir.

Ana kaynak:
  assets/branding/icon-1024.png

Bu dosya, son kullanılan Leyar ana sembolünü korur: açık oyun tahtası
zemininde ortada L harfli altın kare ve etrafında dört yeşil kare. Script artık
eski sade harf ikonunu üretmez; yalnızca mevcut ana sembolden splash ve
adaptive foreground türevlerini yeniler.

Kullanım:
  python3 tool/gen_brand_icon.py
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
"""
from __future__ import annotations

from pathlib import Path
from shutil import copyfile

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "branding"
SOURCE_ICON = OUT_DIR / "icon-1024.png"


def _resize_square(source: Path, target: Path, size: int) -> None:
    with Image.open(source) as img:
        resized = img.convert("RGBA").resize((size, size), Image.LANCZOS)
        resized.save(target, "PNG", optimize=True)


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _make_framed_splash(source: Path, target: Path, size: int = 512) -> None:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    with Image.open(source) as img:
        icon_size = 330
        icon = img.convert("RGBA").resize((icon_size, icon_size), Image.LANCZOS)
        icon.putalpha(_rounded_mask(icon_size, 76))
        canvas.alpha_composite(icon, ((size - icon_size) // 2, 91))

    canvas.save(target, "PNG", optimize=True)


def main() -> None:
    if not SOURCE_ICON.exists():
        raise FileNotFoundError(f"Ana sembol bulunamadı: {SOURCE_ICON}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    copyfile(SOURCE_ICON, OUT_DIR / "icon-foreground.png")
    _make_framed_splash(SOURCE_ICON, OUT_DIR / "splash-light.png")
    _make_framed_splash(SOURCE_ICON, OUT_DIR / "splash-dark.png")

    print("Leyar brand assets refreshed from the current main symbol:")
    print(f"  source: {SOURCE_ICON}")
    print(f"  wrote : {OUT_DIR / 'icon-foreground.png'}")
    print(f"  wrote : {OUT_DIR / 'splash-light.png'}")
    print(f"  wrote : {OUT_DIR / 'splash-dark.png'}")


if __name__ == "__main__":
    main()
