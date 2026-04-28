import 'package:kurdle_app/services/language_config.dart';

// Kurmanji Latin alphabet letter points (frequency-based)
const Map<String, int> kurdishLetterPoints = {
  'A': 1, 'E': 1, 'I': 1, 'N': 1, 'R': 1, 'T': 1,
  'B': 2, 'D': 2, 'K': 2, 'L': 2, 'M': 2, 'S': 2, 'U': 2,
  'C': 3, 'G': 3, 'H': 3, 'O': 3, 'V': 3, 'Y': 3,
  'Ç': 4, 'F': 4, 'J': 4, 'P': 4, 'Ş': 4, 'W': 4, 'Z': 4,
  'Ê': 5, 'Î': 5, 'Û': 5,
  'Q': 8, 'X': 8,
};

class ScoringService {
  final Map<String, int> _points;

  const ScoringService(this._points);

  int letterPoints(String letter) =>
      _points[letter.toUpperCase()] ?? 1;

  int wordScore(String word) =>
      word.toUpperCase().split('').fold(0, (sum, c) => sum + letterPoints(c));

  /// Static access using current locale — used by GameTile, TileBuilder, etc.
  static int letterPointsCurrent(String letter) =>
      LanguageConfig.current.letterPoints[letter.toUpperCase()] ?? 1;

  // 1st attempt = ×6, 2nd = ×5, ..., 6th+ = ×1
  static int attemptMultiplier(int attemptIndex) {
    if (attemptIndex == 0) return 6;
    if (attemptIndex == 1) return 5;
    if (attemptIndex == 2) return 4;
    if (attemptIndex == 3) return 3;
    if (attemptIndex == 4) return 2;
    return 1;
  }

  static int calculateScore(String word, int attemptIndex) {
    final pts = LanguageConfig.current.letterPoints;
    final score = word.toUpperCase().split('').fold(0, (s, c) => s + (pts[c] ?? 1));
    return score * attemptMultiplier(attemptIndex);
  }
}
