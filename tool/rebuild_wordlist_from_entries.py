#!/usr/bin/env python3
"""Wordlist'i sadece sözlükte entry'si olan kelimelere daralt.

Önce: assets/ferheng/wordlist.txt.gz = 1,572,503 Hunspell surface forms.
Sonra: aynı dosya = entries.ndjson.gz headwords + legacy daily wordlists.

Bu, oyunda kabul edilen kelimelerin %100'ünün sözlükte (en azından KMR
tanımıyla) bulunmasını sağlar. Hunspell-only orphan formlar (sözlükte
entry'si olmayan obscure çekimler) reddedilir.
"""
from __future__ import annotations

import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
FERHENG = ASSETS / "ferheng"

WORDLIST_OUT = FERHENG / "wordlist.txt.gz"


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def main() -> int:
    word_set: set[str] = set()

    # 1. entries.ndjson.gz headwords
    entries_count = 0
    with gzip.open(FERHENG / "entries.ndjson.gz", "rt", encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            head = normalize((e.get("normalized") or e.get("headword") or ""))
            if head:
                word_set.add(head)
                entries_count += 1
    print(f"From entries.ndjson:    +{entries_count:,} (set size: {len(word_set):,})")

    # 2. Legacy daily wordlists (Wordle answers + allowed guesses + kurdish dict)
    for path in [
        ASSETS / "answers.txt",
        ASSETS / "allowed_guesses.txt",
        ASSETS / "kurdish_dictionary.txt",
    ]:
        if not path.exists():
            continue
        before = len(word_set)
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                w = normalize(line)
                if w:
                    word_set.add(w)
        added = len(word_set) - before
        print(f"From {path.name:<22} +{added:,} (set size: {len(word_set):,})")

    print(f"\nFinal canonical wordlist: {len(word_set):,} words")
    print(f"(was 1,572,503 Hunspell forms)")

    # Write back as gzip, sorted
    text = "\n".join(sorted(word_set)) + "\n"
    with gzip.open(WORDLIST_OUT, "wt", encoding="utf-8") as f:
        f.write(text)

    size_mb = WORDLIST_OUT.stat().st_size / 1024 / 1024
    print(f"Wrote {WORDLIST_OUT} ({size_mb:.1f} MB)")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
