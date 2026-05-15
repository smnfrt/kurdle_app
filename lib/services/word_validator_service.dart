import 'package:characters/characters.dart';
import 'package:kurdle_app/models/word_suggestion.dart';
import 'package:kurdle_app/services/word_suggestion_service.dart';
import 'package:kurdle_app/services/word_normalizer.dart';

class WordValidatorService {
  final Set<String> _words;

  /// Kelime uzunluğuna göre gruplanmış sub-listeler. Length-aware sorgular
  /// (canFormAny, findFormable with maxLength) bütün 1.5M kelimeyi taramak
  /// yerine sadece ilgili uzunluk diliminde iter eder — ~10-50x hızlanma.
  final Map<int, List<String>> _byLength;

  late final WordSuggestionService _suggester;

  // ── Static cache ───────────────────────────────────────────────
  // Aynı wordList ile her oyunda yeniden inşa etmemek için. 1.5M kelimelik
  // Set + length-index inşası ~500-1000ms — ana thread'i bloklar. Cache
  // sayesinde 2.+ oyun anında.
  static WordValidatorService? _cached;
  static List<String>? _cachedSource;

  factory WordValidatorService(List<String> wordList) {
    if (identical(_cachedSource, wordList) && _cached != null) {
      return _cached!;
    }
    final v = WordValidatorService._internal(wordList);
    _cached = v;
    _cachedSource = wordList;
    return v;
  }

  WordValidatorService._internal(List<String> wordList)
      : _words = wordList
            .map((w) => _normalize(w))
            .where((w) => w.isNotEmpty)
            .toSet(),
        _byLength = {} {
    for (final w in _words) {
      final len = w.characters.length;
      (_byLength[len] ??= <String>[]).add(w);
    }
    _suggester = WordSuggestionService(_words);
  }

  /// Ferheng ile aynı normalize kuralını kullanır.
  static String _normalize(String w) => WordNormalizer.normalize(w);

  bool isValid(String word) => _words.contains(_normalize(word));

  /// Geçersiz bir kelime için en yakın sözlük önerisini döndürür.
  /// Kelime zaten geçerliyse veya yakın eşleşme yoksa null döner.
  WordSuggestion? suggestWord(String word) => _suggester.suggest(word);

  /// Verilen harflerle oluşturulabilecek tüm geçerli kelimeleri döndürür.
  List<String> findFormable(List<String> available,
      {int minLength = 2, int? maxLength}) {
    final pool = available.map((l) => _normalize(l)).toList();
    final out = <String>[];
    for (final entry in _byLength.entries) {
      final len = entry.key;
      if (len < minLength) continue;
      if (maxLength != null && len > maxLength) continue;
      for (final w in entry.value) {
        if (_canForm(w, pool)) out.add(w);
      }
    }
    return out;
  }

  /// Performans için: erken çıkışlı varlık kontrolü. İlk geçerli kelimeyi
  /// bulduğunda `true` döner. Rack playability gibi "var mı/yok" soruları için.
  bool canFormAny(List<String> available, {int minLength = 2, int? maxLength}) {
    final pool = available.map((l) => _normalize(l)).toList();
    // Kısa uzunluklardan başla — en hızlı eşleşme şansı.
    final lengths = _byLength.keys.toList()..sort();
    for (final len in lengths) {
      if (len < minLength) continue;
      if (maxLength != null && len > maxLength) continue;
      for (final w in _byLength[len]!) {
        if (_canForm(w, pool)) return true;
      }
    }
    return false;
  }

  bool _canForm(String word, List<String> pool) {
    final copy = [...pool];
    for (final ch in word.characters) {
      final idx = copy.indexOf(ch);
      if (idx < 0) return false;
      copy.removeAt(idx);
    }
    return true;
  }
}
