import 'dart:math';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/game_score_service.dart';
import 'package:kurdle_app/services/word_validator_service.dart';

class AiMove {
  final List<({int row, int col, GameTile tile})> placements;
  final int score;
  const AiMove({required this.placements, required this.score});
}

class AiService {
  final WordValidatorService _validator;
  final GameScoreService _scorer;
  final Random _rng = Random();

  AiService(this._validator, this._scorer);

  /// Finds the best word the AI can play from its rack.
  /// Returns null if no move is possible.
  AiMove? findBestMove(WordBoard board, List<GameTile> rack) {
    final letters = rack.map((t) => t.letter).toList();
    final candidates = _validator.findFormable(letters, minLength: 2);
    if (candidates.isEmpty) return null;

    candidates.shuffle(_rng);
    final tryList = candidates.take(30).toList(); // limit search

    AiMove? best;

    for (final word in tryList) {
      final move = _tryPlace(board, rack, word);
      if (move != null && (best == null || move.score > best.score)) {
        best = move;
      }
    }
    return best;
  }

  AiMove? _tryPlace(WordBoard board, List<GameTile> rack, String word) {
    // Try placing the word horizontally on each row
    for (var row = 0; row < WordBoard.size; row++) {
      for (var col = 0; col <= WordBoard.size - word.length; col++) {
        final move = _tryHorizontal(board, rack, word, row, col);
        if (move != null) return move;
      }
    }
    // Try vertically
    for (var col = 0; col < WordBoard.size; col++) {
      for (var row = 0; row <= WordBoard.size - word.length; row++) {
        final move = _tryVertical(board, rack, word, row, col);
        if (move != null) return move;
      }
    }
    return null;
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

    // First move must cover center
    final isFirstMove = board.pendingCells.isEmpty &&
        board.cells.every((c) => !c.isLocked);
    if (isFirstMove) {
      final coversCentre = placements
          .any((p) => p.row == 7 && p.col == 7);
      if (!coversCentre) return null;
    } else if (!touchesExisting && placements.isNotEmpty) {
      return null;
    }

    final words = _scorer.calculateNewWords(tempBoard);
    if (words.isEmpty) return null;

    final score = GameScoreService.totalScore(words);
    return AiMove(placements: placements, score: score);
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

    final isFirstMove = board.cells.every((c) => !c.isLocked);
    if (isFirstMove) {
      final coversCentre = placements.any((p) => p.row == 7 && p.col == 7);
      if (!coversCentre) return null;
    } else if (!touchesExisting && placements.isNotEmpty) {
      return null;
    }

    final words = _scorer.calculateNewWords(tempBoard);
    if (words.isEmpty) return null;

    return AiMove(placements: placements, score: GameScoreService.totalScore(words));
  }

  int _findInRack(List<GameTile> rack, String letter, List<String> used) {
    for (var i = 0; i < rack.length; i++) {
      if (rack[i].letter == letter && !used.contains(rack[i].id)) return i;
    }
    return -1;
  }
}
