import 'dart:math';
import 'package:characters/characters.dart';
import 'package:kurdle_app/services/kurdish_meanings.dart';

enum ChallengeDifficulty { easy, medium, hard }

class ChallengeWord {
  final String original;
  final List<int> hiddenIndices;
  final String meaning;
  final ChallengeDifficulty difficulty;

  const ChallengeWord({
    required this.original,
    required this.hiddenIndices,
    required this.meaning,
    required this.difficulty,
  });

  String get masked {
    final chars = original.characters.toList();
    return chars
        .asMap()
        .entries
        .map((e) => hiddenIndices.contains(e.key) ? '_' : e.value)
        .join();
  }

  List<String> get hiddenLetters {
    final chars = original.characters.toList();
    return hiddenIndices.map((i) => chars[i]).toList();
  }

  Duration get stageDuration => switch (difficulty) {
        ChallengeDifficulty.easy => const Duration(seconds: 5),
        ChallengeDifficulty.medium => const Duration(seconds: 7),
        ChallengeDifficulty.hard => const Duration(seconds: 10),
      };

  int get stageIndex => difficulty.index;
}

class DailyChallengeService {
  const DailyChallengeService._();

  static const _kuAlphabet = [
    'A', 'B', 'C', 'Ç', 'D', 'E', 'Ê', 'F', 'G', 'H',
    'I', 'Î', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'R',
    'S', 'Ş', 'T', 'U', 'Û', 'V', 'W', 'X', 'Y', 'Z',
  ];

  static const int perfectBonus = 150;

  static String normalize(String w) => w.trim().toUpperCase();

  static List<int> _computeHiddenIndices(
      String word, ChallengeDifficulty diff, int seed) {
    final chars = word.characters.toList();
    final n = chars.length;
    final ratio = switch (diff) {
      ChallengeDifficulty.easy => 0.30,
      ChallengeDifficulty.medium => 0.50,
      ChallengeDifficulty.hard => 0.70,
    };
    final hideCount = (n * ratio).ceil().clamp(1, n - 1);
    final rng = Random(seed ^ word.hashCode ^ (diff.index * 7919));
    final indices = List<int>.generate(n, (i) => i)..shuffle(rng);
    return (indices.take(hideCount).toList()..sort());
  }

  static bool isCorrect(List<String> input, ChallengeWord challenge) {
    if (input.length != challenge.hiddenIndices.length) return false;
    final chars = challenge.original.characters.toList();
    for (var i = 0; i < challenge.hiddenIndices.length; i++) {
      if (input[i] != chars[challenge.hiddenIndices[i]]) return false;
    }
    return true;
  }

  // Returns exactly [total] unique letter options, always containing
  // all correct hidden letters.
  static List<String> buildOptions(ChallengeWord challenge, {int total = 8}) {
    final seed = _todaySeed() ^ challenge.original.hashCode;
    final rng = Random(seed);
    final correct = challenge.hiddenLetters.toSet().toList();
    final options = <String>{...correct};
    final pool = List<String>.from(_kuAlphabet)..shuffle(rng);
    for (final l in pool) {
      if (options.length >= total) break;
      options.add(l);
    }
    final result = options.toList()..shuffle(Random(seed + 1));
    return result;
  }

  static int calcScore(ChallengeDifficulty diff, int remainingMs) {
    final (int base, int div) = switch (diff) {
      ChallengeDifficulty.easy => (50, 200),
      ChallengeDifficulty.medium => (100, 150),
      ChallengeDifficulty.hard => (150, 100),
    };
    final bonus = (remainingMs / div).floor().clamp(0, 50);
    return base + bonus;
  }

  static List<ChallengeWord> getTodaysWords() {
    final entries = KurdishMeanings.allEntries;
    final seed = _todaySeed();

    // Need at least 3-char words
    final pool = entries
        .where((e) => e.word.characters.length >= 3)
        .toList();

    // Deterministic shuffle
    pool.shuffle(Random(seed));

    // Pick 3 distinct words
    final picked = pool.take(3).toList();

    return List.generate(3, (i) {
      final diff = ChallengeDifficulty.values[i];
      final entry = picked[i];
      final word = normalize(entry.word);
      final hidden = _computeHiddenIndices(word, diff, seed);
      return ChallengeWord(
        original: word,
        hiddenIndices: hidden,
        meaning: entry.meaning,
        difficulty: diff,
      );
    });
  }

  static int _todaySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }
}
