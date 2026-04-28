import 'package:flutter/foundation.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/ai_service.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/board_layout_service.dart';
import 'package:kurdle_app/services/game_score_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/scoring_service.dart';
import 'package:kurdle_app/services/tile_bag_service.dart';
import 'package:kurdle_app/services/word_validator_service.dart';

enum GamePhase { playerTurn, aiTurn, gameOver }

class ScrabbleGameController extends ChangeNotifier {
  static const int rackSize = 7;

  WordBoard board;
  final TileBagService _bag;
  final WordValidatorService _validator;
  final GameScoreService _scorer;
  late final AiService _ai;

  List<GameTile> playerRack = [];
  List<GameTile> aiRack = [];

  int playerScore = 0;
  int aiScore = 0;

  int playerPassCount = 0;
  int totalPassCount  = 0;
  static const int maxPlayerPasses = 4;
  static const int maxTotalPasses  = 5;

  GamePhase phase = GamePhase.playerTurn;
  String message = '';

  int get tilesLeft => _bag.remaining;

  List<({String word, int score, bool valid})> _cachedPendingWords = const [];
  List<({String word, int score, bool valid})> get pendingWords => _cachedPendingWords;

  void _refreshPendingWords() {
    if (board.pendingCells.isEmpty) {
      _cachedPendingWords = const [];
      return;
    }
    _cachedPendingWords = _scorer.calculateNewWords(board)
        .map((w) => (word: w.word, score: w.score, valid: _validator.isValid(w.word)))
        .toList();
  }

  ScrabbleGameController(List<String> wordList, {LanguageConfig? config})
      : board = BoardLayoutService.createClassicLayout(),
        _bag = TileBagService((config ?? LanguageConfig.current).tileBag),
        _validator = WordValidatorService(wordList),
        _scorer = GameScoreService(
          ScoringService((config ?? LanguageConfig.current).letterPoints),
        ) {
    _ai = AiService(_validator, _scorer);
    playerRack = _bag.drawMany(rackSize);
    aiRack = _bag.drawMany(rackSize);
  }

  // ─── Tile placement ──────────────────────────────────────────

  bool canPlace(int row, int col) {
    final cell = board.cellAt(row, col);
    return !cell.hasLetter && phase == GamePhase.playerTurn;
  }

  void placeTile(int row, int col, GameTile tile) {
    if (!canPlace(row, col)) return;
    board = board.placePending(row, col, tile.letter, tile.id);
    playerRack.removeWhere((t) => t.id == tile.id);
    message = '';
    _refreshPendingWords();
    notifyListeners();
  }

  void recallTile(int row, int col) {
    final cell = board.cellAt(row, col);
    if (!cell.isPending) return;
    final tile = GameTile(id: cell.tileId!, letter: cell.letter);
    board = board.clearLetter(row, col);
    playerRack.add(tile);
    _refreshPendingWords();
    notifyListeners();
  }

  void recallAll() {
    for (final cell in board.pendingCells) {
      playerRack.add(GameTile(id: cell.tileId!, letter: cell.letter));
    }
    board = board.clearPending();
    _refreshPendingWords();
    notifyListeners();
  }

  void shuffleRack() {
    playerRack.shuffle();
    notifyListeners();
  }

  // ─── Pass / Exchange / Resign ────────────────────────────────

  int get passesLeft => maxPlayerPasses - playerPassCount;

  String? passTurn() {
    if (phase != GamePhase.playerTurn) return null;
    if (playerPassCount >= maxPlayerPasses) return L.noPassLeft;
    recallAll();
    playerPassCount++;
    totalPassCount++;
    if (totalPassCount >= maxTotalPasses) {
      phase = GamePhase.gameOver;
      message = L.gameEndedByPasses;
      notifyListeners();
      return null;
    }
    message = L.passesLeft(passesLeft);
    notifyListeners();
    _doAiTurn();
    return null;
  }

