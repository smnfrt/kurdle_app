import 'package:kurdle_app/models/board_cell.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/scoring_service.dart';

class PlacedWord {
  final String word;
  final int score;
  final List<BoardCell> cells;

  const PlacedWord({
    required this.word,
    required this.score,
    required this.cells,
  });
}

class GameScoreService {
  final ScoringService _scoring;

  const GameScoreService(this._scoring);

  /// Finds all horizontal/vertical words that include at least one pending cell.
  List<PlacedWord> calculateNewWords(WordBoard board) {
    final pending = board.pendingCells.toSet();
    if (pending.isEmpty) return [];

    final words = <PlacedWord>[];
    final checked = <String>{};

    for (final cell in pending) {
      for (final horizontal in [true, false]) {
        final key = horizontal
            ? 'H:${cell.row}:${_start(board, cell.row, cell.column, true)}'
            : 'V:${_start(board, cell.row, cell.column, false)}:${cell.column}';
        if (checked.contains(key)) continue;
        checked.add(key);

        final word = _extractWord(board, cell.row, cell.column, horizontal);
        if (word != null) words.add(word);
      }
    }
    return words;
  }

  int _start(WordBoard b, int row, int col, bool horiz) {
    var r = row, c = col;
    while (horiz ? c > 0 : r > 0) {
      final prev = b.cellAt(horiz ? r : r - 1, horiz ? c - 1 : c);
      if (!prev.hasLetter) break;
      if (horiz) c--; else r--;
    }
    return horiz ? c : r;
  }

  PlacedWord? _extractWord(WordBoard b, int row, int col, bool horiz) {
    var r = row, c = col;
    while (horiz ? c > 0 : r > 0) {
      final prev = b.cellAt(horiz ? r : r - 1, horiz ? c - 1 : c);
      if (!prev.hasLetter) break;
      if (horiz) c--; else r--;
    }

    final cells = <BoardCell>[];
    while (r < WordBoard.size && c < WordBoard.size) {
      final cell = b.cellAt(r, c);
      if (!cell.hasLetter) break;
      cells.add(cell);
      if (horiz) c++; else r++;
    }

    if (cells.length < 2) return null;

    final hasPending = cells.any((c) => c.isPending);
    if (!hasPending) return null;

    final word = cells.map((c) => c.letter).join();
    int score = 0;
    int wordMult = 1;

    for (final cell in cells) {
      final pts = _scoring.letterPoints(cell.letter);
      score += cell.isPending ? pts * cell.letterMultiplier : pts;
      if (cell.isPending) wordMult *= cell.wordMultiplier;
    }

    return PlacedWord(word: word, score: score * wordMult, cells: cells);
  }

  static int totalScore(List<PlacedWord> words) =>
      words.fold(0, (sum, w) => sum + w.score);
}
