import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/domain.dart' show AiDifficulty;
import 'package:kurdle_app/models/board_cell.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/models/word_enhancement.dart';
import 'package:kurdle_app/models/word_suggestion.dart';
import 'package:kurdle_app/services/ai_service.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/achievement_service.dart';
import 'package:kurdle_app/services/daily_streak_service.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/board_layout_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/game_score_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/scoring_service.dart';
import 'package:kurdle_app/services/tile_bag_service.dart';
import 'package:kurdle_app/services/word_steal_service.dart';
import 'package:kurdle_app/services/word_validator_service.dart';

enum GamePhase { playerTurn, aiTurn, gameOver }

class ScrabbleGameController extends ChangeNotifier {
  static const int rackSize = 7;

  // ── Geliştirme sabitleri ─────────────────────────────────────────
  static const int maxEnhancesPerGame = 2;
  static const int maxEnhancesPerWord = 2;
  static const double enhanceBonusRate = 0.5;
  static const int bonusPerAddedLetter = 10;
  static const double reclaimBonusRate = 0.25;

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
  int totalPassCount = 0;
  static const int maxPlayerPasses = 4;
  static const int maxTotalPasses = 5;

  GamePhase phase = GamePhase.playerTurn;
  String message = '';

  final DateTime _startedAt = DateTime.now();

  // ── Geliştirme durumu ────────────────────────────────────────────
  final List<PlacedWordRecord> _wordHistory = [];
  int _turnNumber = 0;
  int playerEnhanceCount = 0;
  bool _playerEnhancedLastTurn = false;
  Set<String> highlightedCells = {};
  Set<String> lastMoveCells = {};
  List<({String word, Set<String> cells})> lastMoveWords = const [];
  bool turnForfeited = false;
  WordSuggestion? lastSuggestion;

  // ── Çalma durumu ─────────────────────────────────────────────────
  static const _stealSvc = WordStealService();
  static const int maxStealsPerGame = 2;
  static const int stealPenaltyPoints = 5;

  /// Oyuncunun kalan çalma hakkı sayısı (0-2).
  int playerStealsLeft = maxStealsPerGame;

  /// Çalma modu aktif mi? Aktifken hamle çalma denemesi olarak değerlendirilir.
  bool isInStealMode = false;

  /// Son çalma işleminin sonucu; yoksa null.
  StealResult? lastStealResult;

  /// Son başarısız çalma denemesinin sonucu; UI hata gösterimi için.
  StealResult? lastFailedSteal;

  /// Son çalınan kelimede yeni eklenen harflerin hücre anahtarları ('row:col').
  Set<String> stolenNewCells = {};

  // ── Süre sınırı ─────────────────────────────────────────────────
  int? turnTimeLimitSeconds; // null = süresiz
  DateTime? _turnStartedAt;
  Timer? _countdownTimer;
  int turnSecondsLeft = 0; // UI için geri sayım

  int get playerEnhancesLeft => maxEnhancesPerGame - playerEnhanceCount;
  int get tilesLeft => _bag.remaining;

  List<({String word, int score, bool valid})> _cachedPendingWords = const [];
  List<({String word, int score, bool valid})> get pendingWords =>
      _cachedPendingWords;

  void _refreshPendingWords() {
    if (board.pendingCells.isEmpty) {
      _cachedPendingWords = const [];
      return;
    }
    _cachedPendingWords = _scorer
        .calculateNewWords(board)
        .map((w) =>
            (word: w.word, score: w.score, valid: _validator.isValid(w.word)))
        .toList();
  }

  /// AI rakip zorluk seviyesi. Settings'ten gelir; constructor override eder.
  AiDifficulty aiDifficulty;

