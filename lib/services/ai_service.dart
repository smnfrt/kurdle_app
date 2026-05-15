import 'dart:math';

import 'package:kurdle_app/domain.dart' show AiDifficulty;
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/game_score_service.dart';
import 'package:kurdle_app/services/word_validator_service.dart';

class AiMove {
  final List<({int row, int col, GameTile tile})> placements;
  final int score;
  final String word;
  const AiMove({required this.placements, required this.score, required this.word});
}

/// Scrabble AI rakip.
///
/// Mantık (zorluk seviyesine göre):
///   - **Easy**: rack'tan 2-4 harfli kelime üretir, geçerli ilk yerleşimi oynar.
///     Tahta anchor'larını kullanmaz. Düşük skor, öğrenme dostu.
///   - **Normal**: rack + tahtadaki tüm benzersiz harflerle kelime üretir
///     (1-anchor combo), tüm yerleşimleri dener, en yüksek skoru seçer.
///   - **Hard**: Normal'a ek olarak 2-anchor combo, bonus kare optimizasyonu,
///     daha fazla aday kelime.
class AiService {
  final WordValidatorService _validator;
  final GameScoreService _scorer;
  final Random _rng = Random();

  // Difficulty-specific search budget
  static const Map<AiDifficulty, int> _wordBudget = {
    AiDifficulty.easy: 20,
    AiDifficulty.normal: 60,
    AiDifficulty.hard: 200,
  };

  AiService(this._validator, this._scorer);

  /// Verilen tahtada AI'nın oynayabileceği en iyi hamleyi bulur.
  /// Difficulty parametresine göre arama derinliği ve skor önceliği değişir.
  AiMove? findBestMove(
    WordBoard board,
    List<GameTile> rack, {
    AiDifficulty difficulty = AiDifficulty.normal,
  }) {
    final rackChars = rack.map((t) => t.letter).toList();

    // 1) Aday kelimeleri topla — rack-only + (Normal/Hard) anchor combo
    final candidates = _gatherCandidates(board, rackChars, difficulty);
    if (candidates.isEmpty) return null;

    // Easy: kısa kelime + erken random pick
    if (difficulty == AiDifficulty.easy) {
      return _findEasyMove(board, rack, candidates);
    }

    // Normal/Hard: tüm aday kelimeleri test et, en yüksek skor
    return _findBestScoredMove(board, rack, candidates, difficulty);
  }

  // ── Aday üretimi ───────────────────────────────────────────────

  List<String> _gatherCandidates(
    WordBoard board,
    List<String> rackChars,
    AiDifficulty difficulty,
  ) {
    final budget = _wordBudget[difficulty]!;
    final out = <String>{};

    // 1) Rack-only kelimeler
    final rackOnly = _validator.findFormable(rackChars, minLength: 2);
    if (difficulty == AiDifficulty.easy) {
      // Easy: 2-4 harfli kelimeleri tercih, en uzun yapma
      out.addAll(rackOnly.where((w) => w.length >= 2 && w.length <= 4));
      if (out.length < budget) {
        out.addAll(rackOnly);
      }
      return _trim(out, budget, easy: true);
    }
    out.addAll(rackOnly);

    // 2) Tahtadaki benzersiz harflerle anchor combo
    final boardChars = <String>{};
    for (final c in board.cells) {
      final l = c.letter;
      if (l.isNotEmpty) boardChars.add(l);
    }

    // 1-anchor combo: rack + her tahta harfi
    for (final ch in boardChars) {
      out.addAll(_validator.findFormable([...rackChars, ch], minLength: 2));
      if (out.length >= budget * 3) break; // erken çıkış
    }

    // Hard: 2-anchor combo (daha derin arama)
    if (difficulty == AiDifficulty.hard) {
      final boardList = boardChars.toList();
      outer:
      for (var a = 0; a < boardList.length; a++) {
        for (var b = a; b < boardList.length; b++) {
          out.addAll(_validator.findFormable(
              [...rackChars, boardList[a], boardList[b]],
              minLength: 3));
          if (out.length >= budget * 4) break outer;
        }
      }
    }

    return _trim(out, budget);
  }

  /// Aday setini budget'a göre kısaltır.
  List<String> _trim(Set<String> set, int budget, {bool easy = false}) {
    final list = set.toList();
    if (easy) {
      // Easy: kısalardan başla
      list.sort((a, b) => a.length.compareTo(b.length));
    } else {
      // Normal/Hard: uzun kelimeleri öne al (skor potansiyeli)
      list.sort((a, b) => b.length.compareTo(a.length));
    }
    return list.take(budget).toList();
  }

  // ── Easy: rastgele bir geçerli yerleşim ─────────────────────────

  AiMove? _findEasyMove(WordBoard board, List<GameTile> rack, List<String> candidates) {
    candidates.shuffle(_rng);
    for (final word in candidates) {
      final move = _tryPlaceAnyDirection(board, rack, word);
      if (move != null) return move;
    }
    return null;
  }

  // ── Normal/Hard: en yüksek skoru ara ────────────────────────────

