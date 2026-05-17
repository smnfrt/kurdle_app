#!/usr/bin/env python3
"""KMR-only 'Rewşa...' entry'lerinden base lemma'yı çıkarıp inheritance et.

Kuwiktionary'de pek çok entry "Rewşa [grammatical_form] ya/yê [BASE]." formatında.
Bu inflection notu, base kelimenin TR çevirisini miras alabilir.

Heuristik:
1. Gloss "Rewşa" ile başlıyorsa
2. Son kelime "BASE." pattern'i ile bitiyorsa (ya/yê BASE.)
3. BASE entries.ndjson'da var ve TR'si varsa → child'a o TR'yi ata

Output: tr_meaning_overrides.json.gz'e 'rewsa-base-resolved' kaynaklı ekleme
"""
from __future__ import annotations

import gzip
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "ferheng"
ENTRIES = ASSETS / "entries.ndjson.gz"
OVERRIDES = ASSETS / "tr_meaning_overrides.json.gz"

BASE_RE = re.compile(
    r"\b(?:ya|yê|ji)\s+([A-Za-zÊÎÛŞÇêîûşçÉÔ\-']+)\s*[\.,;:]?\s*$"
)


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def main() -> int:
    print("Loading entries + overrides...")
    entries: dict[str, dict] = {}
    with gzip.open(ENTRIES, "rt", encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            n = normalize(e.get("normalized") or "")
            if n:
                entries[n] = e

    with gzip.open(OVERRIDES, "rt", encoding="utf-8") as f:
        overrides = json.load(f)
    ov_entries = overrides.get("entries") or {}
    ov_tr = {
        k.upper(): (v.get("tr") if isinstance(v, dict) else str(v))
        for k, v in ov_entries.items()
    }
    print(f"  entries: {len(entries):,}, overrides: {len(ov_entries):,}")

    added = 0
    no_base = 0
    base_unresolved = 0

    for n, e in entries.items():
        if n in ov_entries:
            continue
        defs = e.get("definitions", {})
        kmr = [
            d.get("gloss", "").strip()
            for d in (defs.get("kmr") or [])
            if (d.get("gloss") or "").strip()
        ]
        tr = [
            d
            for d in (defs.get("tr") or [])
            if (d.get("gloss") or "").strip()
        ]
        if not kmr or tr:
            continue
        gloss = kmr[0]
        if not gloss.startswith("Rewşa"):
            continue
        m = BASE_RE.search(gloss)
        if not m:
            no_base += 1
            continue
        base = normalize(m.group(1))
        # Look up base TR via override or entry
        base_tr = ov_tr.get(base)
        if not base_tr:
            base_entry = entries.get(base)
            if base_entry:
                base_tr_defs = [
                    d.get("gloss", "").strip()
                    for d in (base_entry.get("definitions", {}).get("tr") or [])
                    if (d.get("gloss") or "").strip()
                ]
                if base_tr_defs:
                    base_tr = base_tr_defs[0]
        if not base_tr:
            base_unresolved += 1
            continue
        ov_entries[n] = {
            "tr": base_tr,
            "source": f"rewsa-base-resolved:{base}",
        }
        added += 1

    overrides["entries"] = dict(sorted(ov_entries.items()))
    overrides["version"] = "1.8.0"
    src_str = overrides.get("source", "")
    if "rewsa-base-resolved" not in src_str:
        overrides["source"] = (src_str + " + rewsa-base-resolved").strip(" +")

    with gzip.open(OVERRIDES, "wt", encoding="utf-8") as f:
        json.dump(overrides, f, ensure_ascii=False, indent=2)

    print(f"\nResolved: {added:,}")
    print(f"No base extractable: {no_base:,}")
    print(f"Base also KMR-only:  {base_unresolved:,}")
    print(f"Total overrides now: {len(ov_entries):,}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
