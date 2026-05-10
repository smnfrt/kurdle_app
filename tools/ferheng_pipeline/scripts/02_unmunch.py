#!/usr/bin/env python3
"""Expand Hunspell .dic + .aff to all surface forms via spylls.

Strategy: load the dictionary; for each lemma, enumerate all surface forms
that the affix rules can produce. Output one form per line, NFC + uppercase,
de-duplicated and sorted.

Inputs:  raw/ku_kmr.dic, raw/ku_kmr.aff
Outputs: build/kmr_surface_forms.txt   (one form per line, sorted)
         build/kmr_surface_forms.json  (stats)
"""
from __future__ import annotations

import json
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import (  # noqa: E402
    BUILD,
    RAW,
    TURKISH_ONLY,
    ensure_dirs,
    is_valid_kurmanji,
    log,
    nfc,
    normalize_headword,
)


def _load_spylls():
    try:
        from spylls.hunspell import Dictionary  # type: ignore

        return Dictionary
    except ImportError as e:
        log("ERROR: spylls not installed. Run 'make install' first.")
        raise SystemExit(1) from e


def _apply_suffix(sfx, word: str) -> str | None:
    """Apply a spylls Suffix to a word if its condition regex matches.

    spylls Suffix has: strip (str), add (str), cond_regexp (re.Pattern, anchored at end).
    """
    try:
        if not sfx.cond_regexp.search(word):
            return None
        strip = sfx.strip
        if strip and not word.endswith(strip):
            return None
        base = word[: -len(strip)] if strip else word
        return base + sfx.add
    except Exception:
        return None


def _apply_prefix(pfx, word: str) -> str | None:
    """Apply a spylls Prefix to a word if its condition regex matches.

    spylls Prefix has: strip (str), add (str), cond_regexp (re.Pattern, anchored at start).
    """
    try:
        if not pfx.cond_regexp.search(word):
            return None
        strip = pfx.strip
        if strip and not word.startswith(strip):
            return None
        base = word[len(strip):] if strip else word
        return pfx.add + base
    except Exception:
        return None


def _enumerate_forms(d) -> set[str]:
    """Iterate all words in dic, expand affixes via spylls SFX/PFX tables.

    For each lemma:
      1. Emit the base stem.
      2. For each flag in the lemma's flag set, look up suffixes (aff.SFX[flag])
         and prefixes (aff.PFX[flag]); apply each whose condition matches.
      3. Cross-product: a prefix+suffix combo is allowed only if both have
         crossproduct=True.
    """
    forms: set[str] = set()
    aff = d.aff
    dic = d.dic

    sfx_table = getattr(aff, "SFX", {}) or {}
    pfx_table = getattr(aff, "PFX", {}) or {}

    for word in dic.words:
        stem = word.stem
        flags = word.flags or ()

        forms.add(stem)

        # Collect suffixed forms and prefixed forms separately so we can do
        # cross-product after.
        suffixed: list[tuple[str, bool]] = []  # (form, sfx.crossproduct)
        prefixed: list[tuple[str, bool]] = []

        for flag in flags:
            for sfx in sfx_table.get(flag, ()):
                new = _apply_suffix(sfx, stem)
                if new:
                    forms.add(new)
                    suffixed.append((new, bool(getattr(sfx, "crossproduct", False))))
            for pfx in pfx_table.get(flag, ()):
                new = _apply_prefix(pfx, stem)
                if new:
                    forms.add(new)
                    prefixed.append((new, bool(getattr(pfx, "crossproduct", False))))

        # Cross-product: apply each crossproduct-prefix to each crossproduct-suffix-form.
        for sfx_form, sfx_cp in suffixed:
            if not sfx_cp:
                continue
            for flag in flags:
                for pfx in pfx_table.get(flag, ()):
                    if not getattr(pfx, "crossproduct", False):
                        continue
                    new = _apply_prefix(pfx, sfx_form)
                    if new:
                        forms.add(new)

    return forms


def main() -> int:
    ensure_dirs()
    Dictionary = _load_spylls()

    dic_path = RAW / "ku_kmr.dic"
    aff_path = RAW / "ku_kmr.aff"
    if not dic_path.exists() or not aff_path.exists():
        log(f"ERROR: missing {dic_path} or {aff_path}. Run 'make fetch' first.")
        return 1

    log(f"loading {dic_path}")
    d = Dictionary.from_files(str(dic_path.with_suffix("")))

    log("enumerating surface forms (this can take a minute)")
    raw_forms = _enumerate_forms(d)
    log(f"  raw forms: {len(raw_forms):,}")

    # Normalize, filter, dedupe.
    cleaned: set[str] = set()
    skipped_turkish = 0
    skipped_invalid = 0
    for w in raw_forms:
        n = normalize_headword(w)
        if not n:
            continue
        if any(ch in TURKISH_ONLY for ch in n):
            skipped_turkish += 1
            continue
        if not is_valid_kurmanji(n):
            skipped_invalid += 1
            continue
        cleaned.add(n)

    log(f"  cleaned forms: {len(cleaned):,} "
        f"(skipped: {skipped_turkish} Turkish-only, {skipped_invalid} invalid)")

    sorted_forms = sorted(cleaned)
    out_txt = BUILD / "kmr_surface_forms.txt"
    out_txt.write_text("\n".join(sorted_forms) + "\n", encoding="utf-8")

    stats = {
        "total_forms": len(cleaned),
        "skipped_turkish_only_chars": skipped_turkish,
        "skipped_invalid_chars": skipped_invalid,
        "first_10": sorted_forms[:10],
        "last_10": sorted_forms[-10:],
    }
    (BUILD / "kmr_surface_forms.json").write_text(
        json.dumps(stats, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    log(f"wrote {out_txt} ({len(sorted_forms):,} forms)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