  ScrabbleGameController(
    List<String> wordList, {
    LanguageConfig? config,
    this.turnTimeLimitSeconds,
    this.aiDifficulty = AiDifficulty.normal,
  })  : board = BoardLayoutService.createClassicLayout(),
        _bag = TileBagService((config ?? LanguageConfig.current).tileBag),
        _validator = WordValidatorService(wordList),
        _scorer = GameScoreService(
          ScoringService((config ?? LanguageConfig.current).letterPoints),
        ) {
    _ai = AiService(_validator, _scorer);
    playerRack = _bag.drawMany(rackSize);
    aiRack = _bag.drawMany(rackSize);
    _ensureRackPlayable(playerRack);
    _startTurnTimer();
    // Günlük "her gün oynama" streak'ini işaretle (fire-and-forget).
    DailyStreakService.instance.markPlayedToday().then((streak) {
      AchievementService.instance.onGameStarted();
      AchievementService.instance.onStreakChanged(streak.current);
    });
  }

  void _startTurnTimer() {
    _countdownTimer?.cancel();
    final limit = turnTimeLimitSeconds;
    if (limit == null || phase == GamePhase.gameOver) return;
    _turnStartedAt = DateTime.now();
    turnSecondsLeft = limit;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (phase == GamePhase.gameOver) {
        _countdownTimer?.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_turnStartedAt!).inSeconds;
      turnSecondsLeft = (limit - elapsed).clamp(0, limit);
      notifyListeners();
      if (turnSecondsLeft <= 0) {
        _countdownTimer?.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    if (phase == GamePhase.gameOver) return;
    if (phase == GamePhase.playerTurn) {
      // Oyuncu süreyi aştı → oyuncu kaybetti
      playerScore = 0;
      message = L.timeoutLose;
    } else {
      // AI sırası bitmedi (normalde olmaz)
      aiScore = 0;
    }
    phase = GamePhase.gameOver;
    notifyListeners();
  }

  // ─── Taş yerleştirme ─────────────────────────────────────────────

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

  // ─── Çalma modu ──────────────────────────────────────────────────

  /// Çalma modunu aç/kapat.
  /// Mod değişince rack'teki tüm bekleyen taşlar geri alınır.
  void toggleStealMode() {
    if (phase != GamePhase.playerTurn) return;
    if (!isInStealMode && playerStealsLeft <= 0) {
      message = L.noStealLeft;
      notifyListeners();
      return;
    }
    isInStealMode = !isInStealMode;
    if (!isInStealMode) recallAll();
    lastFailedSteal = null;
    message = isInStealMode ? L.stealModeActive : '';
    notifyListeners();
  }

  // ─── Pas / Değiştir / İstifa ──────────────────────────────────────

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
    _playerEnhancedLastTurn = false;
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
    _ensureRackPlayable(playerRack);
    _playerEnhancedLastTurn = false;
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
    _onGameOver();
  }

  // ─── Hamle gönder ────────────────────────────────────────────────

  bool get _isFirstMove => board.cells.every((c) => !c.isLocked);

