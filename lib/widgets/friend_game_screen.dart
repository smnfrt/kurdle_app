import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/controllers/board_touch_controller.dart';
import 'package:kurdle_app/services/notification_service.dart';
import 'package:kurdle_app/models/board_cell.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/board_layout_service.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/game_score_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/level_rewards.dart';
import 'package:kurdle_app/services/match_chat_service.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/services/scoring_service.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/services/word_steal_service.dart';
import 'package:kurdle_app/services/word_validator_service.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/wordlist_loader.dart';
import 'package:kurdle_app/widgets/letter_rack_widget.dart';
import 'package:kurdle_app/widgets/game_chat_panel.dart';
import 'package:kurdle_app/widgets/scrabble_board_widget.dart';

const _kBgDark = Color(0xFF0D1520);
const _kTopStartDark = Color(0xFF1E2A3A);
const _kCardDark = Color(0xFF162030);
// Light tema chrome (app light theme'i ile uyumlu).
const _kBgLight = Color(0xFFE6EEF2);
const _kTopStartLight = Color(0xFFD2DDE4);
const _kCardLight = Color(0xFFF4F8FA);
// Functional / brand renkleri tema-bağımsız.
const _kPrimary = Color(0xFF4CAF50);
const _kError = Color(0xFFFF6B6B);

