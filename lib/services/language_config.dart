import 'package:kurdle_app/services/app_locale.dart';

class LanguageConfig {
  final Map<String, int> tileBag;
  final Map<String, int> letterPoints;
  final List<String> wordAssets;

  const LanguageConfig({
    required this.tileBag,
    required this.letterPoints,
    required this.wordAssets,
  });

  static LanguageConfig get current =>
      L.current == AppLocale.tr ? turkish : kurdish;

  static const LanguageConfig kurdish = LanguageConfig(
    tileBag: {
      'A': 8, 'B': 3, 'C': 3, 'Ç': 2, 'D': 4, 'E': 8,
      'Ê': 3, 'F': 2, 'G': 3, 'H': 3, 'I': 6, 'Î': 3,
      'J': 2, 'K': 4, 'L': 4, 'M': 3, 'N': 5, 'O': 3,
      'P': 2, 'Q': 1, 'R': 5, 'S': 4, 'Ş': 2, 'T': 5,
      'U': 3, 'Û': 2, 'V': 2, 'W': 2, 'X': 1, 'Y': 3, 'Z': 2,
    },
    letterPoints: {
      'A': 1, 'E': 1, 'I': 1, 'N': 1, 'R': 1, 'T': 1,
      'B': 2, 'D': 2, 'K': 2, 'L': 2, 'M': 2, 'S': 2, 'U': 2,
      'C': 3, 'G': 3, 'H': 3, 'O': 3, 'V': 3, 'Y': 3,
      'Ç': 4, 'F': 4, 'J': 4, 'P': 4, 'Ş': 4, 'W': 4, 'Z': 4,
      'Ê': 5, 'Î': 5, 'Û': 5,
      'Q': 8, 'X': 8,
    },
    wordAssets: [
      'assets/allowed_guesses.txt',
      'assets/answers.txt',
      'assets/kurdish_dictionary.txt',
    ],
  );

  static const LanguageConfig turkish = LanguageConfig(
    tileBag: {
      'A': 12, 'B': 2, 'C': 2, 'Ç': 2, 'D': 4, 'E': 9,
      'F': 1,  'G': 1, 'Ğ': 1, 'H': 1, 'I': 4, 'İ': 8,
      'J': 1,  'K': 7, 'L': 7, 'M': 4, 'N': 5, 'O': 3,
      'Ö': 1,  'P': 1, 'R': 6, 'S': 3, 'Ş': 3, 'T': 5,
      'U': 3,  'Ü': 2, 'V': 1, 'Y': 2, 'Z': 2,
    },
    letterPoints: {
      'A': 1, 'E': 1, 'İ': 1, 'K': 1, 'L': 1, 'N': 1, 'R': 1, 'T': 1,
      'I': 2, 'M': 2, 'O': 2, 'S': 2, 'U': 2,
      'B': 3, 'D': 3, 'Ş': 3, 'Y': 3, 'Ü': 3,
      'C': 4, 'Ç': 4, 'Z': 4,
      'G': 5, 'H': 5, 'P': 5,
      'F': 7, 'Ö': 7, 'V': 7,
      'Ğ': 8,
      'J': 10,
    },
    wordAssets: ['assets/turkish_words.txt'],
  );
}
