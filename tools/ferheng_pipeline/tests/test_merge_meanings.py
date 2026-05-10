"""Test the legacy Dart-map parser in 04_merge_meanings.py."""
import importlib
import sys
from pathlib import Path

# Import the script as a module — it has a numeric-prefix filename, so we use importlib.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
merge_mod = importlib.import_module("04_merge_meanings")  # type: ignore[attr-defined]


FIXTURE = Path(__file__).parent / "fixtures" / "sample_legacy.dart"


def test_parse_legacy_extracts_kurmanji_entries():
    text = FIXTURE.read_text(encoding="utf-8")
    entries = merge_mod.parse_legacy_dart(text)
    # Valid Kurmanji entries are kept.
    assert entries["AV"] == "su"
    assert entries["KITÊB"] == "kitap"
    assert entries["AZADÎ"] == "özgürlük"
    assert entries["ŞEV"] == "gece"
    # Turkish-only-letter headwords are filtered out.
    assert "İSTANBUL" not in entries
    # Total count: 6 valid out of 7 in fixture.
    assert len(entries) == 6


def test_parse_legacy_handles_diacritics_via_nfc():
    text = "'AVÊN': 'sular',"
    entries = merge_mod.parse_legacy_dart(text)
    assert "AVÊN" in entries
