#!/usr/bin/env python3
"""Ferheng coverage audit — kaç kelime hangi kategoriye düşüyor?

Sorulan: kullanıcı 'oyunda kabul edilen her kelimenin sözlükte anlam
içermesini' istiyor. Bu script gerçek veri üzerinde gap'i ölçer:

1. Entry kalitesi: entries.ndjson içinde kaç entry'de TR/KMR boş?
2. Wordlist coverage: wordlist.txt'deki kelimelerden kaçı entry'lerde
   doğrudan veya related/override/legacy ile karşılanıyor?
3. Inflection-stripping gerektiren residual: hangileri direkt eşleşmiyor
   ve FerhengService'in 70-suffix algoritması ile çözülmeye muhtaç?

Kullanım:
  python3 tool/ferheng_audit.py
"""
import gzip
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "ferheng"


def load_entries():
    """entries.ndjson.gz: {normalized: entry_dict}"""
    by_id = {}
    related_index = {}  # related_word -> base_word
    with gzip.open(ASSETS / "entries.ndjson.gz", "rt", encoding="utf-8") as f:
        for line in f:
            entry = json.loads(line)
            wid = entry.get("normalized", "").upper()
            if not wid:
                continue
            by_id[wid] = entry
            for rel in entry.get("related", []) or []:
                rel_id = (rel.get("word") if isinstance(rel, dict) else str(rel)).upper()
                if rel_id:
                    related_index.setdefault(rel_id, wid)
    return by_id, related_index


def load_wordlist():
    forms = set()
    with gzip.open(ASSETS / "wordlist.txt.gz", "rt", encoding="utf-8") as f:
        for line in f:
            w = line.strip().upper()
            if w:
                forms.add(w)
    return forms


def load_tr_overrides():
    with open(ASSETS / "tr_meaning_overrides.json", encoding="utf-8") as f:
        data = json.load(f)
    return {k.upper(): v for k, v in (data.get("entries") or {}).items()}


def load_legacy():
    with open(ASSETS / "legacy_meanings.json", encoding="utf-8") as f:
        data = json.load(f)
    raw = data.get("entries", data)
    return {k.upper(): v for k, v in raw.items()}


