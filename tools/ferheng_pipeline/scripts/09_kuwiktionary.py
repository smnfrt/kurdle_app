#!/usr/bin/env python3
"""Parse kuwiktionary XML dump → Kurmancî tanım çıkarımı.

Strateji:
  1. raw/kuwiktionary.xml.bz2 → bz2.open ile akış aç (~86MB sıkışık).
  2. xml.etree.iterparse ile her <page> elementini gez.
  3. ns=0 (makale) ve title valid Kurmancî kelimeyse:
     a. Wikitext'te `== Kurmancî ==` section'ını bul.
     b. Section içindeki tanım satırlarını (`# ...`) ayrıştır.
     c. Wikitext temizle (template, link, formatting).
  4. Çıktı: build/kuwiktionary_kmr.jsonl (kaikki ile aynı schema).

Çıktı şeması (kaikki ile uyumlu):
  {
    "headword": "av",
    "normalized": "AV",
    "pos": [],                          # ku.wiktionary'de POS section başlığı
    "ipa": "",
    "definitions_kmr": [{"gloss": "...", "examples": [...]}, ...],
    "definitions_tr": [],
    "etymology": "",                    # şimdilik atılır
    "categories_raw": [],
    "related": [],
    "source": "kuwiktionary",
    "source_url": "https://ku.wiktionary.org/wiki/{title}"
  }
"""
from __future__ import annotations

import bz2
import re
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

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

DUMP = RAW / "kuwiktionary.xml.bz2"

# MediaWiki XML namespace
MW_NS = {"mw": "http://www.mediawiki.org/xml/export-0.11/"}

# Section başlıkları — kuwiktionary'de en yaygın form `== {{ziman|ku}} ==`
# (template ile dil işaretlenir). Daha az yaygın: `== Kurmancî ==`,
# `== {{ziman|kmr}} ==`. Hepsini yakalamak için iki alternatif:
KMR_SECTION_RE = re.compile(
    r"(^|\n)\s*==\s*"
    r"(?:\{\{\s*ziman\s*\|\s*(?:ku|kmr)\s*\}\}|Kurmanc[îi])"
    r"\s*==\s*\n",
    re.MULTILINE,
)
NEXT_SECTION_RE = re.compile(r"\n\s*==[^=]", re.MULTILINE)

# Tanım satırı: `# ...` (sıralı liste işaretçisi). `##`, `#:` örnekler/yorumlar.
DEF_LINE_RE = re.compile(r"^#\s*([^*:#].*)$", re.MULTILINE)
EXAMPLE_LINE_RE = re.compile(r"^#:\s*(.*)$", re.MULTILINE)

# POS başlığı (3. seviye) — `=== Navdêr ===`, `=== Lêker ===` vb.
POS_SECTION_RE = re.compile(r"^===\s*([^=]+?)\s*===\s*$", re.MULTILINE)

# IPA: {{IPA|/.../}} veya {{IPA|kmr|/.../}}
IPA_RE = re.compile(r"\{\{IPA\|(?:[a-z]{2,3}\|)?/([^}|]+)/[^}]*\}\}")


def _clean_wikitext(s: str) -> str:
    """Wikitext'i okunaklı düz metne çevirir."""
    # Template'leri at: {{...}} (basit, iç içe için tek geçiş yetmez)
    for _ in range(3):  # iç içe için 3 geçiş
        s = re.sub(r"\{\{[^{}]*\}\}", "", s)
    # Wikilink: [[link|text]] → text, [[link]] → link
    s = re.sub(r"\[\[(?:[^|\]]+\|)?([^\]]+)\]\]", r"\1", s)
    # Dış link: [http://x text] → text
    s = re.sub(r"\[https?://[^\s\]]+\s+([^\]]+)\]", r"\1", s)
    s = re.sub(r"\[https?://[^\]]+\]", "", s)
    # HTML tag: <ref>...</ref>, <small>, <br/>, <nowiki>, etc.
    s = re.sub(r"<ref[^>]*>.*?</ref>", "", s, flags=re.DOTALL)
    s = re.sub(r"<ref[^/>]*/>", "", s)
    s = re.sub(r"</?[a-zA-Z][^>]*>", "", s)
    # Bold/italic: '''x''' → x, ''x'' → x
    s = re.sub(r"'{2,5}", "", s)
    # HTML entity
    s = s.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    # Çoklu boşluk → tek
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def _extract_kmr_section(text: str) -> str | None:
    m = KMR_SECTION_RE.search(text)
    if m is None:
        return None
    start = m.end()
    rest = text[start:]
    # Bir sonraki `==`-başlığı section sonunu işaretler.
    n = NEXT_SECTION_RE.search(rest)
    section = rest[: n.start()] if n else rest
    return section


