import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'dart:ui' as ui;
import 'package:kurdle_app/controllers/board_touch_controller.dart';
import 'package:kurdle_app/controllers/scrabble_game_controller.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_suggestion.dart';
import 'package:kurdle_app/services/game_store.dart';
import 'package:kurdle_app/services/kurdish_meanings.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/wordlist_loader.dart';
import 'package:kurdle_app/widgets/ferheng/word_detail_popup.dart';
import 'package:kurdle_app/widgets/chat_screen.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/widgets/letter_rack_widget.dart';
import 'package:kurdle_app/widgets/scrabble_board_widget.dart';
import 'package:kurdle_app/widgets/steal_banner_widget.dart';
import 'package:kurdle_app/services/haptic_service.dart';

// ── Design tokens ───────────────────────────────────────────────
const _kBg         = Color(0xFFF5F0E8);
const _kTopStart   = Color(0xFF1E2A3A);
const _kTopEnd     = Color(0xFF2D3F52);
const _kActive     = Color(0xFF4CAF50);
const _kPrimary    = Color(0xFF4CAF50);
const _kBottomBg   = Color(0xFF252525);
const _kErrorColor = Color(0xFFFF6B6B);

class ScrabbleGameScreen extends StatefulWidget {
  final ScrabbleGameController? existingController;
  final String? tournamentMatchId;
  final int? turnTimeLimitSeconds;

  const ScrabbleGameScreen({Key? key, this.existingController, this.tournamentMatchId, this.turnTimeLimitSeconds}) : super(key: key);

  @override
  State<ScrabbleGameScreen> createState() => _ScrabbleGameScreenState();
}