def main():
    print("Loading datasets...")
    entries, related_idx = load_entries()
    wordlist = load_wordlist()
    tr_overrides = load_tr_overrides()
    legacy = load_legacy()

    print(f"  entries.ndjson:       {len(entries):>9,} entries")
    print(f"  related index:        {len(related_idx):>9,} extra forms")
    print(f"  wordlist.txt:         {len(wordlist):>9,} playable surface forms")
    print(f"  tr_meaning_overrides: {len(tr_overrides):>9,} TR entries")
    print(f"  legacy_meanings:      {len(legacy):>9,} curated TR entries")
    print()

    # ── A. Entry quality breakdown ─────────────────────────────────
    print("=" * 70)
    print("A. SÖZLÜK ENTRY KALİTESİ (entries.ndjson içinde)")
    print("=" * 70)

    quality = Counter()
    no_def_examples = []
    only_kmr_examples = []
    only_tr_examples = []

    for wid, entry in entries.items():
        defs = entry.get("definitions", {})
        kmr = [d for d in (defs.get("kmr") or []) if (d.get("gloss") or "").strip()]
        tr = [d for d in (defs.get("tr") or []) if (d.get("gloss") or "").strip()]
        # tr_overrides'i yedek olarak say
        has_tr = bool(tr) or wid in tr_overrides or wid in legacy
        has_kmr = bool(kmr)

        if has_kmr and has_tr:
            quality["both_kmr_tr"] += 1
        elif has_kmr and not has_tr:
            quality["kmr_only_no_tr"] += 1
            if len(only_kmr_examples) < 8:
                only_kmr_examples.append((wid, kmr[0]["gloss"][:60]))
        elif has_tr and not has_kmr:
            quality["tr_only_no_kmr"] += 1
            if len(only_tr_examples) < 8:
                only_tr_examples.append(wid)
        else:
            quality["empty_skeleton"] += 1
            if len(no_def_examples) < 8:
                no_def_examples.append(wid)

    total = sum(quality.values())

    def pct(n):
        return f"{n:>7,} ({100*n/total:>5.1f}%)"

    print(f"  ✅ KMR + TR var:           {pct(quality['both_kmr_tr'])}")
    print(f"  ⚠️  Sadece KMR, TR yok:    {pct(quality['kmr_only_no_tr'])}")
    print(f"  ⚠️  Sadece TR, KMR yok:    {pct(quality['tr_only_no_kmr'])}")
    print(f"  ❌ İskelet (her ikisi boş): {pct(quality['empty_skeleton'])}")
    print(f"  ────────────────────────────────────────")
    print(f"  Toplam entry:              {total:,}")
    print()

    if only_kmr_examples:
        print("  Sadece KMR örnekleri:")
        for w, g in only_kmr_examples:
            print(f"    • {w:<18} → {g}")
        print()
    if no_def_examples:
        print(f"  İskelet entry örnekleri: {', '.join(no_def_examples)}")
        print()

    # ── B. Wordlist coverage ───────────────────────────────────────
    print("=" * 70)
    print("B. WORDLIST → SÖZLÜK COVERAGE (playable kelimelerden kaçı bulunuyor)")
    print("=" * 70)

    cov = Counter()
    no_resolution_samples = []

    for w in wordlist:
        if w in entries:
            cov["direct_entry"] += 1
        elif w in related_idx:
            cov["via_related"] += 1
        elif w in tr_overrides:
            cov["via_tr_override"] += 1
        elif w in legacy:
            cov["via_legacy"] += 1
        else:
            cov["no_direct_match"] += 1
            if len(no_resolution_samples) < 30:
                no_resolution_samples.append(w)

    wl_total = len(wordlist)

    def pct_w(n):
        return f"{n:>9,} ({100*n/wl_total:>5.1f}%)"

    print(f"  ✅ Doğrudan entry:           {pct_w(cov['direct_entry'])}")
    print(f"  ✅ Related üzerinden:        {pct_w(cov['via_related'])}")
    print(f"  ✅ TR override üzerinden:    {pct_w(cov['via_tr_override'])}")
    print(f"  ✅ Legacy üzerinden:         {pct_w(cov['via_legacy'])}")
    print(f"  ❓ Direkt eşleşme YOK:       {pct_w(cov['no_direct_match'])}")
    print(f"    (bunlar runtime'da inflection-stripping ile çözülmeyi bekliyor)")
    print(f"  ────────────────────────────────────────")
    print(f"  Toplam playable:             {wl_total:,}")
    print()

    # ── C. Ters yön: dictionary'de olup wordlist'te olmayan ───────
    print("=" * 70)
    print("C. SÖZLÜKTE VAR AMA WORDLIST'DE YOK (oyunda oynanamayan entry'ler)")
    print("=" * 70)

    in_dict_not_playable = set(entries.keys()) - wordlist
    print(f"  Entry sözlükte var, oyunda oynanamıyor: {len(in_dict_not_playable):,}")
    if in_dict_not_playable:
        sample = list(in_dict_not_playable)[:15]
        print(f"  Örnekler: {', '.join(sample)}")
    print()

    # ── D. tr_overrides kalitesi ───────────────────────────────────
    print("=" * 70)
    print("D. TR_OVERRIDES KAYNAK ANALİZİ")
    print("=" * 70)

    src_counter = Counter()
    for k, v in tr_overrides.items():
        if isinstance(v, dict):
            src = v.get("source", "(unknown)")
            if "inferred-inflection" in src:
                src = "inferred-inflection"
            src_counter[src] += 1
        else:
            src_counter["string-form"] += 1
    for src, cnt in src_counter.most_common():
        print(f"  • {src:<35}{cnt:>7,}")
    print()

    # ── E. Özet ────────────────────────────────────────────────────
    print("=" * 70)
    print("ÖZET — En büyük açıklar")
    print("=" * 70)

    if quality['empty_skeleton'] > 0:
        print(
            f"  🔴 {quality['empty_skeleton']:,} entry iskelet (KMR + TR boş) — "
            f"%{100*quality['empty_skeleton']/total:.1f}"
        )
    if quality['kmr_only_no_tr'] > 0:
        print(
            f"  🟡 {quality['kmr_only_no_tr']:,} entry'de TR çevirisi eksik — "
            f"%{100*quality['kmr_only_no_tr']/total:.1f}"
        )
    if cov['no_direct_match'] > 0:
        print(
            f"  🟡 {cov['no_direct_match']:,} playable kelime direkt eşleşmiyor — "
            f"%{100*cov['no_direct_match']/wl_total:.1f}"
        )
        print(
            f"     (inflection-stripping bunların bir kısmını runtime'da çözüyor)"
        )
    if in_dict_not_playable:
        print(
            f"  🟡 {len(in_dict_not_playable):,} entry sözlükte var ama oyunda oynanamıyor"
        )


if __name__ == "__main__":
    main()
