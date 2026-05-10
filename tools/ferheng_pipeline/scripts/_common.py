"""Shared utilities for the ferheng pipeline."""
from __future__ import annotations

import hashlib
import json
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "raw"
BUILD = ROOT / "build"
OUT = BUILD / "out"
DATA = ROOT / "data"

# Kurmancî Latin alphabet, in canonical order. Used for sorting and validation.
KURMANJI_ALPHABET = list("ABCÇDEÊFGHIÎJKLMNOPQRSŞTUÛVWXYZ")
KURMANJI_SET = set(KURMANJI_ALPHABET)

# Letters that look like Turkish characters but are NOT valid Kurmanji.
# We must catch these to avoid Turkish dotted-i contamination.
TURKISH_ONLY = {"İ", "Ğ", "Ü", "Ö"}


def nfc(s: str) -> str:
    """Normalize string to NFC and strip whitespace."""
    return unicodedata.normalize("NFC", s).strip()


def normalize_headword(s: str) -> str:
    """Pipeline-canonical normalization: NFC, uppercase. Used for wordIds."""
    return nfc(s).upper()


def is_valid_kurmanji(word: str) -> bool:
    """Returns True if every char is in the Kurmanji alphabet (NFC, uppercase)."""
    if not word:
        return False
    w = normalize_headword(word)
    if not w:  # normalize() may strip to empty (e.g. whitespace-only input)
        return False
    if any(ch in TURKISH_ONLY for ch in w):
        return False
    # Allow apostrophe and hyphen in compound words but not in headwords.
    return all(ch in KURMANJI_SET for ch in w)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def load_lock() -> dict:
    return json.loads((ROOT / "sources.lock.json").read_text(encoding="utf-8"))


def ensure_dirs() -> None:
    for d in (RAW, BUILD, OUT):
        d.mkdir(parents=True, exist_ok=True)


def log(*args) -> None:
    print("[ferheng]", *args, file=sys.stderr, flush=True)