  String? submitMove() {
    final pending = board.pendingCells;
    if (pending.isEmpty) return L.placeTile;
    if (!_placementIsValid(pending)) return L.sameRowCol;

    if (_isFirstMove) {
      const center = WordBoard.centerIndex;
      if (!pending.any((c) => c.row == center && c.column == center)) {
        return L.centerFirst;
      }
    }

    if (!_isFirstMove && !_touchesLocked(pending)) return L.touchLocked;

    final words = _scorer.calculateNewWords(board);
    if (words.isEmpty) return L.noWord;

    // ── Geliştirme tespiti ────────────────────────────────────────
    turnForfeited = false;
    final enhanceTarget = _findEnhancementTarget(words, enhancerOwner: 0);

    if (enhanceTarget != null) {
      final err = _validateEnhancement(enhanceTarget, enhancerOwner: 0);
      if (err != null) return err;
    }

    final invalid = words.where((w) => !_validator.isValid(w.word)).toList();
    if (invalid.isNotEmpty) {
      if (enhanceTarget != null) {
        // Risk: geçersiz geliştirme denemesi → tur iptali
        turnForfeited = true;
        lastSuggestion = null;
        recallAll();
        highlightedCells = {};
        lastMoveCells = {};
        lastMoveWords = const [];
        message = L.turnForfeitedMsg;
        notifyListeners();
        _doAiTurn();
        return null;
      }
      lastSuggestion = _validator.suggestWord(invalid.first.word);
      notifyListeners();
      return L.invalidWords(invalid.map((w) => w.word).join(', '));
    }

    lastSuggestion = null;
    lastStealResult = null;
    lastFailedSteal = null;
    stolenNewCells = {};

    int earned = GameScoreService.totalScore(words);

    // ── Çalma modu aktifse → çalma denemesi olarak değerlendir ───
    if (isInStealMode) {
      isInStealMode = false; // modu her halükarda kapat

      final extWord = enhanceTarget != null
          ? _getExtendingWord(words, enhanceTarget)
          : null;

      final StealResult steal;
      if (enhanceTarget != null && extWord != null) {
        steal = _stealSvc.canSteal(
          enhanceTarget.word,
          extWord.word,
          currentSteals: enhanceTarget.enhanceCount,
        );
      } else {
        steal = StealResult.fail('', '', L.noStealTarget);
      }

      if (steal.success) {
        // ── Başarılı çalma ──────────────────────────────────
        playerStealsLeft--;
        lastStealResult = steal;
        earned += steal.bonusScore;
        stolenNewCells =
            extWord != null ? _cellsForIndices(extWord, steal.newIndices) : {};
        if (enhanceTarget != null) {
          playerEnhanceCount++;
          _playerEnhancedLastTurn = true;
        }
        message = L.wordStolen(earned);
      } else {
        // ── Başarısız çalma: ceza uygula ─────────────────────
        playerStealsLeft--;
        playerScore = (playerScore - stealPenaltyPoints).clamp(0, 999999);
        lastFailedSteal = steal;
        turnForfeited = true;
        recallAll();
        message = L.stealFailed;
        notifyListeners();
        _doAiTurn();
        return null;
      }
    } else if (enhanceTarget != null) {
      // ── Normal geliştirme (çalma modu kapalıyken) ─────────
      final extWord = _getExtendingWord(words, enhanceTarget);
      if (extWord != null) {
        final steal = _stealSvc.canSteal(
          enhanceTarget.word,
          extWord.word,
          currentSteals: enhanceTarget.enhanceCount,
        );
        if (steal.success) {
          lastStealResult = steal;
          earned += steal.bonusScore;
          stolenNewCells = _cellsForIndices(extWord, steal.newIndices);
          message = L.wordStolen(earned);
        }
      }
      if (lastStealResult == null) {
        earned += _calcEnhancementBonus(enhanceTarget, words, enhancerOwner: 0);
        message = L.enhanced(earned);
      }
      playerEnhanceCount++;
      _playerEnhancedLastTurn = true;
    } else {
      _playerEnhancedLastTurn = false;
      message = '+$earned ${L.points}!';
    }

    final placedCellKeys = pending.map((c) => '${c.row}:${c.column}').toSet();

    playerScore += earned;
    AchievementService.instance.onWordPlayed(earned);
    board = board.commitPending();
    _setLastMoveFromPlacedCells(placedCellKeys, fallbackWords: words);
    _recordWords(words,
        owner: 0, enhanceTarget: enhanceTarget, enhancerOwner: 0);
    _refillRack(playerRack);
    _ensureRackPlayable(playerRack);
    _turnNumber++;
    _refreshPendingWords();
    notifyListeners();

    if (_bag.isEmpty && playerRack.isEmpty) {
      phase = GamePhase.gameOver;
      notifyListeners();
      _onGameOver();
      return null;
    }

    _doAiTurn();
    return null;
  }

  // ─── AI turu ─────────────────────────────────────────────────────

