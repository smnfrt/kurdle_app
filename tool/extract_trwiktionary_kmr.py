#!/usr/bin/env python3
"""tr.wiktionary.org dump'ından Kurmancî çevirileri çıkar.

tr.wiktionary, Türkçe headword'ler altında "Çeviriler" section'ında diğer
dillere çevirileri listeler. Kurmancî için pattern:

  * Kürtçe: {{ç|ku|<kurdish_word>}}

veya

  * Kurmancca: {{ç|kmr|<kurdish_word>}}

Bu script tüm dump'ı stream ile gezer, TR headword → KMR çeviri haritası
çıkarır, sonra INVERT eder: KMR_word → TR_headword.

Output: tool/trwiktionary_kmr_to_tr.json
        {KMR_normalized: "TR_headword"}
"""
from __future__ import annotations

import bz2
import json
import re
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
DUMP = ROOT / "tools" / "ferheng_pipeline" / "raw" / "trwiktionary.xml.bz2"
OUT = ROOT / "tool" / "trwiktionary_kmr_to_tr.json"

MW_NS = "{http://www.mediawiki.org/xml/export-0.11/}"

# tr.wiktionary KMR çeviri pattern'i — birkaç varyasyon yakala
# * Kürtçe: {{ç|ku|<word>}}
# * Kurmancca: {{ç|kmr|<word>}}
# * Kürtçe (Kurmancca): {{ç|ku|<word>}}
KMR_LINE_RE = re.compile(
    r"^\s*\*+\s*(?:Kürtçe|Kurmanc(?:ca|i))[^:]*:\s*(.+)$",
    re.MULTILINE | re.IGNORECASE,
)
CEVIRI_TEMPLATE_RE = re.compile(
    r"\{\{\s*ç\s*\|\s*(?:ku|kmr)\s*\|\s*([^|}]+)", re.IGNORECASE
)


KURMANJI_LETTERS = set("ABCÇDEÊFGHIÎJKLMNOPQRSŞTUÛVWXYZ'’-")


def normalize(s: str) -> str:
    s = re.sub(r"\s+", " ", s.strip().upper())
    return s


def is_valid_kurmanji(head: str) -> bool:
    if not head:
        return False
    chars = set(head)
    if not chars & KURMANJI_LETTERS:
        return False
    return True


def extract_kmr_translations(wikitext: str) -> list[str]:
    """Wikitext'ten {{ç|ku|<word>}} patternlerini çıkar."""
    out: list[str] = []
    for line_match in KMR_LINE_RE.finditer(wikitext):
        rest = line_match.group(1)
        for cm in CEVIRI_TEMPLATE_RE.finditer(rest):
            word = cm.group(1).strip()
            if word:
                out.append(word)
    return out


def main():
    if not DUMP.exists():
        print(f"ERROR: dump yok: {DUMP}", file=sys.stderr)
        return 1

    print(f"Streaming {DUMP}...", file=sys.stderr)

    # KMR_normalized → first TR headword seen (priority by alphabet)
    kmr_to_tr: dict[str, str] = {}
    page_count = 0
    tr_with_kmr = 0
    pairs = 0

    with bz2.open(DUMP, "rb") as f:
        context = ET.iterparse(f, events=("end",))
        title = None
        text = None
        ns = None
        for _, elem in context:
            tag = elem.tag.replace(MW_NS, "")
            if tag == "title":
                title = (elem.text or "").strip()
            elif tag == "ns":
                ns = elem.text
            elif tag == "text":
                text = elem.text or ""
            elif tag == "page":
                page_count += 1
                if ns == "0" and title and text:
                    kmr_words = extract_kmr_translations(text)
                    if kmr_words:
                        tr_with_kmr += 1
                        for kw in kmr_words:
                            kw_norm = normalize(kw)
                            if not is_valid_kurmanji(kw_norm):
                                continue
                            # İlk gördüğümüz TR'yi sakla
                            if kw_norm not in kmr_to_tr:
                                kmr_to_tr[kw_norm] = title.strip()
                                pairs += 1
                if page_count % 50000 == 0:
                    print(
                        f"  {page_count:,} page, {tr_with_kmr:,} TR with KMR, "
                        f"{pairs:,} pairs",
                        file=sys.stderr,
                    )
                title = None
                text = None
                ns = None
                elem.clear()

    print(
        f"\nTotal: {page_count:,} page, {tr_with_kmr:,} TR with KMR, "
        f"{pairs:,} unique KMR→TR pairs",
        file=sys.stderr,
    )

    sorted_map = dict(sorted(kmr_to_tr.items()))
    OUT.write_text(
        json.dumps(sorted_map, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {OUT} ({len(sorted_map):,} entries)", file=sys.stderr)

    print("\nFirst 10 samples:", file=sys.stderr)
    for k, v in list(sorted_map.items())[:10]:
        print(f"  {k:<20} → {v}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main() or 0)
