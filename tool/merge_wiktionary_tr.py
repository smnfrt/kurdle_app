#!/usr/bin/env python3
"""kuwiktionary Werger TR çevirilerini tr_meaning_overrides.json'a merge et.

Politika:
- Mevcut entry varsa (curated, freedict, vs.) DOKUNMA — daha güvenilir kaynak.
- Yeni entry'leri 'kuwiktionary-werger' kaynağıyla ekle.
"""
from __future__ import annotations

import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OVERRIDES = ROOT / "assets" / "ferheng" / "tr_meaning_overrides.json.gz"
WIKT_TR = ROOT / "tool" / "wiktionary_tr_translations.json"


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def _read_overrides(path: Path) -> dict:
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    return json.loads(path.read_text(encoding="utf-8"))


def _write_overrides(path: Path, data: dict) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2)
    if path.suffix == ".gz":
        with gzip.open(path, "wt", encoding="utf-8") as f:
            f.write(text)
    else:
        path.write_text(text, encoding="utf-8")


def main() -> int:
    overrides = _read_overrides(OVERRIDES)
    wikt = json.loads(WIKT_TR.read_text(encoding="utf-8"))

    entries = overrides.get("entries") or {}

    added = 0
    skipped_existing = 0

    for head_raw, tr in wikt.items():
        head = normalize(head_raw)
        if not head or not tr.strip():
            continue
        if head in entries:
            skipped_existing += 1
            continue
        entries[head] = {
            "tr": tr.strip(),
            "source": "kuwiktionary-werger",
        }
        added += 1

    # Sort
    entries_sorted = dict(sorted(entries.items()))
    overrides["entries"] = entries_sorted
    overrides["version"] = "1.3.0"
    overrides["source"] = (
        overrides.get("source", "")
        + " + kuwiktionary-werger translations"
    ).strip(" +")

    _write_overrides(OVERRIDES, overrides)

    print(f"Skipped (already had TR): {skipped_existing:,}")
    print(f"Added from kuwiktionary:  {added:,}")
    print(f"Total overrides now:      {len(entries_sorted):,}")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
