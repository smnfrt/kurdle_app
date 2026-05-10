import 'package:characters/characters.dart';
import 'package:kurdle_app/models/word_suggestion.dart';
import 'package:kurdle_app/services/word_suggestion_service.dart';

class WordValidatorService {
  final Set<String> _words;
  late final WordSuggestionService _suggester;

  WordValidatorService(List<String> wordList)
      : _words = wordList
            .map((w) => _normalize(w))
            .where((w) => w.isNotEmpty)
            .toSet() {
    _suggester = WordSuggestionService(_words);
  }

  /// Büyük harfe çevirir; boşlukları temizler.
  static String _normalize(String w) => w.trim().toUpperCase();

  bool isValid(String word) => _words.contains(_normalize(word));

  /// Geçersiz bir kelime için en yakın sözlük önerisini döndürür.
  /// Kelime zaten geçerliyse veya yakın eşleşme yoksa null döner.
  WordSuggestion? suggestWord(String word) =>
      _suggester.suggest(word);

  /// Verilen harflerle oluşturulabilecek tüm geçerli kelimeleri döndürür.
  List<String> findFormable(List<String> available, {int minLength = 2}) {
    final pool = available.map((l) => _normalize(l)).toList();
    return _words
        .where((w) => w.characters.length >= minLength && _canForm(w, pool))
        .toList();
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
