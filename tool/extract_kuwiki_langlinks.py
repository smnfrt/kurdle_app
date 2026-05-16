#!/usr/bin/env python3
"""KMR Wikipedia article başlıklarından TR karşılıklarını çıkar.

Wikidata-bağlantılı kuwiki article'larının TR Wikipedia karşılıklarını
langlinks tablosundan alır. Output: KMR_normalized → TR_title (TR
Wikipedia başlığı, çoğu zaman ortak isim olarak yararlı).

İki SQL dump kullanılır:
  - kuwiki-page.sql.gz       (page_id → KMR title)
  - kuwiki-langlinks.sql.gz  (page_id → (lang, target_title))

JOIN edip TR lang'lerini filtreler.

Kullanım: python3 tool/extract_kuwiki_langlinks.py
"""
from __future__ import annotations

import gzip
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "tools" / "ferheng_pipeline" / "raw"
OUT = ROOT / "tool" / "kuwiki_langlinks_kmr_to_tr.json"

PAGE_DUMP = RAW / "kuwiki-page.sql.gz"
LANGLINKS_DUMP = RAW / "kuwiki-langlinks.sql.gz"

# MySQL string escape — \' içinde ', \\ içinde \\
# Tek tırnaklı string'leri match etmek için pattern:
STRING_RE = r"'((?:[^'\\]|\\.)*)'"


def unescape(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n == "'":
                out.append("'")
            elif n == "\\":
                out.append("\\")
            elif n == '"':
                out.append('"')
            elif n == "n":
                out.append("\n")
            elif n == "r":
                out.append("\r")
            elif n == "0":
                out.append("\0")
            else:
                out.append(n)
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def stream_insert_rows(path: Path):
    """SQL dump'tan INSERT VALUES tuple'larını stream et."""
    insert_re = re.compile(r"INSERT INTO `\w+` VALUES (.+);", re.IGNORECASE)
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = insert_re.search(line)
            if not m:
                continue
            payload = m.group(1)
            # Split into tuples — basic but careful for nested commas in strings
            yield from _split_tuples(payload)


def _split_tuples(payload: str):
    """`(a,'b',c),(...)` → list of tuple strings (content within parens)."""
    depth = 0
    in_string = False
    buf = []
    for c in payload:
        if in_string:
            buf.append(c)
            if c == "\\":
                # Next char escaped — let buffer capture it
                continue
            if c == "'":
                in_string = False
        else:
            if c == "'":
                in_string = True
                buf.append(c)
            elif c == "(":
                if depth == 0:
                    buf = []
                else:
                    buf.append(c)
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    yield "".join(buf)
                else:
                    buf.append(c)
            else:
                buf.append(c)


def parse_tuple(s: str) -> list:
    """SQL VALUES tuple içeriğini split et."""
    fields = []
    buf = []
    in_string = False
    i = 0
    while i < len(s):
        c = s[i]
        if in_string:
            if c == "\\" and i + 1 < len(s):
                buf.append(c)
                buf.append(s[i + 1])
                i += 2
                continue
            if c == "'":
                in_string = False
                buf.append(c)
            else:
                buf.append(c)
        else:
            if c == "'":
                in_string = True
                buf.append(c)
            elif c == ",":
                fields.append("".join(buf).strip())
                buf = []
            else:
                buf.append(c)
        i += 1
    if buf:
        fields.append("".join(buf).strip())
    return fields


def main() -> int:
    if not PAGE_DUMP.exists() or not LANGLINKS_DUMP.exists():
        print("ERROR: dumps missing", file=sys.stderr)
        return 1

    # Phase 1: page_id → page_title (only ns=0)
    print("Parsing page.sql.gz...", file=sys.stderr)
    page_id_to_title: dict[int, str] = {}
    row_count = 0
    for tuple_str in stream_insert_rows(PAGE_DUMP):
        fields = parse_tuple(tuple_str)
        if len(fields) < 3:
            continue
        try:
            page_id = int(fields[0])
            page_ns = int(fields[1])
            if page_ns != 0:
                continue
            title_field = fields[2]
            if not title_field.startswith("'") or not title_field.endswith("'"):
                continue
            title = unescape(title_field[1:-1])
            # MediaWiki uses underscores for spaces
            title = title.replace("_", " ")
            page_id_to_title[page_id] = title
            row_count += 1
        except (ValueError, IndexError):
            continue
    print(f"  Loaded {len(page_id_to_title):,} ns=0 pages", file=sys.stderr)

    # Phase 2: langlinks → filter to 'tr'
    print("Parsing langlinks.sql.gz...", file=sys.stderr)
    kmr_to_tr: dict[str, str] = {}
    hits = 0
    for tuple_str in stream_insert_rows(LANGLINKS_DUMP):
        fields = parse_tuple(tuple_str)
        if len(fields) < 3:
            continue
        try:
            ll_from = int(fields[0])
            lang_field = fields[1]
            if not lang_field.startswith("'") or not lang_field.endswith("'"):
                continue
            lang = unescape(lang_field[1:-1])
            if lang != "tr":
                continue
            title_field = fields[2]
            if not title_field.startswith("'") or not title_field.endswith("'"):
                continue
            tr_title = unescape(title_field[1:-1])
            kmr_title = page_id_to_title.get(ll_from)
            if not kmr_title:
                continue
            kmr_norm = re.sub(r"\s+", " ", kmr_title.upper().strip())
            tr_clean = tr_title.replace("_", " ").strip()
            if kmr_norm and tr_clean and kmr_norm not in kmr_to_tr:
                kmr_to_tr[kmr_norm] = tr_clean
                hits += 1
        except (ValueError, IndexError):
            continue
    print(f"  Found {hits:,} kuwiki articles with TR Wikipedia link", file=sys.stderr)

    sorted_map = dict(sorted(kmr_to_tr.items()))
    OUT.write_text(
        json.dumps(sorted_map, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {OUT} ({len(sorted_map):,} entries)", file=sys.stderr)

    print("\nFirst 15 samples:", file=sys.stderr)
    for k, v in list(sorted_map.items())[:15]:
        print(f"  {k:<25} → {v}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
