#!/usr/bin/env python3
"""kuwiktionary.xml.bz2'yi GENİŞLETİLMİŞ tanım pattern'i ile parse et.

Mevcut 09_kuwiktionary.py sadece `# ` (MediaWiki list) syntax'ını
tanım olarak alıyor. Pek çok entry `1. ...`, `2. ...` decimal-dot
notation kullanıyor (örn: gêncatî, gencatî). Bu yüzden ~140k entry
kaçırılıyor.

Bu script:
- `# tanım`
- `1. tanım`, `2. tanım`, ... (sayı + nokta)
- `#: tanım` (standalone, sadece bu entry'nin tek tanımı varsa)

şablonlarının HEPSİNİ kabul eder.

Output: tool/kuwiktionary_v2_kmr.jsonl
        (same schema as build/kuwiktionary_kmr.jsonl)
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
OUT = ROOT / "tool" / "kuwiktionary_v2_kmr.jsonl"

MW_NS = "{http://www.mediawiki.org/xml/export-0.11/}"

KMR_SECTION_RE = re.compile(
    r"(^|\n)\s*==\s*"
    r"(?:\{\{\s*ziman\s*\|\s*(?:ku|kmr)\s*\}\}|Kurmanc[îi])"
    r"\s*==\s*\n",
    re.MULTILINE,
)
NEXT_SECTION_RE = re.compile(r"\n\s*==[^=]", re.MULTILINE)

# Tanım satırı pattern'leri (genişletilmiş):
#   # gloss        — klasik MediaWiki numbered list
#   1. gloss       — decimal-dot bullet (yaygın kuwiktionary biçimi)
#   #: gloss       — usually example but if only def, accept
DEF_LINE_PATTERNS = [
    re.compile(r"^#\s+([^*:#].+)$", re.MULTILINE),
    re.compile(r"^\d+\.\s+(.+)$", re.MULTILINE),
    re.compile(r"^#:\s+(.+)$", re.MULTILINE),
]

POS_SECTION_RE = re.compile(r"^===\s*([^=]+?)\s*===\s*$", re.MULTILINE)
IPA_RE = re.compile(r"\{\{IPA\|(?:[a-z]{2,3}\|)?/([^}|]+)/[^}]*\}\}")

KURMANJI_LETTERS = set("ABCÇDEÊFGHIÎJKLMNOPQRSŞTUÛVWXYZ'’-")


def normalize(s: str) -> str:
    s = re.sub(r"\s+", " ", s.upper().strip())
    return s


def is_valid_kurmanji(head: str) -> bool:
    if not head:
        return False
    chars = set(head)
    if not chars & KURMANJI_LETTERS:
        return False
    return True


def _clean_wikitext(s: str) -> str:
    for _ in range(3):
        s = re.sub(r"\{\{[^{}]*\}\}", "", s)
    s = re.sub(r"\[\[(?:[^|\]]+\|)?([^\]]+)\]\]", r"\1", s)
    s = re.sub(r"\[https?://[^\s\]]+\s+([^\]]+)\]", r"\1", s)
    s = re.sub(r"\[https?://[^\]]+\]", "", s)
    s = re.sub(r"<ref[^>]*>.*?</ref>", "", s, flags=re.DOTALL)
    s = re.sub(r"<ref[^/>]*/>", "", s)
    s = re.sub(r"</?[a-zA-Z][^>]*>", "", s)
    s = re.sub(r"'{2,5}", "", s)
    s = s.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def _extract_kmr_section(text: str) -> str | None:
    m = KMR_SECTION_RE.search(text)
    if m is None:
        return None
    start = m.end()
    rest = text[start:]
    n = NEXT_SECTION_RE.search(rest)
    return rest[: n.start()] if n else rest


def parse_page(title: str, text: str) -> dict | None:
    head = normalize(title)
    if not is_valid_kurmanji(head):
        return None
    section = _extract_kmr_section(text)
    if not section:
        return None

    pos_list = []
    for m in POS_SECTION_RE.finditer(section):
        pos_list.append(_clean_wikitext(m.group(1)))

    ipa = ""
    ipa_m = IPA_RE.search(section)
    if ipa_m:
        ipa = ipa_m.group(1)

    # Collect definitions via EXTENDED patterns
    seen_glosses = set()
    definitions: list[dict] = []
    for pattern in DEF_LINE_PATTERNS:
        for m in pattern.finditer(section):
            gloss = _clean_wikitext(m.group(1))
            if not gloss or len(gloss) <= 1:
                continue
            # Skip duplicates
            if gloss in seen_glosses:
                continue
            seen_glosses.add(gloss)
            definitions.append({"gloss": gloss, "examples": []})

    if not definitions:
        return None

    return {
        "headword": title,
        "normalized": head,
        "pos": pos_list[:3] if pos_list else [],
        "ipa": ipa,
        "definitions_kmr": definitions,
        "definitions_tr": [],
        "etymology": "",
        "categories_raw": [],
        "related": [],
        "source": "kuwiktionary",
        "source_url": f"https://ku.wiktionary.org/wiki/{title.replace(' ', '_')}",
    }


def main() -> int:
    if not DUMP.exists():
        print(f"ERROR: dump yok: {DUMP}", file=sys.stderr)
        return 1

    total = 0
    article_pages = 0
    kept = 0
    skipped_invalid = 0
    skipped_no_section = 0
    skipped_no_defs = 0

    with bz2.open(DUMP, "rb") as src, OUT.open("w", encoding="utf-8") as dst:
        ctx = ET.iterparse(src, events=("end",))
        title = ns = text = None
        for _, elem in ctx:
            tag = elem.tag.replace(MW_NS, "")
            if tag == "title":
                title = (elem.text or "").strip()
            elif tag == "ns":
                ns = elem.text
            elif tag == "text":
                text = elem.text or ""
            elif tag == "page":
                total += 1
                if ns == "0" and title and text:
                    article_pages += 1
                    head = normalize(title)
                    if not is_valid_kurmanji(head):
                        skipped_invalid += 1
                    else:
                        rec = parse_page(title, text)
                        if rec is None:
                            if not _extract_kmr_section(text):
                                skipped_no_section += 1
                            else:
                                skipped_no_defs += 1
                        else:
                            kept += 1
                            dst.write(json.dumps(rec, ensure_ascii=False) + "\n")
                title = ns = text = None
                elem.clear()
                if total % 100000 == 0:
                    print(f"  scan {total:,} pages, kept {kept:,}", file=sys.stderr)

    print(f"\nTotal pages:               {total:,}", file=sys.stderr)
    print(f"  article (ns=0):          {article_pages:,}", file=sys.stderr)
    print(f"  invalid Kurmancî title:  {skipped_invalid:,}", file=sys.stderr)
    print(f"  no Kurmancî section:     {skipped_no_section:,}", file=sys.stderr)
    print(f"  no defs (after extend):  {skipped_no_defs:,}", file=sys.stderr)
    print(f"  KEPT (entries written):  {kept:,}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
