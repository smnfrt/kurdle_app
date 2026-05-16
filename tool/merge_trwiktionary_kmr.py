#!/usr/bin/env python3
"""tr.wiktionary'den çıkardığımız KMR→TR pairs'i tr_meaning_overrides'a merge et."""
from __future__ import annotations

import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OVERRIDES = ROOT / "assets" / "ferheng" / "tr_meaning_overrides.json.gz"
SRC = ROOT / "tool" / "trwiktionary_kmr_to_tr.json"


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def main() -> int:
    with gzip.open(OVERRIDES, "rt", encoding="utf-8") as f:
        overrides = json.load(f)
    src = json.loads(SRC.read_text(encoding="utf-8"))

    entries = overrides.get("entries") or {}

    added = 0
    skipped_existing = 0

    for kmr, tr in src.items():
        n = normalize(kmr)
        tr_clean = (tr or "").strip()
        if not n or not tr_clean:
            continue
        if n in entries:
            skipped_existing += 1
            continue
        entries[n] = {
            "tr": tr_clean,
            "source": "trwiktionary-ceviri",
        }
        added += 1

    overrides["entries"] = dict(sorted(entries.items()))
    overrides["version"] = "1.4.0"
    src_str = overrides.get("source", "")
    if "trwiktionary" not in src_str:
        overrides["source"] = (src_str + " + trwiktionary çeviri").strip(" +")

    with gzip.open(OVERRIDES, "wt", encoding="utf-8") as f:
        json.dump(overrides, f, ensure_ascii=False, indent=2)

    print(f"Skipped (already had TR): {skipped_existing:,}")
    print(f"Added from trwiktionary:  {added:,}")
    print(f"Total overrides now:      {len(overrides['entries']):,}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
