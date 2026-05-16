#!/usr/bin/env python3
"""Genişletilmiş kuwiktionary parse sonucunu mevcut entries.ndjson'a merge et.

Politika:
- Mevcut entry varsa DOKUNMA (Wiktionary + legacy + tr_overrides ile zenginleştirilmiş, kalitesi yüksek)
- Yeni entry varsa kuwiktionary v2'den ekle (sadece KMR var, TR sonra inheritance ile gelir)
"""
from __future__ import annotations

import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENTRIES_GZ = ROOT / "assets" / "ferheng" / "entries.ndjson.gz"
V2 = ROOT / "tool" / "kuwiktionary_v2_kmr.jsonl"


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def main() -> int:
    # Load existing entries
    existing: dict[str, dict] = {}
    with gzip.open(ENTRIES_GZ, "rt", encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            n = normalize(e.get("normalized") or "")
            if n:
                existing[n] = e
    print(f"Existing entries: {len(existing):,}")

    # Load v2
    v2_entries: dict[str, dict] = {}
    with V2.open("r", encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            n = normalize(e.get("normalized") or "")
            if n:
                v2_entries[n] = e
    print(f"V2 entries:       {len(v2_entries):,}")

    # Merge: keep existing, add new
    added = 0
    for n, e_v2 in v2_entries.items():
        if n in existing:
            continue
        # Convert v2 schema → entries.ndjson schema
        # v2: definitions_kmr / definitions_tr
        # entries.ndjson: definitions: { kmr: [...], tr: [...] }
        from_v2 = {
            "headword": e_v2.get("headword"),
            "normalized": n,
            "prefixes": list({n[:i] for i in range(1, min(len(n), 5) + 1)}),
            "dialect": "kmr",
            "pos": e_v2.get("pos") or [],
            "ipa": e_v2.get("ipa") or "",
            "definitions": {
                "kmr": e_v2.get("definitions_kmr") or [],
                "tr": [],
            },
            "etymology": "",
            "categories": [],
            "related": [],
            "audioUrl": None,
            "source": "kuwiktionary",
            "sourceUrl": e_v2.get("source_url"),
            "license": "CC BY-SA 4.0",
            "version": 1,
            "createdAt": None,
            "updatedAt": None,
        }
        existing[n] = from_v2
        added += 1

    print(f"Added new entries: {added:,}")
    print(f"Total now:         {len(existing):,}")

    # Write back as gzip
    with gzip.open(ENTRIES_GZ, "wt", encoding="utf-8") as f:
        for n in sorted(existing.keys()):
            f.write(json.dumps(existing[n], ensure_ascii=False) + "\n")

    size_mb = ENTRIES_GZ.stat().st_size / 1024 / 1024
    print(f"Wrote {ENTRIES_GZ} ({size_mb:.1f} MB)")
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
