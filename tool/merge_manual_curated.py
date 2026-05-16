#!/usr/bin/env python3
"""Manuel curated TR çevirileri tr_meaning_overrides'a merge et.

Source: assets/ferheng/manual_tr_curated.json
Bu, kullanıcı geri bildirimleriyle büyüyen, repo'da tutulan listdir.
Wiktionary/freedict gibi otomatik kaynaklardan ÖNCELİKLİ olarak
uygulanır (kalite > miktar).
"""
from __future__ import annotations

import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OVERRIDES = ROOT / "assets" / "ferheng" / "tr_meaning_overrides.json.gz"
MANUAL = ROOT / "assets" / "ferheng" / "manual_tr_curated.json"


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def main() -> int:
    with gzip.open(OVERRIDES, "rt", encoding="utf-8") as f:
        overrides = json.load(f)
    manual = json.loads(MANUAL.read_text(encoding="utf-8"))

    entries = overrides.get("entries") or {}
    manual_entries = manual.get("entries") or {}

    added = 0
    overwritten = 0

    for head_raw, data in manual_entries.items():
        head = normalize(head_raw)
        tr = (data.get("tr") if isinstance(data, dict) else str(data)).strip()
        if not head or not tr:
            continue
        existing = entries.get(head)
        if existing:
            # Manual ALWAYS wins (curation > scraping)
            overwritten += 1
        else:
            added += 1
        entries[head] = {"tr": tr, "source": "manual-curated"}

    overrides["entries"] = dict(sorted(entries.items()))
    overrides["version"] = "1.5.0"
    src_str = overrides.get("source", "")
    if "manual-curated" not in src_str:
        overrides["source"] = (src_str + " + manual-curated").strip(" +")

    with gzip.open(OVERRIDES, "wt", encoding="utf-8") as f:
        json.dump(overrides, f, ensure_ascii=False, indent=2)

    print(f"Added new:           {added:,}")
    print(f"Overwrote existing:  {overwritten:,}")
    print(f"Total overrides now: {len(entries):,}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
