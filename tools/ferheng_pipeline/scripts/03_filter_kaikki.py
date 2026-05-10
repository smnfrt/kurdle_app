#!/usr/bin/env python3
"""Filter kaikki.org Kurdish JSONL to Kurmanji-only entries and project our schema.

The raw kaikki file contains Kurdish entries across multiple dialects (kmr=Kurmanji,
ckb=Sorani, etc.). We keep `lang_code == "kmr"` and project the fields we need.

Inputs:  raw/kaikki_kurdish.jsonl
Outputs: build/kaikki_kmr.jsonl  (one record per line, our schema)
         build/kaikki_kmr_stats.json
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

import orjson

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import (  # noqa: E402
    BUILD,
    RAW,
    ensure_dirs,
    is_valid_kurmanji,
    log,
    normalize_headword,
)


_INFLECTION_TAGS = {"form-of", "alt-of", "inflection-of", "abbreviation-of",
                    "synonym-of", "alternative-of"}

import re

# Gloss'lar "Nth-person ... of X" / "plural of X" / "alternative form of X"
# kalıbı içerir — saf gramatik metadata.
_GRAM_GLOSS_RE = re.compile(
    r"\b("
    r"(first|second|third)[- ]person|"
    r"singular|plural|"
    r"(past|present|future|imperative|infinitive|participle|imperfect|"
    r"indicative|subjunctive|conditional|optative|gerund|preterite)\b|"
    r"alternative (form|spelling) of|"
    r"\boblique form of\b|"
    r"feminine of|masculine of|"
    r"diminutive of|augmentative of|"
    r"abbreviation of|"
    r"reflexive of"
    r")",
    re.IGNORECASE,
)


def _is_inflection_sense(sense: dict) -> bool:
    """Returns True for senses that are pure grammatical metadata (not real defs).

    Detection layers:
      1. Tags contain any of the *-of markers.
      2. `form_of`/`alt_of` field is present.
      3. The gloss text matches grammatical-metadata regex.
    """
    tags = set(sense.get("tags") or ())
    if tags & _INFLECTION_TAGS:
        return True
    if sense.get("form_of") or sense.get("alt_of"):
        return True
    glosses = sense.get("glosses") or sense.get("raw_glosses") or []
    for g in glosses:
        if _GRAM_GLOSS_RE.search(g):
            return True
    return False


def project(rec: dict) -> dict | None:
    word = rec.get("word")
    if not word:
        return None
    head = normalize_headword(word)
    if not is_valid_kurmanji(head):
        return None

    pos = rec.get("pos")
    # Kaikki "Northern Kurdish" dump'ı *İngilizce* Wiktionary'den geliyor —
    # gloss'lar İngilizce, etimoloji İngilizce, örnekler genelde İngilizce.
    # Kullanıcı tercihi: tüm İngilizce içeriği at, yalnızca legacy TR kalsın.
    # Bu sebeple definitions_kmr boş bırakılır; entry'ler sadece metadata
    # (pos, ipa, related, categories) için faydalıdır ve legacy TR ile
    # eşleşmezlerse 04_merge_meanings'te düşürülür.
    kmr_defs: list[dict] = []

    sounds = rec.get("sounds") or []
    ipa = ""
    for s in sounds:
        if s.get("ipa"):
            ipa = s["ipa"]
            break

    categories_raw = rec.get("categories") or []
    cat_names = []
    for c in categories_raw:
        name = c.get("name") if isinstance(c, dict) else (c if isinstance(c, str) else "")
        if name:
            cat_names.append(name)

    forms = rec.get("forms") or []
    form_words = sorted({
        normalize_headword(f.get("form", ""))
        for f in forms
        if f.get("form") and is_valid_kurmanji(normalize_headword(f.get("form", "")))
    })
    related = [w for w in form_words if w and w != head][:10]

    return {
        "headword": word,
        "normalized": head,
        "pos": [pos] if pos else [],
        "ipa": ipa,
        "definitions_kmr": kmr_defs,
        "definitions_tr": [],  # filled in by 04_merge_meanings.py
        "etymology": "",  # kaikki etimolojisi İngilizce — atıldı

        "categories_raw": cat_names,
        "related": related,
        "source": "wiktionary",
        "source_url": f"https://ku.wiktionary.org/wiki/{word.replace(' ', '_')}",
    }


def main() -> int:
    ensure_dirs()
    inp = RAW / "kaikki_kurdish.jsonl"
    if not inp.exists():
        log(f"ERROR: missing {inp}. Run 'make fetch' first.")
        return 1

    out = BUILD / "kaikki_kmr.jsonl"
    total = 0
    kept = 0
    by_pos: Counter[str] = Counter()
    skipped_lang: Counter[str] = Counter()

    with inp.open("rb") as src, out.open("wb") as dst:
        for line in src:
            line = line.strip()
            if not line:
                continue
            total += 1
            try:
                rec = orjson.loads(line)
            except Exception:
                continue

            lang = (rec.get("lang_code") or rec.get("lang") or "").lower()
            # Reject Sorani / Central Kurdish explicitly. The kaikki "Northern Kurdish"
            # dump is pre-filtered to Kurmanji, but we still guard against drift.
            if lang in ("ckb", "central kurdish", "sorani"):
                skipped_lang[lang] += 1
                continue

            projected = project(rec)
            if projected is None:
                continue

            kept += 1
            by_pos[projected["pos"][0] if projected["pos"] else "_unknown"] += 1
            dst.write(orjson.dumps(projected) + b"\n")

    stats = {
        "total_input_records": total,
        "kept_kmr_records": kept,
        "by_pos": dict(by_pos.most_common()),
        "skipped_by_lang": dict(skipped_lang.most_common(10)),
    }
    (BUILD / "kaikki_kmr_stats.json").write_text(
        orjson.dumps(stats, option=orjson.OPT_INDENT_2).decode("utf-8"), encoding="utf-8"
    )
    log(f"input: {total:,} records → kept: {kept:,} kmr records")
    log(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