def parse_page(title: str, text: str) -> dict | None:
    head = normalize_headword(title)
    if not is_valid_kurmanji(head):
        return None
    section = _extract_kmr_section(text)
    if not section:
        return None

    # POS başlıklarını topla
    pos_list = []
    for m in POS_SECTION_RE.finditer(section):
        pos_list.append(_clean_wikitext(m.group(1)))

    # IPA
    ipa = ""
    ipa_m = IPA_RE.search(section)
    if ipa_m:
        ipa = ipa_m.group(1)

    # Tanımları topla — `# ` ile başlayan ve `##`/`#:` olmayan satırlar.
    definitions: list[dict] = []
    for m in DEF_LINE_RE.finditer(section):
        gloss = _clean_wikitext(m.group(1))
        if gloss and len(gloss) > 1:
            definitions.append({"gloss": gloss, "examples": []})

    # Hiç tanım yoksa entry'i yutma — bilgi taşımıyor.
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
    ensure_dirs()
    if not DUMP.exists():
        log(f"ERROR: missing {DUMP}. Önce indir:")
        log(f"  curl -o {DUMP} https://dumps.wikimedia.org/kuwiktionary/latest/kuwiktionary-latest-pages-articles.xml.bz2")
        return 1

    out_path = BUILD / "kuwiktionary_kmr.jsonl"
    log(f"reading {DUMP}")
    log(f"writing {out_path}")

    total_pages = 0
    article_pages = 0
    kmr_entries = 0
    skipped_invalid = 0
    skipped_no_section = 0
    skipped_no_defs = 0

    def _local(tag: str) -> str:
        return tag.split("}", 1)[-1] if "}" in tag else tag

    def _find_local(parent, name: str):
        for c in parent:
            if _local(c.tag) == name:
                return c
        return None

    with bz2.open(DUMP, "rb") as src, out_path.open("wb") as dst:
        ctx = ET.iterparse(src, events=("end",))
        for event, elem in ctx:
            if _local(elem.tag) != "page":
                continue
            total_pages += 1

            ns_el = _find_local(elem, "ns")
            if ns_el is None or ns_el.text != "0":
                elem.clear()
                continue
            article_pages += 1

            title_el = _find_local(elem, "title")
            rev_el = _find_local(elem, "revision")
            text_el = _find_local(rev_el, "text") if rev_el is not None else None

            title = (title_el.text or "") if title_el is not None else ""
            text = (text_el.text or "") if text_el is not None else ""

            elem.clear()  # belleği serbest bırak

            if not title or not text:
                continue

            head = normalize_headword(title)
            if not is_valid_kurmanji(head):
                skipped_invalid += 1
                continue

            rec = parse_page(title, text)
            if rec is None:
                # parse_page içinde hangi sebeple None döndüğünü ayırt edelim
                if not _extract_kmr_section(text):
                    skipped_no_section += 1
                else:
                    skipped_no_defs += 1
                continue

            kmr_entries += 1
            dst.write(orjson.dumps(rec) + b"\n")

            if total_pages % 5000 == 0:
                log(f"  scanned {total_pages:,} pages, kept {kmr_entries:,}")

    log(f"toplam page: {total_pages:,}")
    log(f"  article (ns=0): {article_pages:,}")
    log(f"  invalid Kurmancî (atildi): {skipped_invalid:,}")
    log(f"  Kurmancî section yok: {skipped_no_section:,}")
    log(f"  tanım yok: {skipped_no_defs:,}")
    log(f"  KORUNAN entry: {kmr_entries:,}")
    log(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