  AiMove? _findBestScoredMove(
    WordBoard board,
    List<GameTile> rack,
    List<String> candidates,
    AiDifficulty difficulty,
  ) {
    AiMove? best;
    // Hard: rastgele bağ yok, deterministik en iyi. Normal'da hafif jitter.
    for (final word in candidates) {
      final move = _tryAllPositions(board, rack, word);
      if (move == null) continue;
      if (best == null || move.score > best.score) {
        best = move;
      }
    }
    return best;
  }

  // ── Yerleşim arama ──────────────────────────────────────────────

  AiMove? _tryPlaceAnyDirection(WordBoard board, List<GameTile> rack, String word) {
    for (var row = 0; row < WordBoard.size; row++) {
      for (var col = 0; col <= WordBoard.size - word.length; col++) {
        final move = _tryHorizontal(board, rack, word, row, col);
        if (move != null) return move;
      }
    }
    for (var col = 0; col < WordBoard.size; col++) {
      for (var row = 0; row <= WordBoard.size - word.length; row++) {
        final move = _tryVertical(board, rack, word, row, col);
        if (move != null) return move;
      }
    }
    return null;
  }

  /// Tüm konumları test eder, en yüksek skorlu yerleşimi döndürür.
  AiMove? _tryAllPositions(WordBoard board, List<GameTile> rack, String word) {
    AiMove? best;
    for (var row = 0; row < WordBoard.size; row++) {
      for (var col = 0; col <= WordBoard.size - word.length; col++) {
        final move = _tryHorizontal(board, rack, word, row, col);
        if (move != null && (best == null || move.score > best.score)) {
          best = move;
        }
      }
    }
    for (var col = 0; col < WordBoard.size; col++) {
      for (var row = 0; row <= WordBoard.size - word.length; row++) {
        final move = _tryVertical(board, rack, word, row, col);
        if (move != null && (best == null || move.score > best.score)) {
          best = move;
        }
      }
    }
    return best;
  }

  AiMove? _tryHorizontal(
      WordBoard board, List<GameTile> rack, String word, int row, int col) {
    final placements = <({int row, int col, GameTile tile})>[];
    final usedRack = <String>[];
    var tempBoard = board;
    bool touchesExisting = false;

    for (var i = 0; i < word.length; i++) {
      final c = col + i;
      final letter = word[i];
      final cell = board.cellAt(row, c);

      if (cell.isLocked) {
        if (cell.letter != letter) return null;
        touchesExisting = true;
      } else if (cell.hasLetter) {
        return null;
      } else {
        final idx = _findInRack(rack, letter, usedRack);
        if (idx < 0) return null;
        usedRack.add(rack[idx].id);
        final dummy = GameTile(id: rack[idx].id, letter: letter);
        placements.add((row: row, col: c, tile: dummy));
        tempBoard = tempBoard.placePending(row, c, letter, dummy.id);
      }
    }

    if (placements.isEmpty) return null;

    final isFirstMove = board.cells.every((c) => !c.isLocked);
    if (isFirstMove) {
      final coversCentre = placements.any((p) => p.row == 7 && p.col == 7);
      if (!coversCentre) return null;
    } else if (!touchesExisting) {
      return null;
    }

    final words = _scorer.calculateNewWords(tempBoard);
    if (words.isEmpty) return null;
    final invalid = words.where((w) => !_validator.isValid(w.word));
    if (invalid.isNotEmpty) return null;

    final score = GameScoreService.totalScore(words);
    return AiMove(placements: placements, score: score, word: word);
  }

  AiMove? _tryVertical(
      WordBoard board, List<GameTile> rack, String word, int row, int col) {
    final placements = <({int row, int col, GameTile tile})>[];
    final usedRack = <String>[];
    var tempBoard = board;
    bool touchesExisting = false;

    for (var i = 0; i < word.length; i++) {
      final r = row + i;
      final letter = word[i];
      final cell = board.cellAt(r, col);

      if (cell.isLocked) {
        if (cell.letter != letter) return null;
        touchesExisting = true;
      } else if (cell.hasLetter) {
        return null;
      } else {
        final idx = _findInRack(rack, letter, usedRack);
        if (idx < 0) return null;
        usedRack.add(rack[idx].id);
        final dummy = GameTile(id: rack[idx].id, letter: letter);
        placements.add((row: r, col: col, tile: dummy));
        tempBoard = tempBoard.placePending(r, col, letter, dummy.id);
      }
    }

    if (placements.isEmpty) return null;

    final isFirstMove = board.cells.every((c) => !c.isLocked);
    if (isFirstMove) {
      final coversCentre = placements.any((p) => p.row == 7 && p.col == 7);
      if (!coversCentre) return null;
    } else if (!touchesExisting) {
      return null;
    }

    final words = _scorer.calculateNewWords(tempBoard);
    if (words.isEmpty) return null;
    final invalid = words.where((w) => !_validator.isValid(w.word));
    if (invalid.isNotEmpty) return null;

    return AiMove(
        placements: placements,
        score: GameScoreService.totalScore(words),
        word: word);
  }

  int _findInRack(List<GameTile> rack, String letter, List<String> used) {
    for (var i = 0; i < rack.length; i++) {
      if (rack[i].letter == letter && !used.contains(rack[i].id)) return i;
    }
    return -1;
  }
}