class _ScrabbleGameScreenState extends State<ScrabbleGameScreen>
    with TickerProviderStateMixin {
  ScrabbleGameController? _controller;
  String _error = '';
  GameTile? _selectedTile;
  GamePhase? _lastPhase;

  // ValueNotifier'lar ile sadece ilgili widget rebuild olur
  final _boardNotifier  = ValueNotifier<int>(0);
  final _rackNotifier   = ValueNotifier<int>(0);
  final _scoreNotifier  = ValueNotifier<int>(0);
  VoidCallback? _controllerListener;

  final _zoomController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late final BoardTouchController _touchCtrl;

  // Sohbet paneli
  bool _hasUnread   = false;

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

  void _attachListener(ScrabbleGameController ctrl) {
    _controllerListener = () {
      _onControllerUpdate();
      GameStore.instance.sync(_controller!);
    };
    ctrl.addListener(_controllerListener!);
  }

  @override
  void initState() {
    super.initState();
    _touchCtrl = BoardTouchController(
      transformCtrl: _zoomController,
      vsync: this,
      onPanChanged: (enabled) { if (mounted) setState(() {}); },
    );
    _zoomController.addListener(_touchCtrl.onTransformChanged);
    if (widget.existingController != null) {
      _controller = widget.existingController!;
      _lastPhase = _controller!.phase;
      _attachListener(_controller!);
      GameStore.instance.activeController = _controller;
    } else {
      _loadGame();
    }
  }

  Future<void> _loadGame() async {
    final config = LanguageConfig.current;
    final allWords = await WordlistLoader.loadAssets(config.wordAssets);
    GameStore.instance.createRecord();
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    final newCtrl = ScrabbleGameController(allWords.toList(), config: config, turnTimeLimitSeconds: widget.turnTimeLimitSeconds);
    setState(() {
      _controller = newCtrl;
      _lastPhase = null;
      _error = '';
    });
    _attachListener(newCtrl);
    GameStore.instance.activeController = _controller;
  }

  void _onControllerUpdate() {
    final phase = _controller!.phase;
    if (phase != _lastPhase) {
      if (phase == GamePhase.aiTurn) {
        SoundService.instance.play(SFX.aiTurn);
      } else if (phase == GamePhase.gameOver) {
        final won = _controller!.playerScore > _controller!.aiScore;
        SoundService.instance.play(won ? SFX.win : SFX.lose);
        won ? HapticService.instance.win() : HapticService.instance.lose();
        // Turnuva modunda skoru geri döndür
        if (widget.tournamentMatchId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context, _controller!.playerScore);
          });
        }
      }
      _lastPhase = phase;
      // Faz değişimi tüm ekranı etkiliyor (AI sırası, game over banner)
      setState(() {});
      return;
    }
    // Normal hamle: sadece board, raf ve skor rebuild
    _boardNotifier.value++;
    _rackNotifier.value++;
    _scoreNotifier.value++;
  }

  void _onSubmit() {
    final ctrl = _controller!;
    final err = ctrl.submitMove();

    if (err == null) {
      if (ctrl.turnForfeited) {
        SoundService.instance.play(SFX.wordInvalid);
        HapticService.instance.wordInvalid();
        setState(() => _error = ctrl.message);
      } else {
        HapticService.instance.submit();
        SoundService.instance.play(SFX.wordValid);
        SoundService.instance.play(SFX.scoreUp);
        GameStore.instance.sync(ctrl, moveMade: true);
        if (_error.isNotEmpty) setState(() => _error = '');

        // Çalma gerçekleştiyse banner göster + 3s sonra temizle
        if (ctrl.lastStealResult?.success == true) {
          HapticService.instance.win();
          SoundService.instance.play(SFX.win);
          _showStealBanner(ctrl);
        }

        if (ctrl.highlightedCells.isNotEmpty || ctrl.stolenNewCells.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 3000), () {
            if (mounted) {
              ctrl.highlightedCells = {};
              ctrl.stolenNewCells   = {};
              _boardNotifier.value++;
            }
          });
        }
      }
    } else {
      SoundService.instance.play(SFX.wordInvalid);
      HapticService.instance.wordInvalid();
      setState(() => _error = err);

      final suggestion = ctrl.lastSuggestion;
      if (suggestion != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSuggestionSheet(suggestion);
        });
      }
    }
  }

  void _showStealBanner(ScrabbleGameController ctrl) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => StealBannerWidget(
        result:    ctrl.lastStealResult!,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  void _showSuggestionSheet(WordSuggestion suggestion) {
    final ctrl = _controller!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuggestionSheet(
        suggestion: suggestion,
        onAccept: () {
          Navigator.pop(context);
          ctrl.lastSuggestion = null;
          setState(() => _error = L.suggestionHint(suggestion.suggested));
        },
        onReject: () {
          Navigator.pop(context);
          ctrl.lastSuggestion = null;
        },
      ),
    );
  }

  void _showGameMenu() {
    final ctrl = _controller!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GameMenuSheet(
        tilesLeft: ctrl.tilesLeft,
        passesLeft: ctrl.passesLeft,
        rack: ctrl.playerRack,
        onPass: () {
          Navigator.pop(context);
          final err = ctrl.passTurn();
          if (err == null) SoundService.instance.play(SFX.passTurn);
          setState(() => _error = err ?? '');
        },
        onExchange: (tiles) {
          Navigator.pop(context);
          final err = ctrl.exchangeTiles(tiles);
          if (err == null) SoundService.instance.play(SFX.tileExchange);
          setState(() => _error = err ?? '');
        },
        onResign: () {
          ctrl.resign();
          setState(() => _error = '');
        },
      ),
    );
  }

  void _toggleChat() {
    setState(() => _hasUnread = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _FullScreenChat(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    final ctrl = _controller!;
    final isPlayer = ctrl.phase == GamePhase.playerTurn;
    final mainContent = Column(
      children: [
        // Minimal top bar
        ValueListenableBuilder<int>(
          valueListenable: _scoreNotifier,
          builder: (_, __, ___) => _TopBar(
            playerScore: ctrl.playerScore,
            aiScore: ctrl.aiScore,
            tilesLeft: ctrl.tilesLeft,
            phase: ctrl.phase,
            playerEnhancesLeft: ctrl.playerEnhancesLeft,
            onNewGame: _loadGame,
            canGoBack: Navigator.canPop(context),
            onChatTap: _toggleChat,
            hasUnread: _hasUnread,
          ),
        ),

        // Kelime önizleme
        ValueListenableBuilder<int>(
          valueListenable: _boardNotifier,
          builder: (_, __, ___) => _WordPreviewBar(words: ctrl.pendingWords),
        ),

        // Tahta — ekranın büyük bölümü
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) {
              _touchCtrl.viewportSize = constraints.biggest;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: GestureDetector(
                  onDoubleTapDown: (d) => _doubleTapDetails = d,
                  onDoubleTap: _handleDoubleTap,
                  child: InteractiveViewer(
                    transformationController: _zoomController,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 1.0,
                    maxScale: 4.0,
                    panEnabled: _touchCtrl.panEnabled,
                    onInteractionStart: (_) => _touchCtrl.onGestureStart(),
                    onInteractionEnd: (d) =>
                        _touchCtrl.onGestureEnd(d.velocity.pixelsPerSecond),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _boardNotifier,
                      builder: (_, __, ___) => ScrabbleBoardWidget(
                        board: ctrl.board,
                        highlightedCells: ctrl.highlightedCells,
                        stolenNewCells:   ctrl.stolenNewCells,
                        onTileDrop: isPlayer
                            ? (row, col, tile) {
                                ctrl.placeTile(row, col, tile);
                                HapticFeedback.selectionClick();
                                SoundService.instance.play(SFX.tilePlace);
                                if (_error.isNotEmpty || _selectedTile != null) {
                                  setState(() { _error = ''; _selectedTile = null; });
                                }
                              }
                            : null,
                        onCellTap: isPlayer
                            ? (row, col) => ctrl.recallTile(row, col)
                            : null,
                        onEmptyCellTap: isPlayer && _selectedTile != null
                            ? (row, col) {
                                ctrl.placeTile(row, col, _selectedTile!);
                                HapticFeedback.selectionClick();
                                SoundService.instance.play(SFX.tilePlace);
                                setState(() { _error = ''; _selectedTile = null; });
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Alt panel
        ValueListenableBuilder<int>(
          valueListenable: _rackNotifier,
          builder: (_, __, ___) => _BottomPanel(
            tiles: ctrl.playerRack,
            isEnabled: isPlayer,
            error: _error,
            phase: ctrl.phase,
            playerScore: ctrl.playerScore,
            aiScore: ctrl.aiScore,
            selectedTileId: _selectedTile?.id,
            onMenuTap: _showGameMenu,
            onTileTap: isPlayer
                ? (tile) => setState(() {
                      _selectedTile = _selectedTile?.id == tile.id ? null : tile;
                    })
                : null,
            onRecall: () {
              ctrl.recallAll();
              if (_error.isNotEmpty || _selectedTile != null) {
                setState(() { _error = ''; _selectedTile = null; });
              }
            },
            onShuffle: ctrl.shuffleRack,
            onPass: isPlayer
                ? () {
                    final err = ctrl.passTurn();
                    if (err == null) SoundService.instance.play(SFX.passTurn);
                    setState(() => _error = err ?? '');
                  }
                : null,
            onSubmit: _onSubmit,
            onRestart: _loadGame,
            isInStealMode: ctrl.isInStealMode,
            playerStealsLeft: ctrl.playerStealsLeft,
            onStealToggle: isPlayer ? () => setState(() => ctrl.toggleStealMode()) : null,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          mainContent,

        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _boardNotifier.dispose();
    _rackNotifier.dispose();
    _scoreNotifier.dispose();
    _zoomController.removeListener(_touchCtrl.onTransformChanged);
    _touchCtrl.dispose();
    _zoomController.dispose();
    super.dispose();
  }
}

// ── Tam ekran sohbet ────────────────────────────────────────────

class _FullScreenChat extends StatelessWidget {
  const _FullScreenChat();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_rounded, color: _kPrimary, size: 18),
            const SizedBox(width: 8),
            Text(L.chat,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
      body: const ChatScreen(),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int playerScore;
  final int aiScore;
  final int tilesLeft;
  final GamePhase phase;
  final int playerEnhancesLeft;
  final VoidCallback onNewGame;
  final VoidCallback onChatTap;
  final bool canGoBack;
  final bool hasUnread;
  const _TopBar({
    required this.playerScore,
    required this.aiScore,
    required this.tilesLeft,
    required this.phase,
    required this.playerEnhancesLeft,
    required this.onNewGame,
    required this.onChatTap,
    this.canGoBack = false,
    this.hasUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(10, top + 4, 10, 6),
      decoration: const BoxDecoration(
        color: _kTopStart,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Geri butonu
          if (canGoBack)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white38, size: 18),
              ),
            ),

          // Sol skor
          Expanded(child: _ScoreCard(
            label: L.current == AppLocale.tr ? 'Sen' : 'Ez',
            score: playerScore,
            isActive: phase == GamePhase.playerTurn,
            alignLeft: true,
          )),

          // Orta: torba + enhance badge + geri sayım
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$tilesLeft',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(width: 2),
                  Text(L.remaining,
                      style: const TextStyle(color: Colors.white30, fontSize: 9)),
                ],
              ),
              const SizedBox(height: 3),
              _EnhanceBadge(count: playerEnhancesLeft),
            ],
          ),

          // Sağ skor
          Expanded(child: _ScoreCard(
            label: 'AI',
            score: aiScore,
            isActive: phase == GamePhase.aiTurn,
            alignLeft: false,
          )),

          // 💬 Premium glass FAB
          _GlassChatBtn(onTap: onChatTap, hasUnread: hasUnread),
        ],
      ),
    );
  }
}

class _GlassChatBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool hasUnread;
  const _GlassChatBtn({required this.onTap, required this.hasUnread});

  @override
  State<_GlassChatBtn> createState() => _GlassChatBtnState();
}

