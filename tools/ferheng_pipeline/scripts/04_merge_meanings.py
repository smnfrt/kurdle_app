#!/usr/bin/env python3
"""Merge legacy hardcoded Turkish meanings into kaikki kmr records.

Sources:
  - build/kaikki_kmr.jsonl                              (KMR definitions, no TR)
  - ../../lib/services/kurdish_meanings.dart            (330 hand-curated TR meanings)

Policy: legacy 330 ALWAYS wins on TR gloss (curated > scraped). Kaikki wins on
KMR gloss (legacy has no KMR). Conflicts (both have TR) logged to conflicts.csv.

Outputs: build/merged_entries.jsonl
         build/conflicts.csv
         build/legacy_meanings.json   (offline fallback bundle)
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

import orjson

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import (  # noqa: E402
    BUILD,
    ROOT,
    ensure_dirs,
    is_valid_kurmanji,
    log,
    normalize_headword,
)

LEGACY_DART_PATH = ROOT / ".." / ".." / "lib" / "services" / "kurdish_meanings.dart"

# 'AV': 'su',   →  ('AV', 'su')
LEGACY_RE = re.compile(r"'([^']+)'\s*:\s*'((?:[^'\\]|\\.)*)'")


def parse_legacy_dart(text: str) -> dict[str, str]:
    """Extract { headword: turkish_gloss } from kurdish_meanings.dart."""
    out: dict[str, str] = {}
    for m in LEGACY_RE.finditer(text):
        head_raw, gloss_raw = m.group(1), m.group(2)
        head = normalize_headword(head_raw)
        gloss = gloss_raw.replace("\\'", "'").replace("\\\\", "\\")
        if not is_valid_kurmanji(head):
            continue
        # Last-write-wins on duplicates (Dart map literals can have dupes; warn).
        if head in out and out[head] != gloss:
            log(f"  legacy duplicate: {head} → {out[head]!r} vs {gloss!r}")
        out[head] = gloss
    return out


def main() -> int:
    ensure_dirs()
    legacy_path = LEGACY_DART_PATH.resolve()
    if not legacy_path.exists():
        log(f"ERROR: missing legacy file {legacy_path}")
        return 1

    legacy_text = legacy_path.read_text(encoding="utf-8")
    legacy = parse_legacy_dart(legacy_text)
    log(f"legacy entries: {len(legacy):,}")

    # Load kaikki entries indexed by normalized headword.
    kaikki_path = BUILD / "kaikki_kmr.jsonl"
    if not kaikki_path.exists():
        log(f"ERROR: missing {kaikki_path}. Run 'make filter' first.")
        return 1

    by_norm: dict[str, dict] = {}
    with kaikki_path.open("rb") as f:
        for line in f:
            rec = orjson.loads(line)
            by_norm[rec["normalized"]] = rec

    log(f"kaikki entries: {len(by_norm):,}")

    # ── kuwiktionary KMR verisini merge et ─────────────────────────
    # ku.wiktionary.org dump'ı parse edilmiş ise (09_kuwiktionary.py),
    # KMR tanımlarını mevcut entry'lere ekle veya yeni entry yarat.
    ku_path = BUILD / "kuwiktionary_kmr.jsonl"
    ku_added_kmr = 0
    ku_new_entries = 0
    if ku_path.exists():
        with ku_path.open("rb") as f:
            for line in f:
                ku = orjson.loads(line)
                head = ku["normalized"]
                rec = by_norm.get(head)
                if rec is None:
                    by_norm[head] = ku
                    ku_new_entries += 1
                else:
                    # KMR tanım yoksa ku'dan al; varsa zenginleştir (üzerine yazma).
                    if not (rec.get("definitions_kmr") or []):
                        rec["definitions_kmr"] = ku["definitions_kmr"]
                        rec["source"] = (rec.get("source") or "") + "+kuwiktionary"
                        if not rec.get("ipa") and ku.get("ipa"):
                            rec["ipa"] = ku["ipa"]
                        if not rec.get("pos") and ku.get("pos"):
                            rec["pos"] = ku["pos"]
                        ku_added_kmr += 1
        log(f"kuwiktionary: +{ku_new_entries:,} new entry, +{ku_added_kmr:,} KMR augmented")
    else:
        log(f"WARNING: {ku_path} yok — KMR tanımları eklenmedi.")

    # Merge legacy TR.
    conflicts: list[tuple[str, str, str]] = []  # (headword, kaikki_tr, legacy_tr)
    new_from_legacy = 0
    augmented = 0

    for head, tr_gloss in legacy.items():
        rec = by_norm.get(head)
        if rec is None:
            # Create a minimal new entry from legacy data alone.
            rec = {
                "headword": head,
                "normalized": head,
                "pos": [],
                "ipa": "",
                "definitions_kmr": [],
                "definitions_tr": [{"gloss": tr_gloss, "examples": []}],
                "etymology": "",
                "categories_raw": [],
                "related": [],
                "source": "legacy",
                "source_url": "",
            }
            by_norm[head] = rec
            new_from_legacy += 1
            continue

        # Augment with TR; if kaikki had any TR (rare), record conflict.
        existing_tr = rec.get("definitions_tr") or []
        if existing_tr:
            existing_first = existing_tr[0].get("gloss", "")
            if existing_first and existing_first != tr_gloss:
                conflicts.append((head, existing_first, tr_gloss))

        rec["definitions_tr"] = [{"gloss": tr_gloss, "examples": []}]
        rec["source"] = "wiktionary+legacy"
        augmented += 1

    log(f"new from legacy: {new_from_legacy:,}")
    log(f"augmented existing: {augmented:,}")
    log(f"conflicts: {len(conflicts):,}")

    # Anlamsız (hem KMR hem TR boş) entry'leri at — ingest'i kirletmesinler.
    before = len(by_norm)
    by_norm = {
        k: v for k, v in by_norm.items()
        if (v.get("definitions_kmr") or []) or (v.get("definitions_tr") or [])
    }
    log(f"dropped empty entries: {before - len(by_norm):,} → kept {len(by_norm):,}")

    # Write merged entries.
    out = BUILD / "merged_entries.jsonl"
    with out.open("wb") as f:
        for head in sorted(by_norm):
            f.write(orjson.dumps(by_norm[head]) + b"\n")

    # Conflict report.
    cpath = BUILD / "conflicts.csv"
    with cpath.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["headword", "kaikki_tr", "legacy_tr"])
        for row in conflicts:
            w.writerow(row)

    # Offline fallback bundle (only headwords with TR gloss, deterministic order).
    legacy_bundle = {
        "version": "1.0.0",
        "license": "CC BY-SA 4.0 + project-internal",
        "entries": {
            head: {"tr": legacy[head]} for head in sorted(legacy)
        },
    }
    (BUILD / "legacy_meanings.json").write_text(
        orjson.dumps(legacy_bundle, option=orjson.OPT_INDENT_2).decode("utf-8"),
        encoding="utf-8",
    )

    log(f"wrote {out} (total {len(by_norm):,} entries)")
    log(f"wrote {cpath}")
    log(f"wrote {BUILD / 'legacy_meanings.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
