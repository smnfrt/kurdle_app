#!/usr/bin/env python3
"""ku.wiktionary.org dump'ından Türkçe çeviri linklerini çıkar.

Wiktionary entry'lerinin "Werger" (Translations) section'ında
{{Z|tr}}: {{W+|tr|<turkish_word>}} formatında TR karşılıklar var.
Bu script tüm dump'ı streaming şekilde gezer, headword + TR
çevirileri çıkarır.

Çıktı: build/wiktionary_tr_translations.json
       {entry_normalized: "tr_word_1, tr_word_2"}

Kullanım:
  python3 tool/extract_wiktionary_tr_translations.py
"""
from __future__ import annotations

import bz2
import json
import re
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
DUMP = ROOT / "tools" / "ferheng_pipeline" / "raw" / "kuwiktionary.xml.bz2"
OUT = ROOT / "tool" / "wiktionary_tr_translations.json"

MW_NS = "{http://www.mediawiki.org/xml/export-0.11/}"

# Z templatesı sadece Türkçe satırlarını yakala
TR_LINE_RE = re.compile(r"\{\{\s*Z\s*\|\s*tr\s*\}\}\s*:?\s*(.+?)$", re.IGNORECASE)
# W+ / W- template'inden TR kelime çıkar
W_TEMPLATE_RE = re.compile(
    r"\{\{\s*W[+\-]?\s*\|\s*tr\s*\|\s*([^|}]+)", re.IGNORECASE
)

# Headword normalize — entries.ndjson ile aynı
KURMANJI_LETTERS = set("ABCÇDEÊFGHIÎJKLMNOPQRSŞTUÛVWXYZ'’-")


def normalize(s: str) -> str:
    s = s.strip()
    # Unicode normalize Kurmancî karakterler için
    s = s.upper()
    s = re.sub(r"\s+", " ", s)
    return s


def is_valid_kurmanji(head: str) -> bool:
    if not head:
        return False
    # En az bir Kurmancî harfi olmalı, sadece ASCII boşluk/tire değil
    chars = set(head)
    if not chars & KURMANJI_LETTERS:
        return False
    return True


def extract_tr_translations(wikitext: str) -> list[str]:
    """Werger block içindeki {{Z|tr}}: {{W+|tr|<word>}} patternlerini bul."""
    out: list[str] = []
    in_werger = False
    for line in wikitext.split("\n"):
        lo = line.lower()
        if "werger-ser" in lo:
            in_werger = True
            continue
        if "werger-bin" in lo:
            in_werger = False
            continue
        if not in_werger:
            continue
        # Sadece "* {{Z|tr}}: ..." satırlarına bak
        tr_match = TR_LINE_RE.search(line)
        if not tr_match:
            continue
        rest = tr_match.group(1)
        for w_match in W_TEMPLATE_RE.finditer(rest):
            word = w_match.group(1).strip()
            if word:
                out.append(word)
    return out


def main():
    if not DUMP.exists():
        print(f"ERROR: dump yok: {DUMP}", file=sys.stderr)
        return 1

    print(f"Reading {DUMP} (streaming)...", file=sys.stderr)

    by_head: dict[str, list[str]] = {}
    page_count = 0
    hit_count = 0

    with bz2.open(DUMP, "rb") as f:
        # iterparse for memory efficiency on 83MB compressed dump
        context = ET.iterparse(f, events=("start", "end"))
        title = None
        text = None
        ns = None
        for event, elem in context:
            tag = elem.tag.replace(MW_NS, "")
            if event == "start":
                continue
            if tag == "title":
                title = (elem.text or "").strip()
            elif tag == "ns":
                ns = elem.text
            elif tag == "text":
                text = elem.text or ""
            elif tag == "page":
                page_count += 1
                if ns == "0" and title and text:  # ana namespace
                    head_norm = normalize(title)
                    if is_valid_kurmanji(head_norm):
                        translations = extract_tr_translations(text)
                        if translations:
                            # Aynı title birden fazla çıkıyorsa yine de tek slot
                            by_head[head_norm] = translations
                            hit_count += 1
                if page_count % 20000 == 0:
                    print(
                        f"  {page_count:,} page, {hit_count:,} with TR translations",
                        file=sys.stderr,
                    )
                # Bellek temizle
                title = None
                text = None
                ns = None
                elem.clear()

    print(
        f"\nTotal pages: {page_count:,}, with TR translations: {hit_count:,}",
        file=sys.stderr,
    )

    # Tek string'e birleştir (çoğul çeviri varsa virgülle)
    result = {head: ", ".join(words) for head, words in sorted(by_head.items())}

    OUT.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    print(f"Wrote {OUT} ({len(result):,} entries)", file=sys.stderr)

    # Sample
    print(f"\nFirst 10 samples:", file=sys.stderr)
    for k, v in list(result.items())[:10]:
        print(f"  {k:<20} → {v}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
