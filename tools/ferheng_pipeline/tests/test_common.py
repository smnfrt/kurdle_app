"""Unit tests for _common.py utilities."""
from _common import (
    KURMANJI_ALPHABET,
    is_valid_kurmanji,
    nfc,
    normalize_headword,
)


def test_kurmanji_alphabet_canonical_order():
    assert KURMANJI_ALPHABET[0] == "A"
    assert KURMANJI_ALPHABET[-1] == "Z"
    assert "Ç" in KURMANJI_ALPHABET
    assert "Ê" in KURMANJI_ALPHABET
    assert "Î" in KURMANJI_ALPHABET
    assert "Ş" in KURMANJI_ALPHABET
    assert "Û" in KURMANJI_ALPHABET
    # Turkish-only letters are NOT part of the Kurmanji alphabet
    assert "İ" not in KURMANJI_ALPHABET
    assert "Ğ" not in KURMANJI_ALPHABET
    assert "Ü" not in KURMANJI_ALPHABET
    assert "Ö" not in KURMANJI_ALPHABET


def test_normalize_headword_uppercases_and_nfc():
    assert normalize_headword("av") == "AV"
    assert normalize_headword("kitêb") == "KITÊB"
    assert normalize_headword("  azadî  ") == "AZADÎ"


def test_nfc_collapses_decomposed_diacritics():
    decomposed = "ê"  # e + combining circumflex
    assert nfc(decomposed) == "ê"


def test_is_valid_kurmanji_accepts_all_kurmanji_letters():
    for ch in KURMANJI_ALPHABET:
        assert is_valid_kurmanji(ch), f"{ch} should be valid Kurmanji"


def test_is_valid_kurmanji_rejects_turkish_only_letters():
    assert not is_valid_kurmanji("İSTANBUL")
    assert not is_valid_kurmanji("GÜZEL")
    assert not is_valid_kurmanji("ÖĞRETMEN")


def test_is_valid_kurmanji_rejects_empty():
    assert not is_valid_kurmanji("")
    assert not is_valid_kurmanji("   ")


def test_is_valid_kurmanji_accepts_real_kurmanji_words():
    for w in ["AV", "KITÊB", "BAJAR", "AZADÎ", "ÇEM", "ŞEV", "DÎWAR"]:
        assert is_valid_kurmanji(w), f"{w} should be valid"
