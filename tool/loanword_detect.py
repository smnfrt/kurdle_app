#!/usr/bin/env python3
"""Loanword heuristic — KMR entry'lerini ASCII normalize edip Türkçe
hunspell wordlist'i ile karşılaştır. Eşleşen lemma'lar = TR loanword.

Heuristic:
  Kurmancî diacritic → Türkçe karşılığı
    Î → İ (long-i dotted in TR)
    Ê → E
    Û → U
    Ş → Ş (same)
    Ç → Ç (same)

KMR-only entry'lerin headword'lerini transliterate edip Türkçe
wordlist'te ararız. Eşleşme varsa TR çeviri = entry'nin kendisi
(Türkçe lemma formuyla yazılmış hâli, çoğu zaman aynı veya çok
yakın).

Output: tr_meaning_overrides.json.gz'a 'loanword-heuristic' kaynaklı
ekleme. İkinci dur loanword olup olmadığı tartışmalı — sadece kısa
single-word eşleşmeleri kabul et (≥3 harf, no whitespace).
"""
from __future__ import annotations

import gzip
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "ferheng"
DUMP = ROOT / "tools" / "ferheng_pipeline" / "raw" / "turkish.dic"
ENTRIES = ASSETS / "entries.ndjson.gz"
OVERRIDES = ASSETS / "tr_meaning_overrides.json.gz"


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def transliterate_kmr_to_tr(s: str) -> str:
    """Kurmancî diacritic → Türkçe alfabesi karşılığı (uppercase)."""
    return (
        s.replace("Ê", "E")
         .replace("Î", "İ")
         .replace("Û", "U")
    )


def load_turkish_lemmas() -> set[str]:
    """hunspell-tr .dic'ten base lemma'ları çek."""
    out: set[str] = set()
    with DUMP.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line[0].isdigit():
                # First line is total count
                if line.isdigit():
                    continue
            # Format: word/flag,flag,... veya sadece word
            base = line.split("/", 1)[0].strip()
            if not base or "." in base:
                # 'a.ş.' gibi kısaltma — atla
                continue
            # Skip multi-word phrases
            if " " in base or "-" in base:
                continue
            base_upper = base.upper()
            # Min 3 harf
            if len(base_upper) < 3:
                continue
            out.add(base_upper)
    return out


def main() -> int:
    print("Loading Turkish lemmas...")
    tr_lemmas = load_turkish_lemmas()
    print(f"  Turkish lemmas (≥3 letters, no space/dash/dot): {len(tr_lemmas):,}")

    print("Loading existing overrides...")
    with gzip.open(OVERRIDES, "rt", encoding="utf-8") as f:
        overrides = json.load(f)
    entries_override = overrides.get("entries") or {}
    print(f"  Existing overrides: {len(entries_override):,}")

    print("Scanning entries.ndjson for KMR-only loanword candidates...")
    candidates = []  # (kmr, transliterated_tr)
    with gzip.open(ENTRIES, "rt", encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            n = normalize(e.get("normalized") or "")
            if not n or len(n) < 3:
                continue
            # Skip if already has override
            if n in entries_override:
                continue
            # Skip if has TR in entry
            defs = e.get("definitions", {})
            tr_defs = [d for d in (defs.get("tr") or []) if (d.get("gloss") or "").strip()]
            if tr_defs:
                continue
            # Check loanword match
            translit = transliterate_kmr_to_tr(n)
            if translit in tr_lemmas:
                candidates.append((n, translit))

    print(f"  Loanword candidates: {len(candidates):,}")
    if candidates:
        print(f"  First 15 samples:")
        for kmr, tr in candidates[:15]:
            same = " (same)" if kmr == tr else ""
            print(f"    {kmr:<18} → {tr}{same}")

    # Apply: source "loanword-heuristic"
    added = 0
    for kmr, tr in candidates:
        # Use Turkish form (lowercase for readability, since gloss is usually lowercase)
        gloss = tr.lower()
        entries_override[kmr] = {
            "tr": gloss,
            "source": "loanword-heuristic",
        }
        added += 1

    overrides["entries"] = dict(sorted(entries_override.items()))
    overrides["version"] = "1.7.0"
    src_str = overrides.get("source", "")
    if "loanword-heuristic" not in src_str:
        overrides["source"] = (src_str + " + loanword-heuristic").strip(" +")

    with gzip.open(OVERRIDES, "wt", encoding="utf-8") as f:
        json.dump(overrides, f, ensure_ascii=False, indent=2)

    print(f"\nAdded loanwords: {added:,}")
    print(f"Total overrides: {len(entries_override):,}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
