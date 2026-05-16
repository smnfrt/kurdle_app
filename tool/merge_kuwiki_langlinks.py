#!/usr/bin/env python3
"""kuwiki langlinks (KMR Wikipedia → TR Wikipedia) çiftlerinden
sözlük-uygun olanları tr_meaning_overrides'a merge et.

Filtreler:
- Tek kelime (boşluksuz)
- Pure numeric değil
- Parantez/nokta içeren özel isimler değil
- entries.ndjson'da headword olarak var
- Override'da zaten yoksa
"""
from __future__ import annotations

import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OVERRIDES = ROOT / "assets" / "ferheng" / "tr_meaning_overrides.json.gz"
import os

SRC_NAME = os.environ.get(
    "SRC_FILE", "kuwiki_langlinks_kmr_to_tr.json"
)
SRC = ROOT / "tool" / SRC_NAME
ENTRIES = ROOT / "assets" / "ferheng" / "entries.ndjson.gz"

SKIP_PATTERN = re.compile(r"[\.\(\),:/]|^\d+$|\s|^['’]")


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def main() -> int:
    src = json.loads(SRC.read_text(encoding="utf-8"))
    with gzip.open(OVERRIDES, "rt", encoding="utf-8") as f:
        overrides = json.load(f)

    # Sadece entries.ndjson'da gerçekten var olan headword'leri al
    entry_set = set()
    with gzip.open(ENTRIES, "rt", encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            n = normalize((e.get("normalized") or ""))
            if n:
                entry_set.add(n)

    entries = overrides.get("entries") or {}

    added = 0
    rejected_filter = 0
    rejected_no_entry = 0
    rejected_existing = 0

    for kmr_raw, tr_raw in src.items():
        kmr = normalize(kmr_raw)
        if not kmr or SKIP_PATTERN.search(kmr_raw):
            rejected_filter += 1
            continue
        if kmr not in entry_set:
            rejected_no_entry += 1
            continue
        if kmr in entries:
            rejected_existing += 1
            continue
        tr_clean = tr_raw.strip()
        if not tr_clean or SKIP_PATTERN.search(tr_clean):
            rejected_filter += 1
            continue
        source_label = "kuwiktionary-langlinks" if "kuwiktionary" in SRC_NAME else "kuwiki-langlinks"
        entries[kmr] = {
            "tr": tr_clean.lower() if tr_clean.isupper() else tr_clean,
            "source": source_label,
        }
        added += 1

    overrides["entries"] = dict(sorted(entries.items()))
    overrides["version"] = "1.6.0"
    src_str = overrides.get("source", "")
    if "kuwiki-langlinks" not in src_str:
        overrides["source"] = (src_str + " + kuwiki-langlinks").strip(" +")

    with gzip.open(OVERRIDES, "wt", encoding="utf-8") as f:
        json.dump(overrides, f, ensure_ascii=False, indent=2)

    print(f"Source pairs:                {len(src):,}")
    print(f"Rejected (filter):           {rejected_filter:,}")
    print(f"Rejected (no entry):         {rejected_no_entry:,}")
    print(f"Rejected (already in override): {rejected_existing:,}")
    print(f"Added:                       {added:,}")
    print(f"Total overrides now:         {len(entries):,}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
