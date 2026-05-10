#!/usr/bin/env python3
"""Emit final artifacts for app bundle and Firestore ingest.

Outputs (build/out/):
  - wordlist.txt.gz          (gzipped, sorted, NFC + uppercase, one form per line)
  - ferheng_entries.ndjson   (Firestore-ready document-per-line schema)
  - legacy_meanings.json     (copied from build/, used as offline fallback)
  - ferheng_qa.csv           (head, has_kmr, has_tr, has_examples, has_categ, source)
  - meta.json                (totals, version, timestamps, attribution)
"""
from __future__ import annotations

import csv
import datetime as dt
import gzip
import sys
from pathlib import Path

import orjson

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import (  # noqa: E402
    BUILD,
    OUT,
    ROOT,
    ensure_dirs,
    log,
)

VERSION = "1.0.0"
DIALECT = "kmr"


def _prefixes(head: str, max_len: int = 4) -> list[str]:
    n = min(max_len, len(head))
    return [head[:i] for i in range(1, n + 1)]


def to_firestore_doc(rec: dict) -> dict:
    head = rec["normalized"]
    now = dt.datetime.utcnow().isoformat() + "Z"
    return {
        "headword": rec.get("headword", head),
        "normalized": head,
        "prefixes": _prefixes(head),
        "dialect": DIALECT,
        "pos": rec.get("pos") or [],
        "ipa": rec.get("ipa", ""),
        "definitions": {
            "kmr": rec.get("definitions_kmr") or [],
            "tr": rec.get("definitions_tr") or [],
        },
        "etymology": rec.get("etymology", ""),
        "categories": rec.get("categories") or [],
        "related": rec.get("related") or [],
        "audioUrl": None,
        "source": rec.get("source", "wiktionary"),
        "sourceUrl": rec.get("source_url", ""),
        "license": "CC BY-SA 4.0",
        "version": 1,
        "createdAt": now,
        "updatedAt": now,
    }


def main() -> int:
    ensure_dirs()
    OUT.mkdir(parents=True, exist_ok=True)

    cat_path = BUILD / "categorized_entries.jsonl"
    if not cat_path.exists():
        log(f"ERROR: missing {cat_path}. Run 'make categorize' first.")
        return 1

    surf_path = BUILD / "kmr_surface_forms.txt"
    if not surf_path.exists():
        log(f"ERROR: missing {surf_path}. Run 'make unmunch' first.")
        return 1

    # 1) wordlist.txt.gz — union of (surface forms ∪ entry headwords ∪ curated legacy).
    # Curated assets/kurdish_dictionary.txt: Hunspell henüz tüm Kurmancî
    # kelimelerini kapsamıyor; 516-kelimelik curated listeyi de union'a katmak
    # mevcut Scrabble doğrulama davranışıyla geriye dönük uyumluluk sağlar.
    surf = set(surf_path.read_text(encoding="utf-8").splitlines())
    surf.discard("")
    log(f"surface forms: {len(surf):,}")

    legacy_dict_path = ROOT / ".." / ".." / "assets" / "kurdish_dictionary.txt"
    if legacy_dict_path.exists():
        from _common import normalize_headword, is_valid_kurmanji  # local import OK
        before = len(surf)
        for line in legacy_dict_path.read_text(encoding="utf-8").splitlines():
            n = normalize_headword(line)
            if n and is_valid_kurmanji(n):
                surf.add(n)
        log(f"merged curated kurdish_dictionary.txt: +{len(surf) - before:,} new forms")

    headwords: set[str] = set()
    entries_doc: list[dict] = []
    letter_counts: dict[str, int] = {}
    category_counts: dict[str, int] = {}

    with cat_path.open("rb") as src:
        for line in src:
            rec = orjson.loads(line)
            head = rec["normalized"]
            headwords.add(head)
            doc = to_firestore_doc(rec)
            entries_doc.append(doc)
            first = head[:1]
            letter_counts[first] = letter_counts.get(first, 0) + 1
            for c in doc["categories"]:
                category_counts[c] = category_counts.get(c, 0) + 1

    union = sorted(surf | headwords)
    log(f"wordlist union: {len(union):,}")

    wl_path = OUT / "wordlist.txt.gz"
    with gzip.open(wl_path, "wb", compresslevel=9) as gz:
        gz.write(("\n".join(union) + "\n").encode("utf-8"))

    # 2) ferheng_entries.ndjson — one document per line (Firestore ingest için).
    nd_path = OUT / "ferheng_entries.ndjson"
    with nd_path.open("wb") as f:
        for doc in entries_doc:
            f.write(orjson.dumps(doc) + b"\n")

    # 2b) entries.ndjson.gz — uygulama içine gömülecek bundle (offline lookup).
    # Her satır JSON; client decompress edip in-memory map'e yükler.
    bundle_path = OUT / "entries.ndjson.gz"
    with gzip.open(bundle_path, "wb", compresslevel=9) as gz:
        for doc in entries_doc:
            gz.write(orjson.dumps(doc) + b"\n")

    # 3) legacy_meanings.json — copy from build/.
    legacy_src = BUILD / "legacy_meanings.json"
    legacy_dst = OUT / "legacy_meanings.json"
    legacy_dst.write_bytes(legacy_src.read_bytes())

    # 4) ferheng_qa.csv
    qa_path = OUT / "ferheng_qa.csv"
    with qa_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["headword", "pos", "has_kmr_def", "has_tr_def", "categories", "source"])
        for d in entries_doc:
            kmr = bool(d["definitions"]["kmr"])
            tr = bool(d["definitions"]["tr"])
            w.writerow([
                d["headword"],
                ";".join(d["pos"]),
                int(kmr),
                int(tr),
                ";".join(d["categories"]),
                d["source"],
            ])

    # 5) meta.json
    meta = {
        "version": VERSION,
        "dialect": DIALECT,
        "lastUpdatedAt": dt.datetime.utcnow().isoformat() + "Z",
        "totalEntries": len(entries_doc),
        "totalSurfaceForms": len(union),
        "letterCounts": letter_counts,
        "categoryCounts": category_counts,
        "ferhengEnabled": True,
        "attribution": {
            "kurdishHunspell": "https://github.com/sinaahmadi/KurdishHunspell (CC BY-SA 4.0)",
            "wiktionary": "https://kmr.wiktionary.org (CC BY-SA 4.0)",
        },
    }
    (OUT / "meta.json").write_text(
        orjson.dumps(meta, option=orjson.OPT_INDENT_2).decode("utf-8"),
        encoding="utf-8",
    )

    log("emitted artifacts:")
    log(f"  {wl_path} ({wl_path.stat().st_size:,} bytes gz)")
    log(f"  {nd_path} ({nd_path.stat().st_size:,} bytes)")
    log(f"  {legacy_dst} ({legacy_dst.stat().st_size:,} bytes)")
    log(f"  {qa_path}")
    log(f"  {OUT / 'meta.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
