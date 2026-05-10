#!/usr/bin/env python3
"""Compute SHA-256 checksums for all artifacts in build/out/.

Output: build/out/SHA256SUMS (compatible with `shasum -a 256 -c`)
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import OUT, ensure_dirs, log, sha256_file  # noqa: E402

ARTIFACTS = [
    "wordlist.txt.gz",
    "ferheng_entries.ndjson",
    "entries.ndjson.gz",
    "legacy_meanings.json",
    "ferheng_qa.csv",
    "meta.json",
]


def main() -> int:
    ensure_dirs()
    lines = []
    for name in ARTIFACTS:
        p = OUT / name
        if not p.exists():
            log(f"ERROR: missing {p}. Run 'make emit' first.")
            return 1
        digest = sha256_file(p)
        lines.append(f"{digest}  {name}")

    sums_path = OUT / "SHA256SUMS"
    sums_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    log(f"wrote {sums_path}")
    for line in lines:
        log(f"  {line}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