class _GlassChatBtnState extends State<_GlassChatBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.hasUnread) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _GlassChatBtn old) {
    super.didUpdateWidget(old);
    if (widget.hasUnread && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.hasUnread) {
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
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final glow = widget.hasUnread ? (0.3 + 0.4 * _pulse.value) : 0.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    border: Border.all(
                      color: widget.hasUnread
                          ? const Color(0xFFFF4444).withOpacity(0.55 + 0.25 * _pulse.value)
                          : Colors.white.withOpacity(0.15),
                      width: 1.2,
                    ),
                    boxShadow: [
                      if (widget.hasUnread)
                        BoxShadow(
                          color: const Color(0xFFFF4444).withOpacity(glow),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white70, size: 18),
                ),
                if (widget.hasUnread)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F1923), width: 1.5),
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

// ── Geliştirme hakkı badge ────────────────────────────────────────

class _EnhanceBadge extends StatelessWidget {
  final int count;
  const _EnhanceBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = L.current == AppLocale.tr ? 'Geliştirme' : 'Pêşkeftin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0
            ? const Color(0xFFFFD700).withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: count > 0
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : Colors.white12,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 10,
            color: count > 0
                ? const Color(0xFFFFD700)
                : Colors.white24,
          ),
          const SizedBox(width: 3),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: count > 0 ? const Color(0xFFFFD700) : Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final int score;
  final bool isActive;
  final bool alignLeft;

  const _ScoreCard({required this.label, required this.score, required this.isActive, required this.alignLeft});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? _kActive.withOpacity(0.22) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? _kActive : Colors.transparent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isActive && !alignLeft)
                Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
                    decoration: const BoxDecoration(color: _kActive, shape: BoxShape.circle)),
              Text(label, style: TextStyle(color: isActive ? Colors.white70 : Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
              if (isActive && alignLeft)
                Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 5),
                    decoration: const BoxDecoration(color: _kActive, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOut),
              ),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$score',
              key: ValueKey(score),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom panel ─────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final List<GameTile> tiles;
  final bool isEnabled;
  final String error;
  final GamePhase phase;
  final int playerScore;
  final int aiScore;
  final String? selectedTileId;
  final void Function(GameTile)? onTileTap;
  final VoidCallback onRecall;
  final VoidCallback onShuffle;
  final VoidCallback? onPass;
  final VoidCallback onSubmit;
  final VoidCallback onRestart;
  final VoidCallback? onMenuTap;
  final bool isInStealMode;
  final int playerStealsLeft;
  final VoidCallback? onStealToggle;

  const _BottomPanel({
    required this.tiles,
    required this.isEnabled,
    required this.error,
    required this.phase,
    required this.playerScore,
    required this.aiScore,
    this.selectedTileId,
    this.onTileTap,
    required this.onRecall,
    required this.onShuffle,
    this.onPass,
    required this.onSubmit,
    required this.onRestart,
    this.onMenuTap,
    this.isInStealMode = false,
    this.playerStealsLeft = 2,
    this.onStealToggle,
  });

  static const _kSteal  = Color(0xFF00BFA5);
  static const _kStealActive = Color(0xFFFF6F00);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _kBottomBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: const Offset(0, -4))],
        border: isInStealMode
            ? Border.all(color: _kStealActive.withOpacity(0.7), width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 3,
            margin: const EdgeInsets.only(top: 8, bottom: 2),
            decoration: BoxDecoration(
                color: isInStealMode
                    ? _kStealActive.withOpacity(0.6)
                    : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2)),
          ),

          // Çalma modu banner'ı
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isInStealMode
                ? Container(
                    key: const ValueKey('steal_banner'),
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kStealActive.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kStealActive.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          L.stealModeActive,
                          style: TextStyle(
                            color: _kStealActive,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no_steal_banner')),
          ),

          // Hata mesajı
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: error.isNotEmpty
                ? Padding(
                    key: ValueKey(error),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kErrorColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kErrorColor.withOpacity(0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: _kErrorColor, size: 13),
                          const SizedBox(width: 5),
                          Flexible(
                              child: Text(error,
                                  style: const TextStyle(
                                      color: _kErrorColor, fontSize: 11))),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // AI turu göstergesi — premium thinking pill
          if (phase == GamePhase.aiTurn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Center(child: _AiThinkingPill()),
            ),

          // Harf rafı
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: LetterRackWidget(
              tiles: tiles,
              enabled: isEnabled,
              selectedTileId: selectedTileId,
              onTileTap: onTileTap,
            ),
          ),

          // Küçük eylem butonları
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Row(
              children: [
                _ActionBtn(
                  icon: Icons.undo_rounded,
                  label: L.recall,
                  enabled: isEnabled,
                  onTap: isEnabled ? onRecall : null,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.skip_next_rounded,
                  label: L.passTurn,
                  enabled: isEnabled && onPass != null,
                  onTap: (isEnabled && onPass != null) ? onPass : null,
                ),
                const SizedBox(width: 6),
                // ── Çal butonu ─────────────────────────────────
                _StealBtn(
                  isEnabled: isEnabled && playerStealsLeft > 0,
                  isActive: isInStealMode,
                  stealsLeft: playerStealsLeft,
                  onTap: isEnabled ? onStealToggle : null,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.more_horiz_rounded,
                  label: L.options,
                  enabled: isEnabled,
                  onTap: isEnabled ? onMenuTap : null,
                ),
              ],
            ),
          ),

          // Büyük "Bilîze" butonu
          Padding(
            padding: EdgeInsets.fromLTRB(10, 6, 10, bottom + 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? onSubmit : null,
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(L.play,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF2A2A2A),
                  disabledForegroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: isEnabled ? 6 : 0,
                  shadowColor: _kPrimary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),

          if (phase == GamePhase.gameOver)
            _GameOverBanner(
                playerScore: playerScore,
                aiScore: aiScore,
                onRestart: onRestart),
        ],
      ),
    );
  }
}

