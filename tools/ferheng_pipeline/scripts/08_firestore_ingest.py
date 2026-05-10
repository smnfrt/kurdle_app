#!/usr/bin/env python3
"""Upload `build/out/ferheng_entries.ndjson` to Firestore.

Prerequisites:
  pip install firebase-admin     (eklendi: requirements-ingest.txt)
  Service account JSON: indir → ortam değişkeni `GOOGLE_APPLICATION_CREDENTIALS`
  yol göster.

Kullanım:
  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
  .venv/bin/pip install firebase-admin
  .venv/bin/python scripts/08_firestore_ingest.py [--dry-run] [--limit N]

Notlar:
  - Batch size: 500 (Firestore tek-batch limit).
  - Document id = entry['normalized'] (deterministic, idempotent).
  - `ferheng_meta/kmr` da yazılır (versiyon + sayım + kill switch).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import orjson

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import OUT, log  # noqa: E402

BATCH_SIZE = 500


def _load_firestore():
    try:
        import firebase_admin  # type: ignore
        from firebase_admin import credentials, firestore  # type: ignore
    except ImportError as e:
        log("ERROR: firebase-admin not installed.")
        log("  .venv/bin/pip install firebase-admin")
        raise SystemExit(1) from e

    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    return firestore.client()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true",
                        help="Sadece sayım — yazma yapma.")
    parser.add_argument("--limit", type=int, default=0,
                        help="Test için: en fazla N entry yaz.")
    args = parser.parse_args()

    nd_path = OUT / "ferheng_entries.ndjson"
    meta_path = OUT / "meta.json"
    if not nd_path.exists() or not meta_path.exists():
        log(f"ERROR: missing artifacts. Run 'make all' first.")
        return 1

    entries: list[dict] = []
    with nd_path.open("rb") as f:
        for line in f:
            entries.append(orjson.loads(line))
            if args.limit and len(entries) >= args.limit:
                break
    log(f"loaded {len(entries):,} entries")

    if args.dry_run:
        log("DRY RUN — Firestore'a yazılmayacak.")
        return 0

    db = _load_firestore()

    # 1) Entry'leri batch yaz.
    written = 0
    for start in range(0, len(entries), BATCH_SIZE):
        batch = db.batch()
        chunk = entries[start:start + BATCH_SIZE]
        for doc in chunk:
            ref = db.collection("ferheng").document(doc["normalized"])
            batch.set(ref, doc)
        batch.commit()
        written += len(chunk)
        log(f"  wrote {written:,}/{len(entries):,}")

    # 2) Meta dokümanı yaz.
    meta = orjson.loads(meta_path.read_bytes())
    db.collection("ferheng_meta").document(meta["dialect"]).set(meta)
    log(f"wrote ferheng_meta/{meta['dialect']}")

    log("done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
