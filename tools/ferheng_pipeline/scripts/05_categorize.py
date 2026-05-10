#!/usr/bin/env python3
"""Assign category tags to merged entries.

Strategy (per entry, in order):
  1. data/category_overrides.csv  — manual curation (highest priority)
  2. categories_raw → keyword map (Wîkîferheng category names)
  3. TR gloss keyword heuristics (fallback)

Outputs: build/categorized_entries.jsonl
         build/category_counts.json
"""
from __future__ import annotations

import csv
import sys
from collections import Counter
from pathlib import Path

import orjson

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import (  # noqa: E402
    BUILD,
    DATA,
    ensure_dirs,
    log,
    normalize_headword,
)

# Wîkîferheng / kaikki category-name → our category id
CATEGORY_NAME_MAP = {
    "Heywan": "animals", "Animals": "animals", "ku:Heywan": "animals",
    "Beden": "body", "Body parts": "body",
    "Malbat": "family", "Family": "family",
    "Xwarin": "food", "Food": "food",
    "Xweza": "nature", "Nature": "nature",
    "Dem": "time", "Time": "time",
    "Hejmar": "numbers", "Numbers": "numbers",
    "Reng": "colors", "Colors": "colors", "Colours": "colors",
    "Lêker": "verbs_common", "Verbs": "verbs_common",
    "Cil": "clothing", "Clothing": "clothing",
    "Mal": "home", "Home": "home",
    "Cîh": "places", "Places": "places",
    "Hest": "emotions", "Emotions": "emotions",
    "Pîşe": "professions", "Professions": "professions",
    "Ol": "religion_culture", "Religion": "religion_culture", "Çand": "religion_culture",
}

# Turkish-gloss keyword heuristics (lowercase substring match).
TR_KEYWORD_MAP: list[tuple[tuple[str, ...], str]] = [
    (("hayvan", "kuş", "balık", "köpek", "kedi"), "animals"),
    (("vücut", "el", "ayak", "göz", "kulak", "ağız", "kalp"), "body"),
    (("anne", "baba", "kardeş", "abla", "abi", "amca", "teyze", "aile", "akraba"), "family"),
    (("yemek", "ekmek", "süt", "et", "yumurta", "elma", "su"), "food"),
    (("ağaç", "dağ", "nehir", "deniz", "göl", "orman", "doğa", "rüzgâr"), "nature"),
    (("gün", "ay", "yıl", "saat", "dakika", "hafta", "sabah", "akşam"), "time"),
    (("bir", "iki", "üç", "dört", "beş", "altı", "yedi", "sekiz", "dokuz", "on"), "numbers"),
    (("renk", "kırmızı", "mavi", "yeşil", "sarı", "siyah", "beyaz"), "colors"),
    (("etmek", "olmak", "gitmek", "gelmek", "yapmak", "demek"), "verbs_common"),
    (("giysi", "elbise", "pantolon", "gömlek", "ayakkabı"), "clothing"),
    (("ev", "oda", "kapı", "pencere", "yatak"), "home"),
    (("şehir", "köy", "ülke", "yol", "sokak"), "places"),
    (("sevgi", "korku", "öfke", "üzüntü", "mutluluk"), "emotions"),
    (("öğretmen", "doktor", "mühendis", "çiftçi"), "professions"),
    (("din", "tanrı", "namaz", "kültür", "gelenek"), "religion_culture"),
]


def load_overrides() -> dict[str, list[str]]:
    path = DATA / "category_overrides.csv"
    out: dict[str, list[str]] = {}
    if not path.exists():
        return out
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            head = normalize_headword(row.get("headword", ""))
            cats = (row.get("categories") or "").split(";")
            cats = [c.strip() for c in cats if c.strip()]
            if head and cats:
                out[head] = cats
    return out


def categorize(rec: dict, overrides: dict[str, list[str]]) -> list[str]:
    head = rec["normalized"]
    # 1) override
    if head in overrides:
        return overrides[head]
    # 2) raw categories
    cats: list[str] = []
    for raw in rec.get("categories_raw") or []:
        for key, mapped in CATEGORY_NAME_MAP.items():
            if key.lower() in raw.lower():
                cats.append(mapped)
    if cats:
        return list(dict.fromkeys(cats))  # dedupe, preserve order
    # 3) TR gloss heuristic
    tr_glosses = " ".join(d.get("gloss", "") for d in rec.get("definitions_tr") or []).lower()
    if tr_glosses:
        for keywords, cat in TR_KEYWORD_MAP:
            if any(kw in tr_glosses for kw in keywords):
                return [cat]
    return []


def main() -> int:
    ensure_dirs()
    inp = BUILD / "merged_entries.jsonl"
    if not inp.exists():
        log(f"ERROR: missing {inp}. Run 'make merge' first.")
        return 1

    overrides = load_overrides()
    log(f"overrides loaded: {len(overrides):,}")

    out = BUILD / "categorized_entries.jsonl"
    counts: Counter[str] = Counter()
    with_cat = 0
    total = 0

    with inp.open("rb") as src, out.open("wb") as dst:
        for line in src:
            rec = orjson.loads(line)
            total += 1
            cats = categorize(rec, overrides)
            rec["categories"] = cats
            rec.pop("categories_raw", None)
            for c in cats:
                counts[c] += 1
            if cats:
                with_cat += 1
            dst.write(orjson.dumps(rec) + b"\n")

    summary = {
        "total_entries": total,
        "with_category": with_cat,
        "category_counts": dict(counts.most_common()),
    }
    (BUILD / "category_counts.json").write_text(
        orjson.dumps(summary, option=orjson.OPT_INDENT_2).decode("utf-8"),
        encoding="utf-8",
    )
    log(f"categorized {with_cat:,}/{total:,} entries ({100*with_cat//max(total,1)}%)")
    log(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
