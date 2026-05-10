"""Test the kaikki record projection in 03_filter_kaikki.py."""
import importlib
import sys
from pathlib import Path

import orjson

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
filter_mod = importlib.import_module("03_filter_kaikki")  # type: ignore[attr-defined]


def _load_fixture():
    path = Path(__file__).parent / "fixtures" / "sample_kaikki.jsonl"
    return [orjson.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def test_project_keeps_kmr_record():
    recs = _load_fixture()
    av = next(r for r in recs if r["word"] == "av")
    out = filter_mod.project(av)
    assert out is not None
    assert out["normalized"] == "AV"
    assert out["pos"] == ["noun"]
    assert out["ipa"] == "av"
    assert out["definitions_kmr"][0]["gloss"].startswith("şilaviya")
    assert "Xweza" in out["categories_raw"]


def test_project_extracts_examples():
    recs = _load_fixture()
    kiteb = next(r for r in recs if r["word"] == "kitêb")
    out = filter_mod.project(kiteb)
    assert out is not None
    examples = out["definitions_kmr"][0]["examples"]
    assert examples[0]["text"] == "Kitêbeke baş."
    assert examples[0]["translation"] == "A good book."


def test_project_returns_none_for_invalid_headword():
    # Words with Arabic script are NOT valid Kurmanji (Latin) — should be filtered.
    out = filter_mod.project({"word": "ئاو", "lang_code": "ckb", "senses": []})
    assert out is None
