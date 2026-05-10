"""Test category assignment in 05_categorize.py."""
import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
cat_mod = importlib.import_module("05_categorize")  # type: ignore[attr-defined]


def test_categorize_uses_overrides_first():
    overrides = {"AV": ["nature", "basic"]}
    rec = {"normalized": "AV", "categories_raw": ["Heywan"], "definitions_tr": [{"gloss": "su"}]}
    assert cat_mod.categorize(rec, overrides) == ["nature", "basic"]


def test_categorize_uses_raw_categories_when_no_override():
    rec = {"normalized": "ÇAV", "categories_raw": ["ku:Beden"], "definitions_tr": []}
    assert cat_mod.categorize(rec, {}) == ["body"]


def test_categorize_falls_back_to_tr_keywords():
    rec = {"normalized": "BIRA", "categories_raw": [], "definitions_tr": [{"gloss": "kardeş"}]}
    assert "family" in cat_mod.categorize(rec, {})


def test_categorize_returns_empty_when_no_signal():
    rec = {"normalized": "XYZQ", "categories_raw": [], "definitions_tr": []}
    assert cat_mod.categorize(rec, {}) == []
