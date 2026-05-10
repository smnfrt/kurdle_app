#!/usr/bin/env python3
"""Fetch upstream sources: KurdishHunspell .dic/.aff and kaikki.org Kurdish JSONL.

Inputs:  sources.lock.json
Outputs: raw/ku_kmr.dic, raw/ku_kmr.aff, raw/kaikki_kurdish.jsonl
         raw/FETCH_LOG.json (timestamps, sizes, sha256)
"""
from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import RAW, ensure_dirs, load_lock, log, sha256_file  # noqa: E402

HUNSPELL_RAW = "https://raw.githubusercontent.com/{repo}/{ref}/{path}"


def fetch(url: str, dest: Path, *, stream: bool = False) -> int:
    log(f"fetching {url}")
    r = requests.get(url, stream=stream, timeout=120)
    r.raise_for_status()
    if stream:
        total = 0
        with dest.open("wb") as f:
            for chunk in r.iter_content(1 << 16):
                f.write(chunk)
                total += len(chunk)
        return total
    dest.write_bytes(r.content)
    return len(r.content)


def main() -> int:
    ensure_dirs()
    lock = load_lock()

    fetch_log: dict = {"fetched_at": dt.datetime.utcnow().isoformat() + "Z", "files": {}}

    # KurdishHunspell
    hs = lock["kurdish_hunspell"]
    repo = hs["repo"]
    ref = hs["commit_sha"] if hs["commit_sha"] != "PINME" else hs["ref"]
    for local_name, repo_path in hs["files"].items():
        url = HUNSPELL_RAW.format(repo=repo, ref=ref, path=repo_path)
        dest = RAW / local_name
        size = fetch(url, dest)
        fetch_log["files"][local_name] = {
            "url": url,
            "size_bytes": size,
            "sha256": sha256_file(dest),
        }

    # kaikki.org Kurdish JSONL
    kk = lock["kaikki_kurdish"]
    dest = RAW / "kaikki_kurdish.jsonl"
    size = fetch(kk["url"], dest, stream=True)
    digest = sha256_file(dest)
    if kk["sha256"] not in ("PINME", digest):
        log(f"WARNING: kaikki sha256 mismatch (lock={kk['sha256']!r}, got={digest!r})")
    fetch_log["files"]["kaikki_kurdish.jsonl"] = {
        "url": kk["url"],
        "size_bytes": size,
        "sha256": digest,
    }

    (RAW / "FETCH_LOG.json").write_text(
        json.dumps(fetch_log, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    log("done.")
    log(f"  Hunspell .dic: {fetch_log['files']['ku_kmr.dic']['size_bytes']} bytes")
    log(f"  Hunspell .aff: {fetch_log['files']['ku_kmr.aff']['size_bytes']} bytes")
    log(f"  Kaikki JSONL : {fetch_log['files']['kaikki_kurdish.jsonl']['size_bytes']} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