// Küçük ikon+etiket aksiyon butonu
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(enabled ? 0.06 : 0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.white.withOpacity(enabled ? 0.14 : 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: enabled ? Colors.white60 : Colors.white.withOpacity(0.20),
                  size: 18),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: enabled
                          ? Colors.white.withOpacity(0.45)
                          : Colors.white.withOpacity(0.15),
                      fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Çalma butonu ─────────────────────────────────────────────────

class _StealBtn extends StatelessWidget {
  final bool isEnabled;
  final bool isActive;
  final int stealsLeft;
  final VoidCallback? onTap;

  const _StealBtn({
    required this.isEnabled,
    required this.isActive,
    required this.stealsLeft,
    this.onTap,
  });

  static const _kSteal       = Color(0xFF00BFA5);
  static const _kStealActive = Color(0xFFFF6F00);

  @override
  Widget build(BuildContext context) {
    final color  = isActive ? _kStealActive : _kSteal;
    final dimmed = !isEnabled && !isActive;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: dimmed
                ? Colors.white.withOpacity(0.02)
                : isActive
                    ? _kStealActive.withOpacity(0.15)
                    : _kSteal.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: dimmed
                  ? Colors.white.withOpacity(0.05)
                  : color.withOpacity(isActive ? 0.75 : 0.45),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: _kStealActive.withOpacity(0.25), blurRadius: 8)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isActive ? '⚡' : '🎯',
                style: const TextStyle(fontSize: 14, height: 1),
              ),
              const SizedBox(height: 3),
              Text(
                isActive ? L.steal : '${L.steal} (${stealsLeft})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dimmed
                      ? Colors.white.withOpacity(0.15)
                      : color,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
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

  void _showMeaning(BuildContext context, String word) {
    final meaning = KurdishMeanings.meaning(word) ?? L.meaningNotFound;
    HapticFeedback.selectionClick();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _WordMeaningBubble(
        word: word,
        meaning: meaning,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFFEDE8DF),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: words.map((e) {
          final isValid = e.valid;
          return GestureDetector(
            onTap: isValid ? () => _showMeaning(context, e.word) : null,
            onLongPress: isValid
                ? () {
                    HapticFeedback.lightImpact();
                    WordDetailPopup.show(context, e.word);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isValid
                    ? const Color(0xFF4CAF50).withOpacity(0.12)
                    : const Color(0xFFFF6B6B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isValid ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isValid ? Icons.check_circle : Icons.cancel,
                    size: 13,
                    color: isValid ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.word,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isValid ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C),
                    ),
                  ),
                  if (isValid) ...[
                    const SizedBox(width: 4),
                    Text(
                      '+${e.score}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(L.revealMeaning,
                          style: const TextStyle(fontSize: 9, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WordMeaningBubble extends StatefulWidget {
  final String word;
  final String meaning;
  final VoidCallback onDismiss;

  const _WordMeaningBubble({
    required this.word,
    required this.meaning,
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

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      left: 0,
      right: 0,
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
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A3A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.word,
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(height: 1, color: Colors.white.withOpacity(0.08)),
                      const SizedBox(height: 8),
                      Text(
                        widget.meaning,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        L.current == AppLocale.tr
                            ? 'Kürmanci • dokunarak kapat'
                            : 'Kurmancî • destê xwe lê bide da bigire',
                        style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10),
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

// ── Game over ────────────────────────────────────────────────────

class _GameOverBanner extends StatelessWidget {
  final int playerScore;
  final int aiScore;
  final VoidCallback onRestart;

  const _GameOverBanner({required this.playerScore, required this.aiScore, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final won = playerScore >= aiScore;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: won
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFF7B0000), const Color(0xFFB71C1C)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            won ? L.won : L.lost,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('$playerScore - $aiScore', style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRestart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: won ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(L.newGameBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Game menu bottom sheet ────────────────────────────────────────

class _GameMenuSheet extends StatefulWidget {
  final int tilesLeft;
  final int passesLeft;
  final List<GameTile> rack;
  final VoidCallback onPass;
  final void Function(List<GameTile>) onExchange;
  final VoidCallback onResign;

  const _GameMenuSheet({
    required this.tilesLeft,
    required this.passesLeft,
    required this.rack,
    required this.onPass,
    required this.onExchange,
    required this.onResign,
  });

  @override
  State<_GameMenuSheet> createState() => _GameMenuSheetState();
}

class _GameMenuSheetState extends State<_GameMenuSheet> {
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
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),
        Text(L.options,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _SheetOption(
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
        _SheetOption(
          icon: Icons.swap_horiz_rounded,
          iconColor: const Color(0xFFFFB74D),
          title: L.exchangeTiles,
          subtitle: widget.tilesLeft > 0
              ? '${L.tilesLeft}: ${widget.tilesLeft} — ${L.exchangeSub}'
              : L.noTilesInBag,
          enabled: widget.tilesLeft > 0,
          onTap: widget.tilesLeft > 0 ? () => setState(() => _exchangeMode = true) : null,
        ),
        const SizedBox(height: 10),
        _SheetOption(
          icon: Icons.flag_rounded,
          iconColor: const Color(0xFFFF6B6B),
          title: L.resign,
          subtitle: L.resignSub,
          onTap: () {
            final sheetCtx = context;
            showDialog(
              context: sheetCtx,
              builder: (dialogCtx) => AlertDialog(
                backgroundColor: const Color(0xFF1E2A3A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(L.resign, style: const TextStyle(color: Colors.white)),
                content: Text(L.resignConfirm, style: const TextStyle(color: Colors.white60)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(L.cancel, style: const TextStyle(color: Colors.white38)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      Navigator.pop(sheetCtx);
                      widget.onResign();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(L.resign),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExchangeView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() { _exchangeMode = false; _selected.clear(); }),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 18),
            ),
            const SizedBox(width: 12),
            Text(L.exchangeTitle,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Text(L.exchangeSub,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.rack.map((tile) {
            final isSelected = _selected.contains(tile.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) _selected.remove(tile.id);
                else _selected.add(tile.id);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42,
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 3),
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
                    color: isSelected ? const Color(0xFFFF8F00) : const Color(0xFFB8860B),
                    width: isSelected ? 2.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFFFFC107).withOpacity(0.6)
                          : Colors.black.withOpacity(0.3),
                      blurRadius: isSelected ? 8 : 3,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(tile.letter,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2723))),
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
                onPressed: () => setState(() { _exchangeMode = false; _selected.clear(); }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(L.cancel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selected.isEmpty ? null : () {
                  final tiles = widget.rack.where((t) => _selected.contains(t.id)).toList();
                  widget.onExchange(tiles);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _SheetOption({
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
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.04),
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: enabled ? Colors.white : Colors.white54,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 20),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ── Suggestion sheet ─────────────────────────────────────────────

class _SuggestionSheet extends StatelessWidget {
  final WordSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SuggestionSheet({
    required this.suggestion,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFB74D), size: 32),
          const SizedBox(height: 12),
          Text(
            L.didYouMean(suggestion.suggested),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"${suggestion.original}"',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(L.suggestionReject,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB74D),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(L.suggestionAccept,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── AI thinking pill ─────────────────────────────────────────────

class _AiThinkingPill extends StatefulWidget {
  @override
  State<_AiThinkingPill> createState() => _AiThinkingPillState();
}

class _AiThinkingPillState extends State<_AiThinkingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
        final glow = 0.35 + 0.25 * (0.5 + 0.5 * (1 - (2 * _ctrl.value - 1).abs()));
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF7B1FA2).withOpacity(0.18),
                const Color(0xFF9C27B0).withOpacity(0.22),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFCE93D8).withOpacity(0.45), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C27B0).withOpacity(glow * 0.6),
                blurRadius: 14,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.psychology_rounded,
                  color: Color(0xFFE1BEE7), size: 16),
              const SizedBox(width: 8),
              Text(
                L.aiTurn,
                style: const TextStyle(
                  color: Color(0xFFEDE7F6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              _AiDot(active: _ctrl.value < 0.33),
              const SizedBox(width: 3),
              _AiDot(active: _ctrl.value >= 0.33 && _ctrl.value < 0.66),
              const SizedBox(width: 3),
              _AiDot(active: _ctrl.value >= 0.66),
            ],
          ),
        );
      },
    );
  }
}

class _AiDot extends StatelessWidget {
  final bool active;
  const _AiDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 4, height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? const Color(0xFFE1BEE7)
            : const Color(0xFFE1BEE7).withOpacity(0.30),
      ),
    );
  }
}
