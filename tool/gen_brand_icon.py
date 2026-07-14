#!/usr/bin/env python3
"""Peyvok marka varlıklarını ana sembolden türetir.

Ana kaynak:
  assets/branding/icon-1024.png

Bu dosya, son kullanılan Peyvok ana sembolünü korur: açık oyun tahtası
zemininde ortada yıldızlı P karesi ve etrafında dört yeşil kare. Script artık
eski sade yeşil "P" ikonunu üretmez; yalnızca mevcut ana sembolden splash ve
adaptive foreground türevlerini yeniler.

Kullanım:
  python3 tool/gen_brand_icon.py
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
"""
from __future__ import annotations

from pathlib import Path
from shutil import copyfile

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "branding"
SOURCE_ICON = OUT_DIR / "icon-1024.png"


def _resize_square(source: Path, target: Path, size: int) -> None:
    with Image.open(source) as img:
        resized = img.convert("RGBA").resize((size, size), Image.LANCZOS)
        resized.save(target, "PNG", optimize=True)


def main() -> None:
    if not SOURCE_ICON.exists():
        raise FileNotFoundError(f"Ana sembol bulunamadı: {SOURCE_ICON}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    copyfile(SOURCE_ICON, OUT_DIR / "icon-foreground.png")
    _resize_square(SOURCE_ICON, OUT_DIR / "splash-light.png", 512)
    _resize_square(SOURCE_ICON, OUT_DIR / "splash-dark.png", 512)

    print("Peyvok brand assets refreshed from the current main symbol:")
    print(f"  source: {SOURCE_ICON}")
    print(f"  wrote : {OUT_DIR / 'icon-foreground.png'}")
    print(f"  wrote : {OUT_DIR / 'splash-light.png'}")
    print(f"  wrote : {OUT_DIR / 'splash-dark.png'}")


if __name__ == "__main__":
    main()
