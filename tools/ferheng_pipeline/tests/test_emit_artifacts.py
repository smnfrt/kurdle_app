"""Test artifact emission helpers in 06_emit_artifacts.py."""
import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
emit_mod = importlib.import_module("06_emit_artifacts")  # type: ignore[attr-defined]


def test_prefixes_truncates_to_4_chars():
    assert emit_mod._prefixes("AV") == ["A", "AV"]
    assert emit_mod._prefixes("KITÊB") == ["K", "KI", "KIT", "KITÊ"]
    assert emit_mod._prefixes("HEZKIRIN") == ["H", "HE", "HEZ", "HEZK"]


def test_to_firestore_doc_shape():
    rec = {
        "headword": "av",
        "normalized": "AV",
        "pos": ["noun"],
        "ipa": "av",
        "definitions_kmr": [{"gloss": "şilavî", "examples": []}],
        "definitions_tr": [{"gloss": "su", "examples": []}],
        "etymology": "",
        "categories": ["nature"],
        "related": [],
        "source": "wiktionary+legacy",
        "source_url": "https://ku.wiktionary.org/wiki/av",
    }
    doc = emit_mod.to_firestore_doc(rec)
    assert doc["headword"] == "av"
    assert doc["normalized"] == "AV"
    assert doc["prefixes"] == ["A", "AV"]
    assert doc["dialect"] == "kmr"
    assert doc["definitions"]["kmr"][0]["gloss"] == "şilavî"
    assert doc["definitions"]["tr"][0]["gloss"] == "su"
    assert doc["categories"] == ["nature"]
    assert doc["license"] == "CC BY-SA 4.0"
    assert doc["version"] == 1
