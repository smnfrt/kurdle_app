import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/controllers/board_touch_controller.dart';
import 'package:kurdle_app/models/board_cell.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/board_layout_service.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/services/game_score_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/services/scoring_service.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/services/word_steal_service.dart';
import 'package:kurdle_app/services/word_validator_service.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/wordlist_loader.dart';
import 'package:kurdle_app/widgets/letter_rack_widget.dart';
import 'package:kurdle_app/widgets/scrabble_board_widget.dart';

const _kBg = Color(0xFF0D1520);
const _kTopStart = Color(0xFF1E2A3A);
const _kCard = Color(0xFF162030);
const _kPrimary = Color(0xFF4CAF50);
const _kBlue = Color(0xFF64B5F6);
const _kError = Color(0xFFFF6B6B);
const _kInitialBoardZoom = 2.05;

class FriendGameScreen extends StatefulWidget {
  final String roomCode;
  final String myUid;

  const FriendGameScreen({
    super.key,
    required this.roomCode,
    required this.myUid,
  });

  @override
  State<FriendGameScreen> createState() => _FriendGameScreenState();
}

class _FriendGameScreenState extends State<FriendGameScreen>
    with TickerProviderStateMixin {
  // ── Services ─────────────────────────────────────────────────────
  WordValidatorService? _validator;
  GameScoreService? _scorer;
  static const _stealSvc = WordStealService();

  // ── Firestore ─────────────────────────────────────────────────────
  MultiplayerRoom? _room;
  StreamSubscription<MultiplayerRoom?>? _sub;

  // ── Local game state ─────────────────────────────────────────────
  WordBoard _localBoard = BoardLayoutService.createClassicLayout();
  List<GameTile> _myRack = [];
  GameTile? _selectedTile;
  String _error = '';
  bool _submitting = false;
  bool _loading = true;

  // ── Zoom / pan ────────────────────────────────────────────────────
  final _zoomController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late final BoardTouchController _touchCtrl;
  bool _initialBoardZoomApplied = false;
  bool _initialBoardZoomScheduled = false;

  // ── Steal ─────────────────────────────────────────────────────────
  bool _isInStealMode = false;

  // ── Pending words ─────────────────────────────────────────────────
  List<({String word, int score, bool valid})> _pendingWords = [];

  // ── Game over ─────────────────────────────────────────────────────
  bool _gameOverShown = false;

  // ── FX: turn banner / error shake ─────────────────────────────────
  AnimationController? _turnBannerCtrl;
  String _turnBannerText = '';
  AnimationController? _errorShakeCtrl;
  int _errorTick = 0;

  // Skor celebration particle burst
  int _celebrateTick = 0;
  int _celebrateScore = 0;
  // Streak: ardışık 20+ puanlık hamleler için kombo göstergesi
  int _streak = 0;
  int _streakBannerTick = 0;

  @override
  void initState() {
    super.initState();
    _touchCtrl = BoardTouchController(
      transformCtrl: _zoomController,
      vsync: this,
      onPanChanged: (enabled) {
        if (mounted) setState(() {});
      },
    );
    _zoomController.addListener(_touchCtrl.onTransformChanged);
    _turnBannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _errorShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _turnBannerCtrl?.dispose();
    _errorShakeCtrl?.dispose();
    _zoomController.removeListener(_touchCtrl.onTransformChanged);
    _touchCtrl.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  Future<void> _showTurnBanner(String text) async {
    if (!mounted || _turnBannerCtrl == null) return;
    setState(() => _turnBannerText = text);
    await _turnBannerCtrl!.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || _turnBannerCtrl == null) return;
    await _turnBannerCtrl!.reverse();
    if (mounted) setState(() => _turnBannerText = '');
  }

  void _setError(String msg) {
    setState(() {
      _error = msg;
      _errorTick++;
    });
    if (msg.isNotEmpty && _errorShakeCtrl != null) {
      _errorShakeCtrl!.forward(from: 0);
    }
  }

  // ── Double-tap zoom ───────────────────────────────────────────────

  void _handleDoubleTap() {
    if (_touchCtrl.panEnabled) {
      _zoomController.value = Matrix4.identity();
      return;
    }
    final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _zoomController.value = Matrix4.identity()
      ..translate(-pos.dx * (scale - 1), -pos.dy * (scale - 1))
      ..scale(scale);
  }

  void _scheduleInitialBoardZoom() {
    if (_initialBoardZoomApplied ||
        _initialBoardZoomScheduled ||
        _touchCtrl.viewportSize == Size.zero) {
      return;
    }
    _initialBoardZoomScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialBoardZoomScheduled = false;
      if (!mounted || _initialBoardZoomApplied) return;
      _touchCtrl.zoomToBoardCenter(scale: _kInitialBoardZoom);
      _initialBoardZoomApplied = true;
    });
  }

  // ── Pending word preview ──────────────────────────────────────────

  void _computePendingWords() {
    if (_scorer == null || _validator == null) return;
    final words = _scorer!.calculateNewWords(_localBoard);
    _pendingWords = words
        .map((w) =>
            (word: w.word, score: w.score, valid: _validator!.isValid(w.word)))
        .toList();
  }

  List<Map<String, dynamic>> _serializeMoveWords(List<PlacedWord> words) {
    return words
        .where((w) => w.cells.length >= 2)
        .map((w) => {
              'word': w.word,
              'cells': w.cells.map((c) => '${c.row}:${c.column}').toList(),
            })
        .toList(growable: false);
  }

  List<String> _moveWordCells(List<Map<String, dynamic>> words) {
    return words
        .expand((w) => List<String>.from(w['cells'] ?? const []))
        .toSet()
        .toList(growable: false);
  }

  List<BoardMeaningWord> _meaningWordsFromRoom(MultiplayerRoom room) {
    return room.lastMoveWords
        .map((w) => (
              word: (w['word'] as String? ?? '').toUpperCase(),
              cells: List<String>.from(w['cells'] ?? const []).toSet(),
            ))
        .where((w) => w.word.isNotEmpty && w.cells.isNotEmpty)
        .toList(growable: false);
  }

  void _showWordMeanings(List<String> words) async {
    final seen = <String>{};
    final uniqueWords = <String>[
      for (final word in words)
        if (word.trim().isNotEmpty && seen.add(word.trim().toUpperCase()))
          word.trim()
    ];
    if (uniqueWords.isEmpty) return;
    HapticFeedback.selectionClick();

    final entries = ValueNotifier<List<_MeaningTabEntry>>(
      uniqueWords
          .map(
              (word) => _MeaningTabEntry(word: word, meaning: L.meaningLoading))
          .toList(growable: false),
    );
    var dialogOpen = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'word-meaning',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) =>
          ValueListenableBuilder<List<_MeaningTabEntry>>(
        valueListenable: entries,
        builder: (_, value, ___) => _WordMeaningBubble(
          entries: value,
          onDismiss: () =>
              Navigator.of(dialogContext, rootNavigator: true).maybePop(),
        ),
      ),
    ).whenComplete(() {
      dialogOpen = false;
      entries.dispose();
    });

    try {
      final results = await Future.wait(uniqueWords.map(
        (word) => FerhengService.instance.lookupMeaning(
          word,
          acceptedInGame: true,
        ),
      ));
      if (!mounted || !dialogOpen) return;
      entries.value = results.map((result) {
        final text = result.displayGameMeaning().trim();
        return _MeaningTabEntry(
          word: result.displayWord,
          meaning: text.isEmpty ? L.dictionaryEntryMissingMeaning : text,
        );
      }).toList(growable: false);
    } catch (e) {
      debugPrint('[dictionary_error] $e');
      if (!mounted || !dialogOpen) return;
      entries.value = uniqueWords
          .map((word) =>
              _MeaningTabEntry(word: word, meaning: L.dictionaryWordNotFound))
          .toList(growable: false);
    }
  }

  // ── Init ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    final config = LanguageConfig.current;
    final allWords = await WordlistLoader.loadAssets(config.wordAssets);
    _validator = WordValidatorService(allWords);
    _scorer = GameScoreService(ScoringService(config.letterPoints));

    _sub = MultiplayerService.instance
        .roomStream(widget.roomCode)
        .listen(_onRoomUpdate);
  }

  void _onRoomUpdate(MultiplayerRoom? room) {
    if (room == null || !mounted) return;
    final prev = _room;
    setState(() {
      _room = room;
      _loading = false;
    });

    // Sync local state when my turn starts (or on first load)
    final isMyTurn = room.currentTurnUid == widget.myUid;
    final wasMyTurn = prev?.currentTurnUid == widget.myUid;

    if (isMyTurn && !wasMyTurn) {
      // Opponent just submitted — refresh board and rack
      _syncFromRoom(room);
      // Sıra bana geldi: banner + ses
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTurnBanner(L.turnIsYours);
      });
      HapticFeedback.mediumImpact();
    } else if (prev == null) {
      // First load
      _syncFromRoom(room);
    } else if (!isMyTurn) {
      // Show opponent's committed board
      setState(() {
        _localBoard = room.toWordBoard();
      });
    }

    if (room.status == 'finished' && !_gameOverShown) {
      _gameOverShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showGameOver(room));
    }
  }

  void _syncFromRoom(MultiplayerRoom room) {
    final isHost = room.hostUid == widget.myUid;
    final letters = isHost ? room.hostRack : room.guestRack;
    setState(() {
      _localBoard = room.toWordBoard();
      _myRack = MultiplayerRoom.toRack(letters);
      _selectedTile = null;
      _pendingWords = [];
      _isInStealMode = false;
      _error = '';
    });
  }

  // ── Board interactions ────────────────────────────────────────────

  bool get _isMyTurn => _room?.currentTurnUid == widget.myUid;

  void _onTileTap(GameTile tile) {
    if (!_isMyTurn || _submitting) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTile = _selectedTile?.id == tile.id ? null : tile);
  }

  void _onCellTap(int row, int col) {
    if (!_isMyTurn || _submitting) return;
    final cell = _localBoard.cellAt(row, col);

    if (cell.isPending) {
      // Recall tile
      final tile = GameTile(id: cell.tileId!, letter: cell.letter);
      setState(() {
        _localBoard = _localBoard.clearLetter(row, col);
        _myRack.add(tile);
        _selectedTile = null;
        _error = '';
        _computePendingWords();
      });
      HapticFeedback.selectionClick();
      return;
    }

    if (cell.isLocked || _selectedTile == null) return;

    setState(() {
      _localBoard = _localBoard.placePending(
          row, col, _selectedTile!.letter, _selectedTile!.id);
      _myRack.removeWhere((t) => t.id == _selectedTile!.id);
      _selectedTile = null;
      _error = '';
      _computePendingWords();
    });
    HapticFeedback.selectionClick();
    SoundService.instance.play(SFX.tilePlace);
  }

  void _onTileDrop(int row, int col, GameTile tile) {
    if (!_isMyTurn || _submitting) return;
    final cell = _localBoard.cellAt(row, col);
    if (cell.hasLetter) return;
    setState(() {
      _localBoard = _localBoard.placePending(row, col, tile.letter, tile.id);
      _myRack.removeWhere((t) => t.id == tile.id);
      _selectedTile = null;
      _error = '';
      _computePendingWords();
    });
    HapticFeedback.selectionClick();
    SoundService.instance.play(SFX.tilePlace);
  }

  void _recallAll() {
    final pending = _localBoard.pendingCells;
    final recalled =
        pending.map((c) => GameTile(id: c.tileId!, letter: c.letter)).toList();
    setState(() {
      _localBoard = _localBoard.clearPending();
      _myRack.addAll(recalled);
      _selectedTile = null;
      _pendingWords = [];
      _error = '';
    });
    if (recalled.isNotEmpty) HapticFeedback.lightImpact();
  }

  // ── Steal helpers ─────────────────────────────────────────────────

  int get _myStealsLeft {
    if (_room == null) return 0;
    return _room!.hostUid == widget.myUid
        ? _room!.hostStealsLeft
        : _room!.guestStealsLeft;
  }

  StealResult? _detectSteal(List<PlacedWord> words) {
    for (final word in words) {
      final lockedLetters =
          word.cells.where((c) => c.isLocked).map((c) => c.letter).join();
      if (lockedLetters.isEmpty) continue;
      final steal = _stealSvc.canSteal(
        lockedLetters,
        word.word,
        isValidWord: _validator!.isValid,
      );
      if (steal.success) return steal;
    }
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_isMyTurn || _submitting || _room == null) return;

    final pending = _localBoard.pendingCells;
    if (pending.isEmpty) {
      _setError(L.placeTile);
      return;
    }

    // Placement validity
    if (!_isPlacementValid(pending)) {
      _setError(L.sameRowCol);
      return;
    }

    // First move must cover center
    final isFirst = _localBoard.cells.every((c) => !c.isLocked);
    if (isFirst) {
      const cx = WordBoard.centerIndex;
      if (!pending.any((c) => c.row == cx && c.column == cx)) {
        _setError(L.centerFirst);
        return;
      }
    }

    // Must touch locked cells after first move
    if (!isFirst && !_touchesLocked(pending)) {
      _setError(L.touchLocked);
      return;
    }

    final words = _scorer!.calculateNewWords(_localBoard);
    if (words.isEmpty) {
      _setError(L.noWord);
      return;
    }

    // Çal modu: steal denemesi
    if (_isInStealMode) {
      final steal = _detectSteal(words);
      if (steal == null || _myStealsLeft <= 0) {
        // Başarısız çalma — ceza
        const penalty = 5;
        _isInStealMode = false;
        _recallAll();
        setState(() => _submitting = true);
        try {
          final room = _room!;
          final isHost = room.hostUid == widget.myUid;
          final myCurrentScore = isHost ? room.hostScore : room.guestScore;
          final penaltyScore = (myCurrentScore - penalty).clamp(0, 999999);
          final newSteals = (_myStealsLeft - 1).clamp(0, 2);
          final oppUid = isHost ? (room.guestUid ?? '') : room.hostUid;
          final newBoard = _localBoard.commitPending();
          final bag = List<String>.from(room.bagLetters);
          final rack = List<String>.from(_myRack.map((t) => t.letter));
          SoundService.instance.play(SFX.wordInvalid);
          HapticFeedback.heavyImpact();
          await MultiplayerService.instance.submitMove(
            roomCode: widget.roomCode,
            isHost: isHost,
            myScore: penaltyScore,
            myNewRack: rack,
            newBagLetters: bag,
            newBoardState: MultiplayerService.serializeBoard(newBoard),
            nextTurnUid: oppUid,
            isGameOver: false,
            winner: null,
            myNewStealsLeft: newSteals,
            moveScore: -penalty,
          );
        } catch (e) {
          if (mounted) {
            setState(() => _error = L.errorPrefix(_cleanError(e)));
          }
        }
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = L.stealFailedPenalty(penalty);
          });
        }
        return;
      }
      // Başarılı çalma — devam et (steal.bonusScore eklenir aşağıda)
    }

    if (!_isInStealMode) {
      final invalid = words.where((w) => !_validator!.isValid(w.word)).toList();
      if (invalid.isNotEmpty) {
        _setError(L.invalidWords(invalid.map((w) => w.word).join(', ')));
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = '';
    });

    try {
      final room = _room!;
      final isHost = room.hostUid == widget.myUid;
      int score = GameScoreService.totalScore(words);

      // Çalma bonusu
      int? newStealsLeft;
      if (_isInStealMode) {
        final steal = _detectSteal(words)!;
        score += steal.bonusScore;
        newStealsLeft = _myStealsLeft - 1;
        _isInStealMode = false;
        SoundService.instance.play(SFX.win);
        HapticFeedback.heavyImpact();
      }

      final myCurrentScore = isHost ? room.hostScore : room.guestScore;
      final myNewScore = myCurrentScore + score;
      final lastMoveWords = _serializeMoveWords(words);
      final lastMoveCells = _moveWordCells(lastMoveWords);

      // Commit board
      final newBoard = _localBoard.commitPending();
      final newBoardState = MultiplayerService.serializeBoard(newBoard);

      // Refill rack from bag
      final bag = List<String>.from(room.bagLetters);
      final rack = List<String>.from(_myRack.map((t) => t.letter));
      final draw = bag.take(7 - rack.length).toList();
      bag.removeRange(0, draw.length);
      rack.addAll(draw);

      // Game over?
      final opponentUid = isHost ? (room.guestUid ?? '') : room.hostUid;
      final isGameOver = bag.isEmpty && rack.isEmpty;
      String? winner;
      if (isGameOver) {
        final oppScore = isHost ? room.guestScore : room.hostScore;
        winner = myNewScore > oppScore
            ? (isHost ? 'host' : 'guest')
            : myNewScore < oppScore
                ? (isHost ? 'guest' : 'host')
                : 'draw';
      }

      SoundService.instance.play(SFX.wordValid);
      SoundService.instance.play(SFX.scoreUp);
      HapticFeedback.lightImpact();

      await MultiplayerService.instance.submitMove(
        roomCode: widget.roomCode,
        isHost: isHost,
        myScore: myNewScore,
        myNewRack: rack,
        newBagLetters: bag,
        newBoardState: newBoardState,
        nextTurnUid: opponentUid,
        isGameOver: isGameOver,
        winner: winner,
        myNewStealsLeft: newStealsLeft,
        moveScore: score,
        lastMoveWords: lastMoveWords,
        lastMoveCells: lastMoveCells,
      );
      if (mounted) {
        setState(() {
          _myRack = MultiplayerRoom.toRack(rack);
          _pendingWords = [];
          _selectedTile = null;
          if (score > 0) {
            _celebrateTick++;
            _celebrateScore = score;
            // Streak: 20+ puanlı hamleler ardışık gelirse kombo
            if (score >= 20) {
              _streak++;
              if (_streak >= 2) {
                _streakBannerTick++;
                HapticFeedback.heavyImpact();
              }
            } else {
              _streak = 0;
            }
          } else {
            _streak = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = L.errorPrefix(_cleanError(e)));
      }
    }

    if (mounted) setState(() => _submitting = false);
  }

  // ── Pass ─────────────────────────────────────────────────────────

  Future<void> _pass() async {
    if (!_isMyTurn || _submitting || _room == null) return;
    _recallAll();
    setState(() => _submitting = true);
    try {
      final room = _room!;
      final isHost = room.hostUid == widget.myUid;
      final oppUid = isHost ? (room.guestUid ?? '') : room.hostUid;
      await MultiplayerService.instance.passTurn(
        roomCode: widget.roomCode,
        nextTurnUid: oppUid,
        currentPassCount: room.passCount,
        hostScore: room.hostScore,
        guestScore: room.guestScore,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = L.errorPrefix(_cleanError(e)));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  // ── Game over ─────────────────────────────────────────────────────

  void _showGameOver(MultiplayerRoom room) {
    if (!mounted) return;
    final isHost = room.hostUid == widget.myUid;
    final myScore = isHost ? room.hostScore : room.guestScore;
    final oppScore = isHost ? room.guestScore : room.hostScore;
    final oppName =
        isHost ? (room.guestName ?? L.opponentFallback) : room.hostName;

    final iWon = room.winner == (isHost ? 'host' : 'guest');
    final isDraw = room.winner == 'draw';

    SoundService.instance.play(iWon ? SFX.win : SFX.lose);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final entry = Curves.easeOutBack.transform(anim.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Center(
            child: Transform.scale(
              scale: 0.85 + 0.15 * entry,
              child: _GameOverCard(
                iWon: iWon,
                isDraw: isDraw,
                myScore: myScore,
                oppScore: oppScore,
                oppName: oppName,
                onClose: () {
                  Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Validation helpers ────────────────────────────────────────────

  bool _isPlacementValid(List<BoardCell> pending) {
    if (pending.length == 1) return true;
    final sameRow = pending.every((c) => c.row == pending.first.row);
    final sameCol = pending.every((c) => c.column == pending.first.column);
    if (!sameRow && !sameCol) return false;
    if (sameRow) {
      final cols = pending.map((c) => c.column).toList()..sort();
      for (var i = cols.first; i <= cols.last; i++) {
        if (!_localBoard.cellAt(pending.first.row, i).hasLetter) return false;
      }
    } else {
      final rows = pending.map((c) => c.row).toList()..sort();
      for (var i = rows.first; i <= rows.last; i++) {
        if (!_localBoard.cellAt(i, pending.first.column).hasLetter) {
          return false;
        }
      }
    }
    return true;
  }

  bool _touchesLocked(List<BoardCell> pending) {
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final cell in pending) {
      for (final d in dirs) {
        final r = cell.row + d.$1;
        final c = cell.column + d.$2;
        if (r < 0 || r >= 15 || c < 0 || c >= 15) continue;
        if (_localBoard.cellAt(r, c).isLocked) return true;
      }
    }
    return false;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    final room = _room!;
    final isHost = room.hostUid == widget.myUid;
    final myName = isHost ? room.hostName : (room.guestName ?? L.you);
    final oppName =
        isHost ? (room.guestName ?? L.opponentFallback) : room.hostName;
    final myScore = isHost ? room.hostScore : room.guestScore;
    final oppScore = isHost ? room.guestScore : room.hostScore;
    final myTurn = _isMyTurn;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Ambient sahne arka planı: dikey gradient + radial vignette
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0E1827), Color(0xFF060A12)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      const Color(0xFF4CAF50).withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _Header(
                      myName: myName,
                      oppName: oppName,
                      myScore: myScore,
                      oppScore: oppScore,
                      isMyTurn: myTurn,
                      bagCount: room.bagLetters.length,
                      roomCode: widget.roomCode,
                      onBack: () {
                        Navigator.pop(context);
                        homeOpenMyGamesTick.value++;
                      },
                      onForfeit: () async {
                        final leave = await _confirmLeave();
                        if (!leave || !mounted) return;
                        await MultiplayerService.instance
                            .leaveRoom(widget.roomCode, widget.myUid);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                    // Board — zoom/pan destekli alan
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final size =
                              (constraints.maxWidth < constraints.maxHeight
                                  ? constraints.maxWidth
                                  : constraints.maxHeight);
                          final viewportHeight = _touchCtrl.panEnabled
                              ? constraints.maxHeight
                              : size;
                          _touchCtrl.viewportSize =
                              Size(size, viewportHeight);
                          _touchCtrl.contentSize = Size(size, size);
                          _scheduleInitialBoardZoom();
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Align(
                                alignment: _touchCtrl.panEnabled
                                    ? Alignment.topCenter
                                    : const Alignment(0, 0.72),
                                child: SizedBox(
                                  width: size,
                                  height: viewportHeight,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 360),
                                    curve: Curves.easeOut,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: myTurn
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF4CAF50)
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 26,
                                                spreadRadius: 1.5,
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: GestureDetector(
                                      onDoubleTapDown: (d) =>
                                          _doubleTapDetails = d,
                                      onDoubleTap: _handleDoubleTap,
                                      child: RepaintBoundary(
                                        child: InteractiveViewer(
                                          transformationController:
                                              _zoomController,
                                          boundaryMargin: const EdgeInsets.all(
                                              double.infinity),
                                          minScale: 1.0,
                                          maxScale: 4.0,
                                          panEnabled: _touchCtrl.panEnabled,
                                          onInteractionStart: (_) =>
                                              _touchCtrl.onGestureStart(),
                                          onInteractionEnd: (d) =>
                                              _touchCtrl.onGestureEnd(
                                                  d.velocity.pixelsPerSecond),
                                          child: ScrabbleBoardWidget(
                                            board: _localBoard,
                                            lastMoveCells:
                                                room.lastMoveCells.toSet(),
                                            meaningWords:
                                                _meaningWordsFromRoom(room),
                                            onMeaningTap: _showWordMeanings,
                                            onTileDrop:
                                                myTurn ? _onTileDrop : null,
                                            onCellTap:
                                                myTurn ? _onCellTap : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                left: 10,
                                right: 10,
                                child: _WordPreviewBar(words: _pendingWords),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Error
                    if (_error.isNotEmpty)
                      _ErrorShake(
                        key: ValueKey(_errorTick),
                        controller: _errorShakeCtrl!,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kError.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _kError.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              _error,
                              style:
                                  const TextStyle(color: _kError, fontSize: 13),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                      ),
                    // Turn indicator
                    if (!myTurn)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kBlue),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$oppName ${L.opponentTurnSuffix}',
                              style:
                                  const TextStyle(color: _kBlue, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    // Rack
                    RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                        child: LetterRackWidget(
                          tiles: _myRack,
                          enabled: myTurn && !_submitting,
                          selectedTileId: _selectedTile?.id,
                          onTileTap: _onTileTap,
                        ),
                      ),
                    ),
                    // Action buttons
                    if (myTurn)
                      RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                          child: Column(
                            children: [
                              // Küçük eylem butonları
                              Row(
                                children: [
                                  _SmallBtn(
                                    label: L.recall,
                                    icon: Icons.undo_rounded,
                                    onTap: _submitting ? null : _recallAll,
                                  ),
                                  const SizedBox(width: 8),
                                  _SmallBtn(
                                    label: L.passTurn,
                                    icon: Icons.skip_next_rounded,
                                    onTap: _submitting ? null : _pass,
                                  ),
                                  const SizedBox(width: 8),
                                  _SmallBtn(
                                    label: _isInStealMode
                                        ? '⚡ ${L.steal}'
                                        : '🎯 ${L.steal} ($_myStealsLeft)',
                                    icon: Icons.auto_awesome_rounded,
                                    active: _isInStealMode,
                                    disabled: _myStealsLeft <= 0,
                                    onTap: (_submitting || _myStealsLeft <= 0)
                                        ? null
                                        : () {
                                            setState(() {
                                              _isInStealMode = !_isInStealMode;
                                              if (!_isInStealMode) _recallAll();
                                            });
                                            HapticFeedback.mediumImpact();
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Oyna butonu — premium gradient + glow
                              _PlayBtn(
                                loading: _submitting,
                                steal: _isInStealMode,
                                label: L.play,
                                onTap: _submitting ? null : _submit,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
                // Turn banner overlay
                if (_turnBannerText.isNotEmpty)
                  _TurnBanner(
                    controller: _turnBannerCtrl!,
                    text: _turnBannerText,
                  ),
                // Skor celebration burst (streak büyütür)
                if (_celebrateTick > 0)
                  _CelebrationBurst(
                    key: ValueKey('celeb-$_celebrateTick'),
                    score: _celebrateScore,
                    streak: _streak,
                  ),
                // Streak banner — kombo başladığında görünen "x2 / x3 ..."
                if (_streakBannerTick > 0)
                  _StreakBanner(
                    key: ValueKey('streak-$_streakBannerTick'),
                    streak: _streak,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    if (_room?.status == 'finished') return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _kCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(L.leaveGameTitle,
                style: const TextStyle(color: Colors.white)),
            content: Text(
              L.leaveGameMessage,
              style: const TextStyle(color: Colors.white54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(L.cancel,
                    style: const TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(L.leaveGameAction,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _cleanError(Object error) =>
      error.toString().replaceAll('Exception: ', '').split(']').last.trim();
}

// ── Header ────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
  final String myName;
  final String oppName;
  final int myScore;
  final int oppScore;
  final bool isMyTurn;
  final int bagCount;
  final String roomCode;
  final VoidCallback onBack;
  final VoidCallback onForfeit;

  const _Header({
    required this.myName,
    required this.oppName,
    required this.myScore,
    required this.oppScore,
    required this.isMyTurn,
    required this.bagCount,
    required this.roomCode,
    required this.onBack,
    required this.onForfeit,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  int? _myDelta;
  int? _oppDelta;
  int _myDeltaTick = 0;
  int _oppDeltaTick = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Header old) {
    super.didUpdateWidget(old);
    if (widget.myScore != old.myScore) {
      final delta = widget.myScore - old.myScore;
      if (delta != 0) {
        setState(() {
          _myDelta = delta;
          _myDeltaTick++;
        });
      }
    }
    if (widget.oppScore != old.oppScore) {
      final delta = widget.oppScore - old.oppScore;
      if (delta != 0) {
        setState(() {
          _oppDelta = delta;
          _oppDeltaTick++;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onMyDeltaDone() {
    if (mounted) setState(() => _myDelta = null);
  }

  void _onOppDeltaDone() {
    if (mounted) setState(() => _oppDelta = null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111A28), Color(0xFF1A2940)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom:
              BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            onTap: widget.onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PlayerCard(
              name: widget.myName,
              score: widget.myScore,
              isActive: widget.isMyTurn,
              alignEnd: false,
              pulse: _pulseCtrl,
              delta: _myDelta,
              deltaTick: _myDeltaTick,
              onDeltaDone: _onMyDeltaDone,
            ),
          ),
          _BagChip(count: widget.bagCount),
          Expanded(
            child: _PlayerCard(
              name: widget.oppName,
              score: widget.oppScore,
              isActive: !widget.isMyTurn,
              alignEnd: true,
              pulse: _pulseCtrl,
              delta: _oppDelta,
              deltaTick: _oppDeltaTick,
              onDeltaDone: _onOppDeltaDone,
            ),
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.flag_rounded,
            color: const Color(0xFFEF5350).withValues(alpha: 0.85),
            onTap: widget.onForfeit,
            tooltip: L.leaveGameAction,
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.onTap,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _BagChip extends StatelessWidget {
  final int count;
  const _BagChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_rounded,
              color: Colors.white.withValues(alpha: 0.45), size: 14),
          const SizedBox(height: 2),
          Text('$count',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              )),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String name;
  final int score;
  final bool isActive;
  final bool alignEnd;
  final Animation<double> pulse;
  final int? delta;
  final int deltaTick;
  final VoidCallback onDeltaDone;

  const _PlayerCard({
    required this.name,
    required this.score,
    required this.isActive,
    required this.alignEnd,
    required this.pulse,
    required this.delta,
    required this.deltaTick,
    required this.onDeltaDone,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    final avatar = AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final glow = isActive ? (0.35 + 0.25 * pulse.value) : 0.0;
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? const [Color(0xFF4CAF50), Color(0xFF1B5E20)]
                  : [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04)
                    ],
            ),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF4CAF50)
                      .withValues(alpha: 0.55 + 0.25 * pulse.value)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1.5,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: const Color(0xFF4CAF50).withValues(alpha: glow),
                  blurRadius: 12 + 6 * pulse.value,
                  spreadRadius: 0.5,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
    );

    final onlineDot = Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF6F8197),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF111A28), width: 1.5),
        ),
      ),
    );

    final avatarStack = SizedBox(
      width: 42,
      height: 42,
      child: Stack(clipBehavior: Clip.none, children: [
        Center(child: avatar),
        onlineDot,
      ]),
    );

    final textBlock = Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Stack(
          clipBehavior: Clip.none,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: score.toDouble(), end: score.toDouble()),
              duration: const Duration(milliseconds: 250),
              builder: (_, val, __) => Text(
                '${val.round()} ${L.points}',
                style: TextStyle(
                  color: isActive ? const Color(0xFF8BE193) : Colors.white38,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  shadows: isActive
                      ? [
                          Shadow(
                              color: const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.45),
                              blurRadius: 8)
                        ]
                      : null,
                ),
              ),
            ),
            if (delta != null)
              Positioned(
                top: -4,
                child: _FloatingDelta(
                  key: ValueKey(deltaTick),
                  delta: delta!,
                  onDone: onDeltaDone,
                ),
              ),
          ],
        ),
      ],
    );

    final children = alignEnd
        ? [Expanded(child: textBlock), const SizedBox(width: 10), avatarStack]
        : [avatarStack, const SizedBox(width: 10), Expanded(child: textBlock)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: children),
    );
  }
}

class _FloatingDelta extends StatefulWidget {
  final int delta;
  final VoidCallback onDone;
  const _FloatingDelta({super.key, required this.delta, required this.onDone});

  @override
  State<_FloatingDelta> createState() => _FloatingDeltaState();
}

class _FloatingDeltaState extends State<_FloatingDelta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value;
        final dy = -28 * Curves.easeOutCubic.transform(v);
        final scale = 0.85 + 0.30 * (v < 0.25 ? v / 0.25 : 1.0);
        final opacity = v < 0.85 ? 1.0 : (1 - (v - 0.85) / 0.15);
        final positive = widget.delta > 0;
        final color =
            positive ? const Color(0xFFFFD54F) : const Color(0xFFEF9A9A);
        final sign = positive ? '+' : '';
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.55)),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 10,
                        spreadRadius: 0.5),
                  ],
                ),
                child: Text(
                  '$sign${widget.delta}',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Small action button (icon + label, equal width) ──────────────

class _SmallBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool disabled;

  const _SmallBtn({
    required this.label,
    required this.icon,
    this.onTap,
    this.active = false,
    this.disabled = false,
  });

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  bool _pressed = false;
  static const _kStealActive = Color(0xFFFF6F00);

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.active
        ? _kStealActive.withValues(alpha: 0.18)
        : widget.disabled
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.07);
    final Color border = widget.active
        ? _kStealActive.withValues(alpha: 0.7)
        : widget.disabled
            ? Colors.white12
            : Colors.white.withValues(alpha: 0.15);
    final Color fg = widget.active
        ? _kStealActive
        : widget.disabled
            ? Colors.white24
            : Colors.white60;

    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) {
          if (widget.disabled || widget.onTap == null) return;
          setState(() => _pressed = true);
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: border, width: widget.active ? 1.5 : 1.0),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: _kStealActive.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: fg, size: 18),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 9.5,
                    fontWeight:
                        widget.active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Word preview bar ─────────────────────────────────────────────

class _WordPreviewBar extends StatelessWidget {
  final List<({String word, int score, bool valid})> words;

  const _WordPreviewBar({required this.words});

  @override
  Widget build(BuildContext context) {
    final validWords = words.where((e) => e.valid).toList(growable: false);
    final hasInvalid = words.any((e) => !e.valid);
    final totalScore =
        hasInvalid ? 0 : validWords.fold<int>(0, (sum, e) => sum + e.score);
    final accent = hasInvalid ? _kError : _kPrimary;

    return SizedBox(
      height: 36,
      width: double.infinity,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: words.isEmpty ? 0.08 : 0.14),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: accent.withValues(alpha: 0.55), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasInvalid ? Icons.warning_amber_rounded : Icons.bolt_rounded,
                  size: 13,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  '$totalScore ${L.points}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          for (final e in words) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (e.valid ? _kPrimary : _kError).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: (e.valid ? _kPrimary : _kError).withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                e.valid ? '${e.word} +${e.score}' : e.word,
                style: TextStyle(
                  color: e.valid ? _kPrimary : _kError,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeaningTabEntry {
  final String word;
  final String meaning;

  const _MeaningTabEntry({
    required this.word,
    required this.meaning,
  });
}

class _WordMeaningBubble extends StatefulWidget {
  final List<_MeaningTabEntry> entries;
  final VoidCallback onDismiss;

  const _WordMeaningBubble({
    required this.entries,
    required this.onDismiss,
  });

  @override
  State<_WordMeaningBubble> createState() => _WordMeaningBubbleState();
}

class _WordMeaningBubbleState extends State<_WordMeaningBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final selected = entries.isEmpty
        ? const _MeaningTabEntry(word: '', meaning: '')
        : entries[_selectedIndex.clamp(0, entries.length - 1)];

    return SizedBox.expand(
      child: GestureDetector(
        onTap: widget.onDismiss,
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _kTopStart,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _kPrimary.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < entries.length; i++) ...[
                              _MeaningWordTab(
                                word: entries[i].word,
                                selected: i == _selectedIndex,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedIndex = i);
                                },
                              ),
                              if (i != entries.length - 1)
                                const SizedBox(width: 7),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          selected.word,
                          style: const TextStyle(
                            color: Color(0xFF81C784),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Align(
                          key: ValueKey('${selected.word}-${selected.meaning}'),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selected.meaning,
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        L.current == AppLocale.tr
                            ? 'Sekmeye dokun • dışarı dokunarak kapat'
                            : 'Li peyvê bitikîne • derve bitikîne da bigire',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeaningWordTab extends StatelessWidget {
  final String word;
  final bool selected;
  final VoidCallback onTap;

  const _MeaningWordTab({
    required this.word,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _kPrimary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF81C784)
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Text(
          word,
          style: TextStyle(
            color: selected ? const Color(0xFFE8F5E9) : Colors.white60,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

// ── Premium "Oyna" butonu ────────────────────────────────────────

class _PlayBtn extends StatefulWidget {
  final bool loading;
  final bool steal;
  final String label;
  final VoidCallback? onTap;
  const _PlayBtn(
      {required this.loading,
      required this.steal,
      required this.label,
      this.onTap});

  @override
  State<_PlayBtn> createState() => _PlayBtnState();
}

class _PlayBtnState extends State<_PlayBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final stealMode = widget.steal;
    final colors = stealMode
        ? const [Color(0xFFFFB300), Color(0xFFFF6F00)]
        : const [Color(0xFF66E093), Color(0xFF2E9F58)];
    final glow = stealMode ? const Color(0xFFFF6F00) : const Color(0xFF4CAF50);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        if (!disabled) setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (_, __) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: disabled
                    ? const LinearGradient(
                        colors: [Color(0xFF2A3445), Color(0xFF1B2330)])
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: disabled
                      ? Colors.white12
                      : Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          color: glow.withValues(alpha: 0.40),
                          blurRadius: 22,
                          spreadRadius: 0.5,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Shimmer overlay
                  if (!disabled)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: IgnorePointer(
                          child: Transform.translate(
                            offset: Offset(
                              -180 + 360 * _shimmer.value,
                              0,
                            ),
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        widget.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Icon(
                                stealMode
                                    ? Icons.bolt_rounded
                                    : Icons.send_rounded,
                                color: disabled ? Colors.white24 : Colors.white,
                                size: 19,
                              ),
                        const SizedBox(width: 10),
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: disabled ? Colors.white24 : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.4,
                            shadows: disabled
                                ? null
                                : [
                                    Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.35),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1)),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Skor celebration particle burst ─────────────────────────────

class _CelebrationBurst extends StatefulWidget {
  final int score;
  final int streak;
  const _CelebrationBurst({super.key, required this.score, this.streak = 0});

  @override
  State<_CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<_CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    final rng = math.Random();
    // Streak büyüdükçe parçacık sayısı katlanır: 1× → 1.5× → 2×
    final streakBoost = math.min(widget.streak, 4);
    final n = (16 + math.min(widget.score, 20).toInt()) + (streakBoost * 8);
    _particles = List.generate(n, (_) {
      final angle = -math.pi + rng.nextDouble() * math.pi; // upward fan
      final speed = 90 + rng.nextDouble() * 130;
      return _Particle(
        angle: angle,
        speed: speed,
        size: 3 + rng.nextDouble() * 4,
        hueShift: rng.nextDouble(),
        delay: rng.nextDouble() * 0.10,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 30,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _ctrl.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double hueShift;
  final double delay;
  _Particle(
      {required this.angle,
      required this.speed,
      required this.size,
      required this.hueShift,
      required this.delay});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, 30);
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      // Easeout for outward motion
      final ease = 1 - math.pow(1 - t, 2).toDouble();
      final dx = math.cos(p.angle) * p.speed * ease;
      final dy =
          math.sin(p.angle) * p.speed * ease + 110 * t * t; // gravity pull
      final pos = origin + Offset(dx, dy);
      // Color: amber → orange → fade
      final hueT = p.hueShift;
      final base = Color.lerp(
        const Color(0xFFFFE082),
        const Color(0xFFFFA000),
        hueT,
      )!;
      final opacity = (t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = base.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
      canvas.drawCircle(pos, p.size * (1 - 0.3 * t), paint);
      // Rim glow
      final glow = Paint()
        ..color = base.withValues(alpha: opacity * 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(pos, p.size * 1.6, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress;
}

// ── Streak / kombo banner ────────────────────────────────────────

class _StreakBanner extends StatefulWidget {
  final int streak;
  const _StreakBanner({super.key, required this.streak});

  @override
  State<_StreakBanner> createState() => _StreakBannerState();
}

class _StreakBannerState extends State<_StreakBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.streak;
    final fire = s >= 3;
    return Positioned(
      top: 86,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final v = _ctrl.value;
              final entry =
                  Curves.easeOutBack.transform(v.clamp(0.0, 0.45) / 0.45);
              final opacity = v < 0.75 ? 1.0 : 1.0 - (v - 0.75) / 0.25;
              final scale = 0.7 + 0.3 * entry;
              final dy =
                  -16 * (1 - entry) + (v > 0.75 ? -20 * (v - 0.75) / 0.25 : 0);
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: fire
                              ? const [Color(0xFFFF6F00), Color(0xFFD84315)]
                              : const [Color(0xFFFFB300), Color(0xFFE65100)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: (fire
                                    ? const Color(0xFFFF6F00)
                                    : const Color(0xFFFFB300))
                                .withValues(alpha: 0.55),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            fire
                                ? Icons.local_fire_department_rounded
                                : Icons.bolt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'x$s ${fire ? "COMBO!" : "STREAK"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Turn banner overlay ──────────────────────────────────────────

class _TurnBanner extends StatelessWidget {
  final AnimationController controller;
  final String text;
  const _TurnBanner({required this.controller, required this.text});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final v = controller.value;
            final scale =
                0.85 + 0.15 * Curves.easeOutBack.transform(v.clamp(0.0, 1.0));
            return Center(
              child: Opacity(
                opacity: (v < 0.85 ? v / 0.85 : 1.0).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF4CAF50).withValues(alpha: 0.55),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Error shake ──────────────────────────────────────────────────

class _ErrorShake extends StatelessWidget {
  final AnimationController controller;
  final Widget child;
  const _ErrorShake({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        // 3 oscillation, decaying amplitude
        final t = controller.value;
        final amp = (1 - t) * 8;
        final dx = amp * (t < 1 ? (t * 12).remainder(1) - 0.5 : 0);
        return Transform.translate(offset: Offset(dx * 2, 0), child: child);
      },
      child: child,
    );
  }
}

// ── Premium game over card ───────────────────────────────────────

class _GameOverCard extends StatelessWidget {
  final bool iWon;
  final bool isDraw;
  final int myScore;
  final int oppScore;
  final String oppName;
  final VoidCallback onClose;

  const _GameOverCard({
    required this.iWon,
    required this.isDraw,
    required this.myScore,
    required this.oppScore,
    required this.oppName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDraw
        ? const Color(0xFF6CC0F5)
        : iWon
            ? const Color(0xFFFFB300)
            : const Color(0xFFEF5350);
    final accentDeep = isDraw
        ? const Color(0xFF1565C0)
        : iWon
            ? const Color(0xFFE65100)
            : const Color(0xFFB71C1C);
    final headerIcon = isDraw
        ? Icons.handshake_rounded
        : iWon
            ? Icons.emoji_events_rounded
            : Icons.shield_moon_rounded;
    final title = isDraw
        ? (L.current == AppLocale.tr ? 'Berabere' : 'Wekhev')
        : iWon
            ? L.won
            : L.lost;
    final subtitle = isDraw
        ? (L.current == AppLocale.tr ? 'İyi maç!' : 'Lîstik baş bû!')
        : iWon
            ? (L.current == AppLocale.tr ? 'Mükemmel oyun!' : 'Pir baş!')
            : (L.current == AppLocale.tr ? 'Tekrar dene!' : 'Dîsa biceribîne!');

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2433), Color(0xFF0E1622)],
            ),
            border:
                Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.30),
                blurRadius: 40,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Top gradient accent bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.28),
                          accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon halo
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accentDeep],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.55),
                              blurRadius: 22,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(headerIcon, color: Colors.white, size: 38),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          shadows: [
                            Shadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 14),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Score comparison
                      _ScoreCompareRow(
                        label: L.you,
                        score: myScore,
                        accent: accent,
                        highlight: !isDraw && iWon,
                      ),
                      const SizedBox(height: 10),
                      _ScoreCompareRow(
                        label: oppName,
                        score: oppScore,
                        accent: const Color(0xFF6CC0F5),
                        highlight: !isDraw && !iWon,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: onClose,
                          child: Text(
                            L.current == AppLocale.tr ? 'Tamam' : 'Baş e',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreCompareRow extends StatelessWidget {
  final String label;
  final int score;
  final Color accent;
  final bool highlight;

  const _ScoreCompareRow({
    required this.label,
    required this.score,
    required this.accent,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        final shown = (score * t).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: highlight
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight
                  ? accent.withValues(alpha: 0.50)
                  : Colors.white.withValues(alpha: 0.08),
              width: highlight ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (highlight)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                          color: accent.withValues(alpha: 0.7), blurRadius: 6),
                    ],
                  ),
                ),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$shown',
                style: TextStyle(
                  color: highlight ? accent : Colors.white60,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