  String? exchangeTiles(List<GameTile> tiles) {
    if (phase != GamePhase.playerTurn) return null;
    if (tiles.isEmpty) return L.selectTile;
    if (_bag.remaining < tiles.length) return L.notEnoughTiles;
    recallAll();
    for (final tile in tiles) {
      playerRack.removeWhere((t) => t.id == tile.id);
    }
    _bag.returnTiles(tiles);
    _refillRack(playerRack);
    message = L.exchanged(tiles.length);
    notifyListeners();
    _doAiTurn();
    return null;
  }

  void resign() {
    recallAll();
    phase = GamePhase.gameOver;
    message = L.resign;
    notifyListeners();
  }

  // ─── Submit ──────────────────────────────────────────────────

  bool get _isFirstMove => board.cells.every((c) => !c.isLocked);

  String? submitMove() {
    final pending = board.pendingCells;
    if (pending.isEmpty) return L.placeTile;

    if (!_placementIsValid(pending)) return L.sameRowCol;

    if (_isFirstMove) {
      const center = WordBoard.centerIndex;
      final coversCenter = pending.any((c) => c.row == center && c.column == center);
      if (!coversCenter) return L.centerFirst;
    }

    if (!_isFirstMove && !_touchesLocked(pending)) return L.touchLocked;

    final words = _scorer.calculateNewWords(board);
    if (words.isEmpty) return L.noWord;

    final invalid = words.where((w) => !_validator.isValid(w.word)).toList();
    if (invalid.isNotEmpty) {
      final names = invalid.map((w) => w.word).join(', ');
      return L.invalidWords(names);
    }

    final earned = GameScoreService.totalScore(words);
    playerScore += earned;
    board = board.commitPending();
    _refillRack(playerRack);
    message = '+$earned ${L.points}!';
    _refreshPendingWords();
    notifyListeners();

    if (_bag.isEmpty && playerRack.isEmpty) {
      phase = GamePhase.gameOver;
      notifyListeners();
      return null;
    }

    _doAiTurn();
    return null;
  }

  // ─── AI turn ─────────────────────────────────────────────────

  void _doAiTurn() {
    phase = GamePhase.aiTurn;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 800), () {
      final move = _ai.findBestMove(board, aiRack);
      if (move != null) {
        for (final p in move.placements) {
          board = board.placePending(p.row, p.col, p.tile.letter, p.tile.id);
          aiRack.removeWhere((t) => t.id == p.tile.id);
        }
        aiScore += move.score;
        board = board.commitPending();
        _refillRack(aiRack);
      } else {
        totalPassCount++;
      }

      _refreshPendingWords();
      if (totalPassCount >= maxTotalPasses) {
        phase = GamePhase.gameOver;
        message = L.gameEndedByPasses;
      } else {
        phase = _bag.isEmpty && playerRack.isEmpty
            ? GamePhase.gameOver
            : GamePhase.playerTurn;
      }
      notifyListeners();
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────

  bool _touchesLocked(List cells) {
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final cell in cells) {
      for (final d in dirs) {
        final r = cell.row + d.$1;
        final c = cell.column + d.$2;
        if (r < 0 || r >= WordBoard.size || c < 0 || c >= WordBoard.size) continue;
        if (board.cellAt(r, c).isLocked) return true;
      }
    }
    return false;
  }

  bool _placementIsValid(List cells) {
    if (cells.length == 1) return true;
    final sameRow = cells.every((c) => c.row == cells.first.row);
    final sameCol = cells.every((c) => c.column == cells.first.column);
    if (!sameRow && !sameCol) return false;

    if (sameRow) {
      final cols = cells.map((c) => c.column as int).toList()..sort();
      for (var i = cols.first; i <= cols.last; i++) {
        if (!board.cellAt(cells.first.row, i).hasLetter) return false;
      }
    } else {
      final rows = cells.map((c) => c.row as int).toList()..sort();
      for (var i = rows.first; i <= rows.last; i++) {
        if (!board.cellAt(i, cells.first.column).hasLetter) return false;
      }
    }
    return true;
  }

  void _refillRack(List<GameTile> rack) {
    final need = rackSize - rack.length;
    rack.addAll(_bag.drawMany(need));
  }
}
