class WordValidatorService {
  final Set<String> _words;

  WordValidatorService(List<String> wordList)
      : _words = wordList.map((w) => w.trim().toUpperCase()).toSet();

  bool isValid(String word) => _words.contains(word.toUpperCase());

  /// Returns all words from dictionary that can be formed with [available] letters.
  List<String> findFormable(List<String> available, {int minLength = 2}) {
    final pool = available.map((l) => l.toUpperCase()).toList();
    return _words
        .where((w) => w.length >= minLength && _canForm(w, pool))
        .toList();
  }

  bool _canForm(String word, List<String> pool) {
    final copy = [...pool];
    for (final ch in word.split('')) {
      final idx = copy.indexOf(ch);
      if (idx < 0) return false;
      copy.removeAt(idx);
    }
    return true;
  }
}