  void _doAiTurn() {
    phase = GamePhase.aiTurn;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 800), () {
      final move = _ai.findBestMove(board, aiRack, difficulty: aiDifficulty);
      if (move != null) {
        for (final p in move.placements) {
          board = board.placePending(p.row, p.col, p.tile.letter, p.tile.id);
          aiRack.removeWhere((t) => t.id == p.tile.id);
        }
        final aiWords = _scorer.calculateNewWords(board);
        final placedCellKeys = board.pendingCells
            .map((cell) => '${cell.row}:${cell.column}')
            .toSet();
        aiScore += move.score;
        board = board.commitPending();
        _setLastMoveFromPlacedCells(placedCellKeys, fallbackWords: aiWords);
        _recordWords(aiWords, owner: 1, enhanceTarget: null, enhancerOwner: 1);
        _refillRack(aiRack);
      } else {
        totalPassCount++;
      }

      _turnNumber++;
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
      if (phase == GamePhase.gameOver) {
        _onGameOver();
      } else {
        _startTurnTimer();
      }
    });
  }

  // ─── Geliştirme yardımcıları ──────────────────────────────────────

  /// Oynatılan kelimeler arasında rakibe ait bir kelimeyi uzatan var mı?
  PlacedWordRecord? _findEnhancementTarget(
    List<PlacedWord> words, {
    required int enhancerOwner,
  }) {
    for (final newWord in words) {
      if (newWord.cells.length < 2) continue;
      final hasPending = newWord.cells.any((c) => c.isPending);
      final hasLocked = newWord.cells.any((c) => c.isLocked);
      if (!hasPending || !hasLocked) continue;

      final isH = newWord.cells.first.row == newWord.cells.last.row;
      final fixedLine =
          isH ? newWord.cells.first.row : newWord.cells.first.column;
      final positions =
          newWord.cells.map((c) => isH ? c.column : c.row).toList()..sort();
      final newStart = positions.first;
      final newEnd = positions.last;

      for (final record in _wordHistory) {
        if (record.owner == enhancerOwner) continue;
        if (record.isExtendedBy(
          horizontal: isH,
          line: fixedLine,
          newStart: newStart,
          newEnd: newEnd,
        )) {
          return record;
        }
      }
    }
    return null;
  }

  /// Geliştirme kurallarını kontrol eder; hata mesajı ya da null döner.
  String? _validateEnhancement(
    PlacedWordRecord target, {
    required int enhancerOwner,
  }) {
    final count = enhancerOwner == 0 ? playerEnhanceCount : 0;
    final lastTurn = enhancerOwner == 0 ? _playerEnhancedLastTurn : false;

    if (count >= maxEnhancesPerGame) return L.noEnhanceLeft;
    if (lastTurn) return L.consecutiveEnhanceBlocked;
    if (target.enhanceCount >= maxEnhancesPerWord) return L.wordMaxEnhanced;
    if (_turnNumber - target.turnPlaced <= 1) return L.wordProtected;

    return null;
  }

  // ── Çalma yardımcıları ────────────────────────────────────────────

  /// [words] içinden [target]'ı genişleten `PlacedWord`'ü döndürür.
  PlacedWord? _getExtendingWord(
      List<PlacedWord> words, PlacedWordRecord target) {
    final isH = target.isHorizontal;
    for (final w in words) {
      if (w.cells.length < 2) continue;
      final wIsH = w.cells.first.row == w.cells.last.row;
      if (wIsH != isH) continue;
      final fixedLine = isH ? w.cells.first.row : w.cells.first.column;
      if (fixedLine != target.fixedLine) continue;
      final positions = w.cells.map((c) => isH ? c.column : c.row).toList()
        ..sort();
      if (target.isExtendedBy(
        horizontal: isH,
        line: fixedLine,
        newStart: positions.first,
        newEnd: positions.last,
      )) {
        return w;
      }
    }
    return null;
  }

  /// [newIndices] ile verilen harf indekslerini `'row:col'` hücre anahtarlarına çevirir.
  Set<String> _cellsForIndices(PlacedWord word, List<int> newIndices) {
    final result = <String>{};
    for (final idx in newIndices) {
      if (idx < word.cells.length) {
        final c = word.cells[idx];
        result.add('${c.row}:${c.column}');
      }
    }
    return result;
  }

  /// Geliştirme bonusunu hesaplar.
  int _calcEnhancementBonus(
    PlacedWordRecord target,
    List<PlacedWord> words, {
    required int enhancerOwner,
  }) {
    final isH = target.isHorizontal;

    PlacedWord? extWord;
    for (final w in words) {
      if (w.cells.length < 2) continue;
      final wIsH = w.cells.first.row == w.cells.last.row;
      if (wIsH != isH) continue;
      final fixedLine = isH ? w.cells.first.row : w.cells.first.column;
      if (fixedLine != target.fixedLine) continue;
      final positions = w.cells.map((c) => isH ? c.column : c.row).toList()
        ..sort();
      if (target.isExtendedBy(
        horizontal: isH,
        line: fixedLine,
        newStart: positions.first,
        newEnd: positions.last,
      )) {
        extWord = w;
        break;
      }
    }
    if (extWord == null) return 0;

    final addedLetters = extWord.word.length - target.word.length;
    int bonus = (target.originalScore * enhanceBonusRate).round();
    bonus += addedLetters * bonusPerAddedLetter;

    // Geri çalma bonusu: orijinal sahibi geliştiren ise +%25
    final isReclaim =
        target.originalOwner == enhancerOwner && target.owner != enhancerOwner;
    if (isReclaim) bonus = (bonus * (1 + reclaimBonusRate)).round();

    return bonus;
  }

  /// Yeni kelimeleri geçmişe kaydeder; genişletme varsa metadata aktarır.
  void _recordWords(
    List<PlacedWord> words, {
    required int owner,
    required PlacedWordRecord? enhanceTarget,
    required int enhancerOwner,
  }) {
    for (final w in words) {
      if (w.cells.length < 2) continue;
      final isH = w.cells.first.row == w.cells.last.row;
      final fixedLine = isH ? w.cells.first.row : w.cells.first.column;
      final positions = w.cells.map((c) => isH ? c.column : c.row).toList()
        ..sort();
      final startPos = positions.first;
      final endPos = positions.last;

      // Bu kelimenin kapsamını içeren eski kaydı bul ve çıkar
      PlacedWordRecord? extended;
      _wordHistory.removeWhere((r) {
        if (r.isExtendedBy(
          horizontal: isH,
          line: fixedLine,
          newStart: startPos,
          newEnd: endPos,
        )) {
          extended = r;
          return true;
        }
        return false;
      });

      final isEnhancement =
          extended != null && identical(extended, enhanceTarget);

      _wordHistory.add(PlacedWordRecord(
        word: w.word,
        isHorizontal: isH,
        fixedLine: fixedLine,
        startPos: startPos,
        endPos: endPos,
        originalScore: w.score,
        originalOwner: extended?.originalOwner ?? owner,
        owner: owner,
        turnPlaced: _turnNumber,
        enhanceCount: isEnhancement
            ? (extended!.enhanceCount + 1)
            : (extended?.enhanceCount ?? 0),
        lastEnhancedBy:
            isEnhancement ? enhancerOwner : extended?.lastEnhancedBy,
      ));

      // Geliştirilen hücreler için vurgulama (oyuncu için)
      if (isEnhancement && enhancerOwner == 0) {
        highlightedCells = w.cells.map((c) => '${c.row}:${c.column}').toSet();
      }
    }
  }

  void _setLastMove(List<PlacedWord> words) {
    final wordRecords = words
        .where((w) => w.cells.length >= 2)
        .map((w) => (
              word: w.word,
              cells: w.cells.map((c) => '${c.row}:${c.column}').toSet(),
            ))
        .toList(growable: false);

    lastMoveWords = wordRecords;
    lastMoveCells = {
      for (final record in wordRecords) ...record.cells,
    };
  }

  void _setLastMoveFromPlacedCells(
    Set<String> placedCellKeys, {
    required List<PlacedWord> fallbackWords,
  }) {
    final wordRecords = <({String word, Set<String> cells})>[];
    final seen = <String>{};

    void addWord(List<BoardCell> cells, bool horizontal) {
      if (cells.length < 2) return;
      final cellKeys = cells.map((c) => '${c.row}:${c.column}').toSet();
      if (!cellKeys.any(placedCellKeys.contains)) return;
      final word = cells.map((c) => c.letter).join();
      final key =
          '${horizontal ? 'H' : 'V'}:${cells.first.row}:${cells.first.column}:$word';
      if (!seen.add(key)) return;
      wordRecords.add((word: word, cells: cellKeys));
    }

    for (final key in placedCellKeys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final row = int.tryParse(parts[0]);
      final col = int.tryParse(parts[1]);
      if (row == null || col == null) continue;
      if (row < 0 ||
          row >= WordBoard.size ||
          col < 0 ||
          col >= WordBoard.size) {
        continue;
      }
      addWord(_collectWordCells(row, col, horizontal: true), true);
      addWord(_collectWordCells(row, col, horizontal: false), false);
    }

    wordRecords.sort((a, b) {
      final aStart = _wordStart(a.cells);
      final bStart = _wordStart(b.cells);
      final rowCompare = aStart.row.compareTo(bStart.row);
      if (rowCompare != 0) return rowCompare;
      return aStart.col.compareTo(bStart.col);
    });

    if (wordRecords.isEmpty) {
      _setLastMove(fallbackWords);
      return;
    }
    lastMoveWords = wordRecords;
    lastMoveCells = {
      for (final record in wordRecords) ...record.cells,
    };
  }

  List<BoardCell> _collectWordCells(
    int row,
    int col, {
    required bool horizontal,
  }) {
    var r = row;
    var c = col;
    while (horizontal ? c > 0 : r > 0) {
      final previous =
          board.cellAt(horizontal ? r : r - 1, horizontal ? c - 1 : c);
      if (!previous.hasLetter) break;
      if (horizontal) {
        c--;
      } else {
        r--;
      }
    }

    final cells = <BoardCell>[];
    while (r < WordBoard.size && c < WordBoard.size) {
      final cell = board.cellAt(r, c);
      if (!cell.hasLetter) break;
      cells.add(cell);
      if (horizontal) {
        c++;
      } else {
        r++;
      }
    }
    return cells;
  }

  ({int row, int col}) _wordStart(Set<String> cells) {
    final points = cells.map((key) {
      final parts = key.split(':');
      return (
        row: int.tryParse(parts.first) ?? WordBoard.centerIndex,
        col: int.tryParse(parts.last) ?? WordBoard.centerIndex,
      );
    }).toList();
    return points.reduce((a, b) {
      if (a.row != b.row) return a.row < b.row ? a : b;
      return a.col <= b.col ? a : b;
    });
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────

  bool _touchesLocked(List cells) {
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final cell in cells) {
      for (final d in dirs) {
        final r = cell.row + d.$1;
        final c = cell.column + d.$2;
        if (r < 0 || r >= WordBoard.size || c < 0 || c >= WordBoard.size) {
          continue;
        }
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

  // Kurmancî sesli harfleri (NFC, uppercase)
  static const _vowels = {'A', 'E', 'Ê', 'I', 'Î', 'O', 'U', 'Û'};

  /// Player'ın rack'ini doldurduktan sonra playability garantisi.
  ///
  /// İki kuralı birden uygular:
  ///   1) Vowel balance: 7 harflik rack'ta 2-5 sesli olmalı (0 veya 6+ → swap)
  ///   2) Word formability: rack veya rack+anchor ile ≥1 geçerli kelime
  /// Akıllı swap: önce duplicate'i sonra rack'a en az katkı sağlayanı atar.
  /// Max 6 takas — agresif ama bag tükenebilir.
  void _ensureRackPlayable(List<GameTile> rack) {
    const maxSwaps = 6;
    for (var i = 0; i < maxSwaps; i++) {
      if (_bag.remaining == 0) return;
      final balanceIssue = _vowelBalanceIssue(rack);
      final formable = _canMakeAnyWord(rack);
      if (balanceIssue == null && formable) return;

      // Hedef tile'ı seç: dengesizlik varsa fazla olan tipten, yoksa en sık duplicate
      int swapIdx;
      if (balanceIssue == 'too_many_vowels') {
        swapIdx = _findIndex(rack, (t) => _vowels.contains(t.letter)) ??
            (rack.length - 1);
      } else if (balanceIssue == 'too_few_vowels') {
        swapIdx = _findIndex(rack, (t) => !_vowels.contains(t.letter)) ??
            (rack.length - 1);
      } else {
        swapIdx = _mostDuplicateIndex(rack);
      }

      final swapped = rack.removeAt(swapIdx);
      final replacement = _bag.drawOne();
      if (replacement == null) {
        rack.add(swapped);
        return;
      }
      rack.add(replacement);
      _bag.returnTiles([swapped]);
    }
  }

  /// Sesli harf dengesi. 0 veya 6+ sesli problem; 2-5 normal.
  /// Returns: 'too_few_vowels', 'too_many_vowels', or null.
  String? _vowelBalanceIssue(List<GameTile> rack) {
    final vowels = rack.where((t) => _vowels.contains(t.letter)).length;
    if (vowels < 2) return 'too_few_vowels';
    if (vowels >= 6) return 'too_many_vowels';
    return null;
  }

  int? _findIndex(List<GameTile> rack, bool Function(GameTile) test) {
    for (var i = 0; i < rack.length; i++) {
      if (test(rack[i])) return i;
    }
    return null;
  }

  /// Rack'te en çok tekrar eden harfin ilk index'i — duplicate atmak için.
  int _mostDuplicateIndex(List<GameTile> rack) {
    final counts = <String, int>{};
    for (final t in rack) {
      counts[t.letter] = (counts[t.letter] ?? 0) + 1;
    }
    String? bestLetter;
    var bestCount = 1;
    counts.forEach((k, v) {
      if (v > bestCount) {
        bestCount = v;
        bestLetter = k;
      }
    });
    if (bestLetter == null) return rack.length - 1;
    return rack.indexWhere((t) => t.letter == bestLetter);
  }

  /// Verilen rack ile (tahta anchorları dahil) en az 1 geçerli kelime
  /// oluşturulabilir mi? Erken-çıkış `canFormAny` kullanır (findFormable'ın
  /// ~100x hızlı versiyonu). Kısa kelimelerle sınırlandırılır (3-5 harf):
  /// "rack tıkanmamış mı" kontrolü için 7-harf joker aramaya gerek yok.
  bool _canMakeAnyWord(List<GameTile> rack) {
    final rackChars = rack.map((t) => t.letter).toList();
    const minLen = 3;
    const maxLen = 5;

    // 1) Sadece rack
    if (_validator.canFormAny(rackChars,
        minLength: minLen, maxLength: maxLen)) {
      return true;
    }
    // 2) Rack + tahtadaki her benzersiz harf (1 anchor combo)
    final boardChars = <String>{};
    for (final cell in board.cells) {
      final l = cell.letter;
      if (l.isNotEmpty) boardChars.add(l);
    }
    for (final ch in boardChars) {
      if (_validator.canFormAny([...rackChars, ch],
          minLength: minLen, maxLength: maxLen)) {
        return true;
      }
    }
    // 3) Rack + 2 anchor — tahta dolu durumlar için son çare
    final chars = boardChars.toList();
    for (var a = 0; a < chars.length; a++) {
      for (var b = a; b < chars.length; b++) {
        if (_validator.canFormAny([...rackChars, chars[a], chars[b]],
            minLength: minLen, maxLength: maxLen)) {
          return true;
        }
      }
    }
    return false;
  }

  void _onGameOver() {
    _countdownTimer?.cancel();
    if (playerScore > aiScore) {
      AchievementService.instance.onGameWon();
    }
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    FirestoreService.instance.saveGameResult(
      uid: uid,
      playerScore: playerScore,
      aiScore: aiScore,
      won: playerScore > aiScore,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