// Build-time theme-aware ortak getter'lar. Build() içinden çağrılır.
Color _bgFor(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? _kBgDark : _kBgLight;
Color _topStartFor(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
        ? _kTopStartDark
        : _kTopStartLight;
Color _cardFor(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? _kCardDark : _kCardLight;
Color _textFor(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? Colors.white
    : const Color(0xFF172033);
Color _mutedTextFor(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.62)
        : const Color(0xFF5D6A7A);
const _kInitialBoardZoom = 2.05;

double _bottomSafePadding(BuildContext context, {double minimum = 18}) {
  final mq = MediaQuery.of(context);
  final detected = [
    mq.padding.bottom,
    mq.viewPadding.bottom,
    mq.systemGestureInsets.bottom,
  ].fold<double>(0, (max, value) => value > max ? value : max);
  return detected < minimum ? minimum : detected;
}

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
  StreamSubscription<int>? _chatUnreadSub;
  String? _chatRoomCode;
  int _chatUnreadCount = 0;
  final Map<String, _MeaningTabEntry> _meaningCache = {};
  final Map<String, Future<_MeaningTabEntry>> _meaningWarmInFlight = {};

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
  Timer? _emptyWordHintTimer;
  bool _showEmptyWordHint = true;
  String? _lastSyncedTurnUid;

  // ── Game over ─────────────────────────────────────────────────────
  bool _gameOverShown = false;
  Timer? _turnTimeoutTimer;
  Timer? _turnClockTimer;
  String? _scheduledTurnReminderKey;
  DateTime _clockNow = DateTime.now();

  // ── Player progression info (avatar frame + title) ──────────────
  int _myLevel = 1;
  int _oppLevel = 1;
  bool _levelsFetched = false;

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
    NotificationService.instance.markRoomForeground(widget.roomCode);
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
    NotificationService.instance.clearRoomForeground(widget.roomCode);
    _turnTimeoutTimer?.cancel();
    _turnClockTimer?.cancel();
    _emptyWordHintTimer?.cancel();
    _sub?.cancel();
    _chatUnreadSub?.cancel();
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
      ..scale(scale, scale);
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

  void _showEmptyWordHintBriefly() {
    _emptyWordHintTimer?.cancel();
    if (mounted && !_showEmptyWordHint) {
      setState(() => _showEmptyWordHint = true);
    } else {
      _showEmptyWordHint = true;
    }
    _emptyWordHintTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted || _pendingWords.isNotEmpty) return;
      setState(() => _showEmptyWordHint = false);
    });
  }

  void _computePendingWords() {
    if (_scorer == null || _validator == null) return;
    final words = _scorer!.calculateNewWords(_localBoard);
    _pendingWords = words
        .map((w) =>
            (word: w.word, score: w.score, valid: _validator!.isValid(w.word)))
        .toList();
    if (_pendingWords.isNotEmpty) {
      _emptyWordHintTimer?.cancel();
      _showEmptyWordHint = true;
    }
  }

  List<Map<String, dynamic>> _serializeMoveWords(List<PlacedWord> words) {
    return words
        .where((w) => w.cells.length >= 2)
        .map((w) => {
              'word': w.word,
              'score': w.score,
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

  String _meaningKey(String word) => word.trim().toUpperCase();

  List<String> _uniqueMeaningWords(Iterable<String> words) {
    final seen = <String>{};
    return [
      for (final word in words)
        if (word.trim().isNotEmpty && seen.add(_meaningKey(word))) word.trim()
    ];
  }

  Future<_MeaningTabEntry> _loadMeaningEntry(String word) async {
    final result = await FerhengService.instance.lookupMeaning(
      word,
      acceptedInGame: true,
    );
    final text = result.displayGameMeaning().trim();
    return _MeaningTabEntry(
      word: result.displayWord,
      meaning: text.isEmpty ? L.dictionaryEntryMissingMeaning : text,
    );
  }

  Future<_MeaningTabEntry> _meaningEntryFuture(String word) {
    final key = _meaningKey(word);
    final cached = _meaningCache[key];
    if (cached != null) return Future.value(cached);

    final pending = _meaningWarmInFlight[key];
    if (pending != null) return pending;

    late final Future<_MeaningTabEntry> future;
    future = _loadMeaningEntry(word).then((entry) {
      _meaningCache[key] = entry;
      return entry;
    }).catchError((_) {
      final fallback =
          _MeaningTabEntry(word: word, meaning: L.dictionaryWordNotFound);
      _meaningCache[key] = fallback;
      return fallback;
    }).whenComplete(() {
      if (_meaningWarmInFlight[key] == future) {
        _meaningWarmInFlight.remove(key);
      }
    });
    _meaningWarmInFlight[key] = future;
    return future;
  }

  List<_MeaningTabEntry> _meaningEntriesSnapshot(List<String> words) {
    return words
        .map((word) =>
            _meaningCache[_meaningKey(word)] ??
            _MeaningTabEntry(word: word, meaning: L.meaningLoading))
        .toList(growable: false);
  }

  void _warmMeaningCache(Iterable<String> words) {
    final uniqueWords = _uniqueMeaningWords(words);
    for (final word in uniqueWords) {
      final key = _meaningKey(word);
      if (_meaningCache.containsKey(key) ||
          _meaningWarmInFlight.containsKey(key)) {
        continue;
      }
      unawaited(_meaningEntryFuture(word));
    }
  }

  void _showWordMeanings(List<String> words) async {
    final uniqueWords = _uniqueMeaningWords(words);
    if (uniqueWords.isEmpty) return;
    HapticFeedback.selectionClick();

    final initialEntries = await Future.wait(
      uniqueWords.map(_meaningEntryFuture),
    ).timeout(
      const Duration(milliseconds: 650),
      onTimeout: () => _meaningEntriesSnapshot(uniqueWords),
    );
    if (!mounted) return;

    final entries = ValueNotifier<List<_MeaningTabEntry>>(initialEntries);
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
      final results = await Future.wait(uniqueWords.map(_meaningEntryFuture));
      if (!mounted || !dialogOpen) return;
      entries.value = results;
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
    unawaited(FerhengService.instance.init());
    final allWords = await WordlistLoader.loadAssets(config.wordAssets);
    _validator = WordValidatorService(allWords);
    _scorer = GameScoreService(ScoringService(config.letterPoints));

    _sub = MultiplayerService.instance
        .roomStream(widget.roomCode)
        .listen(_onRoomUpdate);
  }

  void _onRoomUpdate(MultiplayerRoom? room) {
    if (room == null || !mounted) return;
    if (kDebugMode) {
      debugPrint(
          '[FriendGameScreen] room=${room.roomCode} status=${room.status} turn=${room.currentTurnUid} host=${room.hostUid} guest=${room.guestUid} winner=${room.winner} finish=${room.finishReason} by=${room.finishedBy} pass=${room.passCount} score=${room.hostScore}-${room.guestScore}');
    }
    final prev = _room;
    _ensureChatListener(room);
    _warmMeaningCache(room.lastMoveWords.map(
      (word) => (word['word'] as String? ?? '').trim(),
    ));
    setState(() {
      _room = room;
      _loading = false;
    });
    _handleTurnTiming(room);

    // İlk yüklemede her iki oyuncunun seviyesini çek (bot olmayanlar için).
    if (!_levelsFetched) {
      _levelsFetched = true;
      _fetchPlayerLevels(room);
    }

    // Sync local state when my turn starts (or on first load)
    final isMyTurn = room.currentTurnUid == widget.myUid;
    final wasMyTurn = prev?.currentTurnUid == widget.myUid;

    if (isMyTurn && !wasMyTurn) {
      // Opponent just submitted — refresh board and rack
      _syncFromRoom(room);
      // Sıra bana geldi: ekran zaten açıksa sadece oyun içi banner yeterli.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTurnBanner(L.turnIsYours);
      });
      HapticFeedback.mediumImpact();
    } else if (prev == null) {
      // First load
      _syncFromRoom(room);
    } else if (!isMyTurn) {
      // Rakibin sırası ve room güncellendi. Eğer kullanıcı preview taşları
      // yerleştirmişse onları koruyalım — board'u ezmeyelim. Sıra bize
      // gelince zaten _syncFromRoom çağrılır ve preview taşlar rafa geri
      // döner (server rack'i hâlâ onları içerir).
      if (_localBoard.pendingCells.isEmpty) {
        setState(() {
          _localBoard = room.toWordBoard();
        });
      }
    }

    if (room.status == 'finished' && !_gameOverShown) {
      _gameOverShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showGameOver(room));
    }
  }

  void _handleTurnTiming(MultiplayerRoom room) {
    _turnTimeoutTimer?.cancel();
    _turnClockTimer?.cancel();

    final deadline = room.turnDeadlineAt;
    final limit = room.turnTimeLimitSeconds;
    if (room.status != 'active' || deadline == null || limit == null) {
      _scheduledTurnReminderKey = null;
      unawaited(
          NotificationService.instance.cancelTurnReminders(room.roomCode));
      return;
    }

    final now = DateTime.now();
    if (!deadline.isAfter(now)) {
      unawaited(MultiplayerService.instance.resolveTimedOutTurn(room.roomCode));
      return;
    }

    final remaining = deadline.difference(now);
    _turnTimeoutTimer = Timer(remaining, () {
      if (!mounted) return;
      unawaited(MultiplayerService.instance.resolveTimedOutTurn(room.roomCode));
    });

    final isMyTurn = room.currentTurnUid == widget.myUid;
    if (!isMyTurn) {
      _scheduledTurnReminderKey = null;
      unawaited(
          NotificationService.instance.cancelTurnReminders(room.roomCode));
      return;
    }

    final key =
        '${room.roomCode}:${room.currentTurnUid}:${deadline.millisecondsSinceEpoch}';
    if (_scheduledTurnReminderKey != key) {
      _scheduledTurnReminderKey = key;
      unawaited(NotificationService.instance.scheduleTurnReminders(
        roomCode: room.roomCode,
        deadline: deadline,
        timeLimitSeconds: limit,
      ));
    }

    _clockNow = now;
    _turnClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final room = _room;
      if (room == null ||
          room.status != 'active' ||
          room.currentTurnUid != widget.myUid) {
        _turnClockTimer?.cancel();
        return;
      }
      setState(() => _clockNow = DateTime.now());
    });
  }

  void _ensureChatListener(MultiplayerRoom room) {
    if (room.guestUid == null || room.status == 'waiting_invite') return;
    if (_chatRoomCode == room.roomCode && _chatUnreadSub != null) return;
    _chatRoomCode = room.roomCode;
    MatchChatService.instance.ensureMatch(room);
    _chatUnreadSub?.cancel();
    _chatUnreadSub = MatchChatService.instance
        .unreadCountStream(room.roomCode, widget.myUid)
        .listen((count) {
      if (mounted) setState(() => _chatUnreadCount = count);
    }, onError: (_) {
      if (mounted) setState(() => _chatUnreadCount = 0);
    });
  }

  Future<void> _openGameChat() async {
    final room = _room;
    if (room == null) return;
    HapticFeedback.selectionClick();
    try {
      await MatchChatService.instance.ensureMatch(room);
      await MatchChatService.instance.markRead(room.roomCode, widget.myUid);
      if (mounted) setState(() => _chatUnreadCount = 0);
    } catch (_) {}
    if (!mounted) return;
    await GameChatPanel.show(
      context,
      room: room,
      myUid: widget.myUid,
      myName: AuthService.instance.effectiveDisplayName,
    );
    try {
      await MatchChatService.instance.markRead(room.roomCode, widget.myUid);
    } catch (_) {}
  }

  void _syncFromRoom(MultiplayerRoom room) {
    final isHost = room.hostUid == widget.myUid;
    final letters = isHost ? room.hostRack : room.guestRack;
    final isMyTurn = room.currentTurnUid == widget.myUid;
    final becameMyTurn = isMyTurn && _lastSyncedTurnUid != room.currentTurnUid;
    _lastSyncedTurnUid = room.currentTurnUid;
    setState(() {
      _localBoard = room.toWordBoard();
      _myRack = MultiplayerRoom.toRack(letters);
      _selectedTile = null;
      _pendingWords = [];
      _isInStealMode = false;
      _error = '';
      if (!isMyTurn) {
        _showEmptyWordHint = false;
      }
    });
    if (becameMyTurn) _showEmptyWordHintBriefly();
  }

  // ── Board interactions ────────────────────────────────────────────

  bool get _isMyTurn => _room?.currentTurnUid == widget.myUid;

  String? _turnTimeLabel(MultiplayerRoom room) {
    final deadline = room.turnDeadlineAt;
    if (deadline == null || room.turnTimeLimitSeconds == null) return null;
    final remaining = deadline.difference(_clockNow);
    if (remaining <= Duration.zero) return '0:00';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _onTileTap(GameTile tile) {
    // Sıra rakipte olsa bile taş seçilebilsin (preview/test için).
    // Gerçek submit hâlâ _isMyTurn'e gated.
    if (_submitting) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTile = _selectedTile?.id == tile.id ? null : tile);
  }

  void _onCellTap(int row, int col) {
    if (_submitting) return;
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
    if (_submitting) return;
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
    if (_isMyTurn) _showEmptyWordHintBriefly();
    if (recalled.isNotEmpty) HapticFeedback.lightImpact();
  }

  // ── Steal helpers ─────────────────────────────────────────────────

  int get _myStealsLeft {
    if (_room == null) return 0;
    return _room!.hostUid == widget.myUid
        ? _room!.hostStealsLeft
        : _room!.guestStealsLeft;
  }

  List<_MpWordRecord> _roomWordHistory(MultiplayerRoom room) {
    final stored = room.wordHistory
        .map(_MpWordRecord.fromMap)
        .whereType<_MpWordRecord>()
        .toList(growable: false);
    if (stored.isNotEmpty) return stored;
    return _historyFromLastMove(room);
  }

  List<_MpWordRecord> _historyFromLastMove(MultiplayerRoom room) {
    final owner = room.lastMoveBy;
    if (owner == null) return const [];
    return room.lastMoveWords
        .map((map) => _MpWordRecord.fromLastMoveMap(
              map,
              owner: owner,
              turnPlaced: room.turnNumber,
            ))
        .whereType<_MpWordRecord>()
        .toList(growable: false);
  }

  _StealCheck _detectSteal(List<PlacedWord> words) {
    final room = _room;
    if (room == null) {
      return _StealCheck.fail(L.noStealTarget);
    }
    final history = _roomWordHistory(room);
    if (history.isEmpty) {
      return _StealCheck.fail(L.noStealTarget);
    }
    final myOwner = room.hostUid == widget.myUid ? 'host' : 'guest';

    _StealCheck? firstFailure;
    for (final word in words) {
      final target = _findExtendedRecord(word, history, excludedOwner: myOwner);
      if (target == null) continue;
      final protectedTurns = room.turnNumber - target.turnPlaced;
      if (protectedTurns <= 1) {
        firstFailure ??= _StealCheck.fail(L.wordProtected, target: target);
        continue;
      }

      final steal = _stealSvc.canSteal(
        target.word,
        word.word,
        isValidWord: _validator!.isValid,
        currentSteals: target.stealCount,
      );
      if (steal.success) {
        return _StealCheck.ok(steal, target: target, word: word);
      }
      firstFailure ??= _StealCheck.fail(steal.reason, target: target);
    }
    return firstFailure ?? _StealCheck.fail(L.noStealTarget);
  }

  _MpWordRecord? _findExtendedRecord(
    PlacedWord word,
    List<_MpWordRecord> history, {
    String? excludedOwner,
  }) {
    if (word.cells.length < 2) return null;
    final isHorizontal = word.cells.first.row == word.cells.last.row;
    final fixedLine =
        isHorizontal ? word.cells.first.row : word.cells.first.column;
    final positions = word.cells
        .map((c) => isHorizontal ? c.column : c.row)
        .toList(growable: false)
      ..sort();
    final start = positions.first;
    final end = positions.last;

    _MpWordRecord? best;
    for (final record in history) {
      if (excludedOwner != null && record.owner == excludedOwner) continue;
      if (!record.isExtendedBy(
        horizontal: isHorizontal,
        line: fixedLine,
        newStart: start,
        newEnd: end,
      )) {
        continue;
      }
      if (best == null ||
          (record.endPos - record.startPos) > (best.endPos - best.startPos)) {
        best = record;
      }
    }
    return best;
  }

  List<Map<String, dynamic>> _nextWordHistory({
    required MultiplayerRoom room,
    required List<PlacedWord> words,
    required bool isHost,
    _StealCheck? stealCheck,
  }) {
    final owner = isHost ? 'host' : 'guest';
    final nextTurnNumber = room.turnNumber + 1;
    final history = _roomWordHistory(room).toList();

    for (final word in words) {
      if (word.cells.length < 2) continue;
      final isHorizontal = word.cells.first.row == word.cells.last.row;
      final fixedLine =
          isHorizontal ? word.cells.first.row : word.cells.first.column;
      final positions = word.cells
          .map((c) => isHorizontal ? c.column : c.row)
          .toList(growable: false)
        ..sort();
      final start = positions.first;
      final end = positions.last;

      _MpWordRecord? extended;
      history.removeWhere((record) {
        final hit = record.isExtendedBy(
          horizontal: isHorizontal,
          line: fixedLine,
          newStart: start,
          newEnd: end,
        );
        if (hit) extended = record;
        return hit;
      });

      final stoleThisWord =
          stealCheck?.success == true && identical(stealCheck?.word, word);
      history.add(_MpWordRecord(
        word: word.word,
        isHorizontal: isHorizontal,
        fixedLine: fixedLine,
        startPos: start,
        endPos: end,
        owner: owner,
        turnPlaced: nextTurnNumber,
        stealCount: (extended?.stealCount ?? 0) + (stoleThisWord ? 1 : 0),
      ));
    }

    return history.map((record) => record.toMap()).toList(growable: false);
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
    _StealCheck? stealCheck;
    if (_isInStealMode) {
      stealCheck = _detectSteal(words);
      if (!stealCheck.success || _myStealsLeft <= 0) {
        // Başarısız çalma — ceza
        const penalty = 5;
        final reason = _myStealsLeft <= 0 ? L.noStealLeft : stealCheck.reason;
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
            _error = '${L.stealFailedPenalty(penalty)} $reason';
          });
        }
        return;
      }
      // Başarılı çalma — devam et (steal.bonusScore eklenir aşağıda)
    }

    final invalid = words.where((w) => !_validator!.isValid(w.word)).toList();
    if (invalid.isNotEmpty) {
      _setError(L.invalidWords(invalid.map((w) => w.word).join(', ')));
      return;
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
        final steal = (stealCheck ?? _detectSteal(words)).result!;
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
      final nextWordHistory = _nextWordHistory(
        room: room,
        words: words,
        isHost: isHost,
        stealCheck: stealCheck,
      );

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
        wordHistory: nextWordHistory,
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

  void _showGameMenu() {
    if (!_isMyTurn || _room == null || _submitting) return;
    final room = _room!;
    showAppModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FriendGameMenuSheet(
        tilesLeft: room.bagLetters.length,
        passesLeft: math.max(0, 4 - room.passCount),
        rack: _myRack,
        onPass: () {
          Navigator.pop(context);
          unawaited(_pass());
        },
        onExchange: (tiles) {
          Navigator.pop(context);
          unawaited(_exchangeTiles(tiles));
        },
      ),
    );
  }

  Future<void> _exchangeTiles(List<GameTile> tiles) async {
    if (!_isMyTurn || _submitting || _room == null) return;
    if (tiles.isEmpty) {
      _setError(L.selectTile);
      return;
    }

    final room = _room!;
    if (room.bagLetters.length < tiles.length) {
      _setError(L.notEnoughTiles);
      return;
    }

    _recallAll();
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final isHost = room.hostUid == widget.myUid;
      final oppUid = isHost ? (room.guestUid ?? '') : room.hostUid;
      if (oppUid.isEmpty) {
        _setError(L.errorPrefix('Rakip bulunamadı'));
      } else {
        await MultiplayerService.instance.exchangeTiles(
          roomCode: widget.roomCode,
          isHost: isHost,
          selectedLetters: tiles.map((t) => t.letter).toList(),
          nextTurnUid: oppUid,
        );
        if (mounted) {
          SoundService.instance.play(SFX.tileExchange);
          HapticFeedback.lightImpact();
          setState(() {
            _selectedTile = null;
            _error = L.exchanged(tiles.length);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = L.errorPrefix(_cleanError(e)));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  // ── Game over ─────────────────────────────────────────────────────

  Future<void> _fetchPlayerLevels(MultiplayerRoom room) async {
    if (!FirebaseService.isAvailable) return;
    final isHost = room.hostUid == widget.myUid;
    final myUid = widget.myUid;
    final oppUid = isHost ? room.guestUid : room.hostUid;
    try {
      final my = await FirestoreService.instance.getProfile(myUid);
      if (my != null && mounted) {
        setState(() => _myLevel = my.level);
      }
    } catch (_) {}
    if (oppUid == null || oppUid.startsWith('bot_')) return;
    try {
      final opp = await FirestoreService.instance.getProfile(oppUid);
      if (opp != null && mounted) {
        setState(() => _oppLevel = opp.level);
      }
    } catch (_) {}
  }

  void _awardMultiplayerReward({
    required String roomCode,
    required int myScore,
    required bool iWon,
    required bool isDraw,
  }) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    final int xp;
    final int peyv;
    if (iWon) {
      xp = 150 + myScore ~/ 10;
      peyv = 15 + myScore ~/ 30;
    } else if (isDraw) {
      xp = 75 + myScore ~/ 15;
      peyv = 7 + myScore ~/ 45;
    } else {
      xp = 30 + myScore ~/ 30;
      peyv = 3 + myScore ~/ 60;
    }
    FirestoreService.instance.awardMultiplayerProgressionOnce(
      roomCode: roomCode,
      uid: uid,
      xp: xp,
      peyv: peyv,
      reason: 'multiplayer_${iWon ? 'win' : isDraw ? 'draw' : 'loss'}',
    );
    FirestoreService.instance.recordPlayStats(
      uid: uid,
      playerScore: myScore,
      won: iWon,
    );
  }

  void _showGameOver(MultiplayerRoom room) {
    if (!mounted) return;
    final isHost = room.hostUid == widget.myUid;
    final myScore = isHost ? room.hostScore : room.guestScore;
    final oppScore = isHost ? room.guestScore : room.hostScore;
    final oppName =
        isHost ? (room.guestName ?? L.opponentFallback) : room.hostName;

    final iWon = room.winner == (isHost ? 'host' : 'guest');
    final isDraw = room.winner == 'draw';

    // Multiplayer XP/Peyv ödülü — sadece bir kez (idempotent _gameOverShown
    // guard'ı caller'da sağlıyor). Bots'a karşı kazançlar da sayılır.
    _awardMultiplayerReward(
      roomCode: room.roomCode,
      myScore: myScore,
      iWon: iWon,
      isDraw: isDraw,
    );

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
                finishReason: room.finishReason,
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
      return Scaffold(
        backgroundColor: _bgFor(context),
        body: const Center(child: CircularProgressIndicator(color: _kPrimary)),
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
    final turnTimeLabel = _turnTimeLabel(room);
    final boardInteractive = room.status != 'finished';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomSafe = _bottomSafePadding(context);
    return Scaffold(
      backgroundColor: _bgFor(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_kBgDark, Color(0xFF111827)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_kBgLight, Color(0xFFE9F2E2)],
                      ),
              ),
            ),
          ),
          Stack(
            children: [
              Column(
                children: [
                  _Header(
                    myName: myName,
                    oppName: oppName,
                    myScore: myScore,
                    oppScore: oppScore,
                    myLevel: _myLevel,
                    oppLevel: _oppLevel,
                    isMyTurn: myTurn,
                    bagCount: room.bagLetters.length,
                    roomCode: widget.roomCode,
                    chatUnreadCount: _chatUnreadCount,
                    turnTimeLabel: turnTimeLabel,
                    onBack: () {
                      Navigator.pop(context);
                      homeOpenMyGamesTick.value++;
                    },
                    onChat: _openGameChat,
                    onForfeit: () async {
                      final leave = await _confirmLeave();
                      if (!leave || !mounted) return;
                      await MultiplayerService.instance
                          .leaveRoom(widget.roomCode, widget.myUid);
                      if (!mounted) return;
                      _returnToMyGames();
                    },
                  ),
                  // Board — zoom/pan destekli alan
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? const [Color(0xFF101824), Color(0xFF0C1420)]
                              : const [Color(0xFF87969E), Color(0xFFE9F2E2)],
                          stops: const [0.0, 0.42],
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final size =
                              (constraints.maxWidth < constraints.maxHeight
                                  ? constraints.maxWidth
                                  : constraints.maxHeight);
                          final viewportHeight = _touchCtrl.panEnabled
                              ? constraints.maxHeight
                              : size;
                          _touchCtrl.viewportSize = Size(size, viewportHeight);
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
                                            isDarkMode: isDark,
                                            lastMoveCells:
                                                room.lastMoveCells.toSet(),
                                            meaningWords:
                                                _meaningWordsFromRoom(room),
                                            onMeaningTap: _showWordMeanings,
                                            onTileDrop: boardInteractive
                                                ? _onTileDrop
                                                : null,
                                            onCellTap: boardInteractive
                                                ? _onCellTap
                                                : null,
                                            onEmptyCellTap: boardInteractive
                                                ? _onCellTap
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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
                  // Rack — rakibin sırasında bile aktif (preview için)
                  RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                      child: LetterRackWidget(
                        tiles: _myRack,
                        enabled: !_submitting,
                        selectedTileId: _selectedTile?.id,
                        onTileTap: _onTileTap,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _pendingWords.isNotEmpty ||
                            (myTurn && _showEmptyWordHint)
                        ? Padding(
                            key: const ValueKey('word-preview-bottom'),
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                            child: _WordPreviewBar(
                              words: _pendingWords,
                              isMyTurn: myTurn,
                              opponentName: oppName,
                              timeLabel: turnTimeLabel,
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('word-preview-empty'),
                          ),
                  ),
                  // Action buttons — opponent turn'ünde de göster ama
                  // submit/pass/steal disabled. Recall her zaman aktif
                  // ki preview temizlenebilsin.
                  if (myTurn)
                    RepaintBoundary(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(10, 2, 10, bottomSafe + 10),
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
                                  label: L.options,
                                  icon: Icons.tune_rounded,
                                  onTap: _submitting ? null : _showGameMenu,
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
                    // Rakibin sırası: kullanıcı preview yerleştirebilsin
                    // ama submit edilmesin. Recall her zaman aktif.
                    RepaintBoundary(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(10, 2, 10, bottomSafe + 10),
                        child: Column(
                          children: [
                            if (_localBoard.pendingCells.isNotEmpty)
                              Row(
                                children: [
                                  _SmallBtn(
                                    label: L.recall,
                                    icon: Icons.undo_rounded,
                                    onTap: _submitting ? null : _recallAll,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
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
        ],
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    if (_room?.status == 'finished') return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardFor(ctx),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title:
                Text(L.leaveGameTitle, style: TextStyle(color: _textFor(ctx))),
            content: Text(
              L.leaveGameMessage,
              style: TextStyle(color: _mutedTextFor(ctx)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text(L.cancel, style: TextStyle(color: _mutedTextFor(ctx))),
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

  void _returnToMyGames() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeOpenMyGamesTick.value++;
    });
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
  final int myLevel;
  final int oppLevel;
  final bool isMyTurn;
  final int bagCount;
  final String roomCode;
  final int chatUnreadCount;
  final String? turnTimeLabel;
  final VoidCallback onBack;
  final VoidCallback onChat;
  final VoidCallback onForfeit;

  const _Header({
    required this.myName,
    required this.oppName,
    required this.myScore,
    required this.oppScore,
    required this.myLevel,
    required this.oppLevel,
    required this.isMyTurn,
    required this.bagCount,
    required this.roomCode,
    required this.chatUnreadCount,
    required this.turnTimeLabel,
    required this.onBack,
    required this.onChat,
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
    final top = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(10, top + 6, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF1E2A3A), Color(0xFF101824)]
              : const [Color(0xFF52616A), Color(0xFF87969E)],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white10
                : const Color(0xFF6E7D86).withValues(alpha: 0.75),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _IconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                color: const Color(0xFFF1F5F2),
                onTap: widget.onBack,
              ),
              const SizedBox(width: 8),
              _BagChip(count: widget.bagCount),
              const Spacer(),
              if (widget.turnTimeLabel != null)
                _TurnTimerChip(
                  label: widget.turnTimeLabel!,
                  active: widget.isMyTurn,
                ),
              const SizedBox(width: 8),
              _HeaderChatButton(
                unreadCount: widget.chatUnreadCount,
                onTap: widget.onChat,
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.flag_rounded,
                color: const Color(0xFFEF5350).withValues(alpha: 0.85),
                onTap: widget.onForfeit,
                tooltip: L.leaveGameAction,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PlayerCard(
                  name: widget.myName,
                  score: widget.myScore,
                  level: widget.myLevel,
                  isActive: widget.isMyTurn,
                  alignEnd: false,
                  pulse: _pulseCtrl,
                  delta: _myDelta,
                  deltaTick: _myDeltaTick,
                  onDeltaDone: _onMyDeltaDone,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.16),
                    border: Border.all(
                      color:
                          Colors.white.withValues(alpha: isDark ? 0.10 : 0.22),
                    ),
                  ),
                  child: Text(
                    'VS',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _PlayerCard(
                  name: widget.oppName,
                  score: widget.oppScore,
                  level: widget.oppLevel,
                  isActive: !widget.isMyTurn,
                  alignEnd: true,
                  pulse: _pulseCtrl,
                  delta: _oppDelta,
                  deltaTick: _oppDeltaTick,
                  onDeltaDone: _onOppDeltaDone,
                ),
              ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btn = Material(
      color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.22),
              width: 1.2,
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _TurnTimerChip extends StatelessWidget {
  final String label;
  final bool active;

  const _TurnTimerChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? const Color(0xFFFFC857) : Colors.white70;
    return Container(
      height: 36,
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.14),
        border: Border.all(
          color: active
              ? const Color(0xFFFFC857).withValues(alpha: 0.48)
              : Colors.white.withValues(alpha: isDark ? 0.10 : 0.22),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChatButton extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _HeaderChatButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  State<_HeaderChatButton> createState() => _HeaderChatButtonState();
}

class _HeaderChatButtonState extends State<_HeaderChatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.unreadCount > 0) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _HeaderChatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount > 0 && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (widget.unreadCount <= 0) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final hasUnread = widget.unreadCount > 0;
            final glow = hasUnread ? (0.28 + 0.34 * _pulse.value) : 0.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.14),
                    border: Border.all(
                      color: hasUnread
                          ? const Color(0xFF64B5F6)
                              .withValues(alpha: 0.48 + 0.25 * _pulse.value)
                          : Colors.white
                              .withValues(alpha: isDark ? 0.10 : 0.22),
                      width: 1.2,
                    ),
                    boxShadow: [
                      if (hasUnread)
                        BoxShadow(
                          color:
                              const Color(0xFF64B5F6).withValues(alpha: glow),
                          blurRadius: 14,
                          spreadRadius: 0.8,
                        ),
                    ],
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Color(0xFFF1F5F2), size: 18),
                ),
                if (hasUnread)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: const Color(0xFF111A28), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.unreadCount > 9 ? '9+' : '${widget.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
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
  final int level;
  final bool isActive;
  final bool alignEnd;
  final Animation<double> pulse;
  final int? delta;
  final int deltaTick;
  final VoidCallback onDeltaDone;

  const _PlayerCard({
    required this.name,
    required this.score,
    required this.level,
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

    // Seviye-bağımlı avatar çerçevesi (Bronz/Gümüş/Altın/Prestige)
    final frame = avatarFrameAtLevel(level);
    final frameColor = avatarFrameColor(frame);
    final avatarRing = frameColor == null
        ? avatar
        : Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: frameColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: frameColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2),
            child: avatar,
          );

    final avatarSize = frameColor == null ? 42.0 : 48.0;
    final avatarStack = SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(clipBehavior: Clip.none, children: [
        Center(child: avatarRing),
        onlineDot,
      ]),
    );

    final isTr = L.current == AppLocale.tr;
    final title = mpTitleAtLevel(level, isTr: isTr);

    final textBlock = Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (frameColor ?? const Color(0xFFFFD700))
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (frameColor ?? const Color(0xFFFFD700))
                      .withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: frameColor ?? const Color(0xFFFFD700),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: isActive ? const Color(0xFF8BE193) : Colors.white38,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
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

// ── Game menu bottom sheet ───────────────────────────────────────

class _FriendGameMenuSheet extends StatefulWidget {
  final int tilesLeft;
  final int passesLeft;
  final List<GameTile> rack;
  final VoidCallback onPass;
  final void Function(List<GameTile>) onExchange;

  const _FriendGameMenuSheet({
    required this.tilesLeft,
    required this.passesLeft,
    required this.rack,
    required this.onPass,
    required this.onExchange,
  });

  @override
  State<_FriendGameMenuSheet> createState() => _FriendGameMenuSheetState();
}

class _FriendGameMenuSheetState extends State<_FriendGameMenuSheet> {
  final Set<String> _selected = {};
  bool _exchangeMode = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: _exchangeMode ? _buildExchangeView() : _buildMainView(),
    );
  }

  Widget _buildMainView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          L.options,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        _FriendSheetOption(
          icon: Icons.skip_next_rounded,
          iconColor: const Color(0xFF64B5F6),
          title: L.passTurn,
          subtitle: widget.passesLeft > 0
              ? '${L.passTurnSub}  •  ${L.passesLeft(widget.passesLeft)}'
              : L.noPassLeft,
          enabled: widget.passesLeft > 0,
          onTap: widget.passesLeft > 0 ? widget.onPass : null,
        ),
        const SizedBox(height: 10),
        _FriendSheetOption(
          icon: Icons.swap_horiz_rounded,
          iconColor: const Color(0xFFFFB74D),
          title: L.exchangeTiles,
          subtitle: widget.tilesLeft > 0
              ? '${L.tilesLeft}: ${widget.tilesLeft} - ${L.exchangeSub}'
              : L.noTilesInBag,
          enabled: widget.tilesLeft > 0,
          onTap: widget.tilesLeft > 0
              ? () => setState(() => _exchangeMode = true)
              : null,
        ),
      ],
    );
  }

  Widget _buildExchangeView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _exchangeMode = false;
                _selected.clear();
              }),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white54,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                L.exchangeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          L.exchangeSub,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: widget.rack.map((tile) {
            final isSelected = _selected.contains(tile.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selected.remove(tile.id);
                } else {
                  _selected.add(tile.id);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? [const Color(0xFFFFEE58), const Color(0xFFFFC107)]
                        : [const Color(0xFFFFF8E1), const Color(0xFFE8C46A)],
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF8F00)
                        : const Color(0xFFB8860B),
                    width: isSelected ? 2.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFFFFC107).withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: isSelected ? 8 : 3,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    tile.letter,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _exchangeMode = false;
                  _selected.clear();
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(L.cancel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        final tiles = widget.rack
                            .where((t) => _selected.contains(t.id))
                            .toList();
                        widget.onExchange(tiles);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selected.isEmpty ? L.selectTile : L.exchangeConfirm,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FriendSheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _FriendSheetOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled ? Colors.white : Colors.white54,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseText = isDark ? Colors.white : const Color(0xFF173321);
    final disabledText = isDark ? Colors.white38 : const Color(0xFF718178);
    final Color bg = widget.active
        ? _kStealActive.withValues(alpha: 0.18)
        : widget.disabled
            ? (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.035))
            : (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.82));
    final Color border = widget.active
        ? _kStealActive.withValues(alpha: 0.7)
        : widget.disabled
            ? (isDark ? Colors.white24 : const Color(0xFFB8C6BE))
            : (isDark
                ? Colors.white.withValues(alpha: 0.20)
                : const Color(0xFFC7D7CE));
    final Color fg = widget.active
        ? (isDark ? _kStealActive : const Color(0xFFD75F00))
        : widget.disabled
            ? disabledText
            : baseText.withValues(alpha: 0.92);

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
                  : widget.disabled
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.18 : 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
  final bool isMyTurn;
  final String opponentName;
  final String? timeLabel;

  const _WordPreviewBar({
    required this.words,
    required this.isMyTurn,
    required this.opponentName,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validWords = words.where((e) => e.valid).toList(growable: false);
    final invalidWords = words.where((e) => !e.valid).toList(growable: false);
    final hasInvalid = words.any((e) => !e.valid);
    final hasWords = words.isNotEmpty;
    final totalScore =
        hasInvalid ? 0 : validWords.fold<int>(0, (sum, e) => sum + e.score);
    final accent = hasInvalid ? _kError : _kPrimary;
    final invalidWordColor = const Color(0xFFFF6B6B);
    final validWordColor = isDark ? const Color(0xFF8FE3B0) : _kPrimary;
    final surface = isDark
        ? const Color(0xFF101A25).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.92);
    final secondaryText =
        isDark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF52645A);
    final statusText = !hasWords
        ? (isMyTurn
            ? (L.current == AppLocale.tr ? 'Sıra sende' : 'Dor li te ye')
            : (L.current == AppLocale.tr
                ? '$opponentName düşünüyor'
                : '$opponentName difikire'))
        : invalidWords.isEmpty
            ? (validWords.length == 1
                ? (L.current == AppLocale.tr
                    ? 'Geçerli kelime'
                    : 'Peyv derbasdar e')
                : (L.current == AppLocale.tr
                    ? '${validWords.length} kelime geçerli'
                    : '${validWords.length} peyv derbasdar in'))
            : (L.current == AppLocale.tr
                ? '${validWords.length} geçerli · ${invalidWords.length} geçersiz'
                : '${validWords.length} derbasdar · ${invalidWords.length} nederbasdar');
    final wordText = hasWords
        ? words.map((e) => e.word).join(' + ')
        : (isMyTurn
            ? (L.current == AppLocale.tr
                ? 'Tahtaya kelime yerleştir'
                : 'Peyvê li textê deyne')
            : (L.current == AppLocale.tr
                ? 'İstersen taşlarını deneyip hamleni hazırlayabilirsin'
                : 'Tu dikarî tîpan biceribînî û tevgera xwe amade bikî'));
    final hintTextStyle = TextStyle(
      color: isDark ? Colors.white : const Color(0xFF16251D),
      fontSize: 15,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
      height: 1.05,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasWords
              ? accent.withValues(alpha: isDark ? 0.58 : 0.62)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFD5E0D8)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.13),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          if (hasWords)
            BoxShadow(
              color: accent.withValues(alpha: hasInvalid ? 0.16 : 0.20),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: hasWords ? 0.16 : 0.08),
              border: Border.all(
                color: accent.withValues(alpha: hasWords ? 0.52 : 0.22),
              ),
            ),
            child: Icon(
              !hasWords
                  ? Icons.edit_rounded
                  : hasInvalid
                      ? Icons.warning_amber_rounded
                      : Icons.check_rounded,
              color: hasWords ? accent : secondaryText,
              size: 21,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasWords ? accent : secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                hasWords
                    ? _WordStatusStrip(
                        words: words,
                        validColor: validWordColor,
                        invalidColor: invalidWordColor,
                        textColor:
                            isDark ? Colors.white : const Color(0xFF16251D),
                        mutedColor: secondaryText,
                      )
                    : Text(
                        wordText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hintTextStyle,
                      ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            constraints: const BoxConstraints(minWidth: 72),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: hasWords && !hasInvalid
                    ? const [Color(0xFFFFD86B), Color(0xFFE0A82B)]
                    : [
                        accent.withValues(alpha: hasWords ? 0.18 : 0.08),
                        accent.withValues(alpha: hasWords ? 0.10 : 0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasWords && !hasInvalid
                    ? const Color(0xFFFFE7A3)
                    : accent.withValues(alpha: hasWords ? 0.34 : 0.16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasInvalid ? '0' : '$totalScore',
                  style: TextStyle(
                    color: hasWords && !hasInvalid
                        ? const Color(0xFF3A2600)
                        : (hasWords ? accent : secondaryText),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L.points,
                  style: TextStyle(
                    color: hasWords && !hasInvalid
                        ? const Color(0xFF5D4307)
                        : secondaryText,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (timeLabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: (hasWords ? accent : secondaryText)
                    .withValues(alpha: hasWords ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: (hasWords ? accent : secondaryText)
                      .withValues(alpha: hasWords ? 0.30 : 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_rounded,
                    color: hasWords ? accent : secondaryText,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    timeLabel!,
                    style: TextStyle(
                      color: hasWords ? accent : secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WordStatusStrip extends StatelessWidget {
  final List<({String word, int score, bool valid})> words;
  final Color validColor;
  final Color invalidColor;
  final Color textColor;
  final Color mutedColor;

  const _WordStatusStrip({
    required this.words,
    required this.validColor,
    required this.invalidColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: words.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = words[index];
          final color = item.valid ? validColor : invalidColor;
          return Container(
            constraints: const BoxConstraints(maxWidth: 132),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.48)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.valid
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: color,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    item.word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item.valid ? '${item.score}' : '0',
                  style: TextStyle(
                    color: item.valid ? mutedColor : color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          );
        },
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

class _StealCheck {
  final bool success;
  final StealResult? result;
  final _MpWordRecord? target;
  final PlacedWord? word;
  final String reason;

  const _StealCheck._({
    required this.success,
    this.result,
    this.target,
    this.word,
    this.reason = '',
  });

  factory _StealCheck.ok(
    StealResult result, {
    required _MpWordRecord target,
    required PlacedWord word,
  }) =>
      _StealCheck._(
        success: true,
        result: result,
        target: target,
        word: word,
      );

  factory _StealCheck.fail(String reason, {_MpWordRecord? target}) =>
      _StealCheck._(success: false, reason: reason, target: target);
}

class _MpWordRecord {
  final String word;
  final bool isHorizontal;
  final int fixedLine;
  final int startPos;
  final int endPos;
  final String owner;
  final int turnPlaced;
  final int stealCount;

  const _MpWordRecord({
    required this.word,
    required this.isHorizontal,
    required this.fixedLine,
    required this.startPos,
    required this.endPos,
    required this.owner,
    required this.turnPlaced,
    required this.stealCount,
  });

  static _MpWordRecord? fromMap(Map<String, dynamic> map) {
    final word = map['word'] as String?;
    final owner = map['owner'] as String?;
    final isHorizontal = map['isHorizontal'] as bool?;
    final fixedLine = (map['fixedLine'] as num?)?.toInt();
    final startPos = (map['startPos'] as num?)?.toInt();
    final endPos = (map['endPos'] as num?)?.toInt();
    if (word == null ||
        owner == null ||
        isHorizontal == null ||
        fixedLine == null ||
        startPos == null ||
        endPos == null) {
      return null;
    }
    return _MpWordRecord(
      word: word,
      isHorizontal: isHorizontal,
      fixedLine: fixedLine,
      startPos: startPos,
      endPos: endPos,
      owner: owner,
      turnPlaced: (map['turnPlaced'] as num?)?.toInt() ?? 0,
      stealCount: (map['stealCount'] as num?)?.toInt() ?? 0,
    );
  }

  static _MpWordRecord? fromLastMoveMap(
    Map<String, dynamic> map, {
    required String owner,
    required int turnPlaced,
  }) {
    final word = map['word'] as String?;
    final rawCells = map['cells'] as List?;
    if (word == null || rawCells == null || rawCells.length < 2) return null;

    final positions = <({int row, int col})>[];
    for (final raw in rawCells) {
      final parts = raw.toString().split(':');
      if (parts.length != 2) return null;
      final row = int.tryParse(parts[0]);
      final col = int.tryParse(parts[1]);
      if (row == null || col == null) return null;
      positions.add((row: row, col: col));
    }
    final isHorizontal = positions.first.row == positions.last.row;
    final fixedLine = isHorizontal ? positions.first.row : positions.first.col;
    final linePositions =
        positions.map((p) => isHorizontal ? p.col : p.row).toList()..sort();
    return _MpWordRecord(
      word: word,
      isHorizontal: isHorizontal,
      fixedLine: fixedLine,
      startPos: linePositions.first,
      endPos: linePositions.last,
      owner: owner,
      turnPlaced: turnPlaced,
      stealCount: 0,
    );
  }

  bool isExtendedBy({
    required bool horizontal,
    required int line,
    required int newStart,
    required int newEnd,
  }) {
    if (isHorizontal != horizontal) return false;
    if (fixedLine != line) return false;
    return newStart <= startPos &&
        endPos <= newEnd &&
        (newStart < startPos || endPos < newEnd);
  }

  Map<String, dynamic> toMap() => {
        'word': word,
        'isHorizontal': isHorizontal,
        'fixedLine': fixedLine,
        'startPos': startPos,
        'endPos': endPos,
        'owner': owner,
        'turnPlaced': turnPlaced,
        'stealCount': stealCount,
      };
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? _topStartFor(context) : Colors.white;
    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black12;
    final wordColor =
        isDark ? const Color(0xFF81C784) : const Color(0xFF1B7A3A);
    final meaningColor =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1C2A22);
    final helperColor =
        isDark ? Colors.white.withValues(alpha: 0.42) : const Color(0xFF65786D);

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
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _kPrimary.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.45 : 0.18),
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
                        Container(height: 1, color: dividerColor),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selected.word,
                            style: TextStyle(
                              color: wordColor,
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
                            key: ValueKey(
                                '${selected.word}-${selected.meaning}'),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              selected.meaning,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: meaningColor,
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
                          style: TextStyle(color: helperColor, fontSize: 10),
                        ),
                      ],
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _kPrimary.withValues(alpha: 0.22)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFEAF3EC)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF81C784)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFFC8D8CE)),
            width: 1,
          ),
        ),
        child: Text(
          word,
          style: TextStyle(
            color: selected
                ? (isDark ? const Color(0xFFE8F5E9) : const Color(0xFF175C2E))
                : (isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : const Color(0xFF31463A)),
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
  final String? finishReason;
  final VoidCallback onClose;

  const _GameOverCard({
    required this.iWon,
    required this.isDraw,
    required this.myScore,
    required this.oppScore,
    required this.oppName,
    this.finishReason,
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
            : finishReason == 'timeout'
                ? L.timeoutLose
                : (L.current == AppLocale.tr
                    ? 'Tekrar dene!'
                    : 'Dîsa biceribîne!');

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
