import 'package:flutter/material.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:kurdle_app/controllers/scrabble_game_controller.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/game_store.dart';
import 'package:kurdle_app/services/kurdish_meanings.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/widgets/chat_screen.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/widgets/letter_rack_widget.dart';
import 'package:kurdle_app/widgets/scrabble_board_widget.dart';

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
  const ScrabbleGameScreen({Key? key, this.existingController}) : super(key: key);

  @override
  State<ScrabbleGameScreen> createState() => _ScrabbleGameScreenState();
}

class _ScrabbleGameScreenState extends State<ScrabbleGameScreen> {
  ScrabbleGameController? _controller;
  String _error = '';
  GameTile? _selectedTile;
  GamePhase? _lastPhase;
  DateTime _startTime = DateTime.now();

  // ValueNotifier'lar ile sadece ilgili widget rebuild olur
  final _boardNotifier  = ValueNotifier<int>(0);
  final _rackNotifier   = ValueNotifier<int>(0);
  final _scoreNotifier  = ValueNotifier<int>(0);
  VoidCallback? _controllerListener;

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
    final ls = const LineSplitter();
    final allWords = <String>{};
    for (final assetPath in config.wordAssets) {
      final lines = ls.convert(await rootBundle.loadString(assetPath));
      allWords.addAll(lines);
    }
    GameStore.instance.createRecord();
    _startTime = DateTime.now();
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    final newCtrl = ScrabbleGameController(allWords.toList(), config: config);
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
        _saveToFirestore(won);
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

  Future<void> _saveToFirestore(bool won) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    await FirestoreService.instance.saveGameResult(
      uid: uid,
      playerScore: _controller!.playerScore,
      aiScore: _controller!.aiScore,
      won: won,
      durationSeconds: DateTime.now().difference(_startTime).inSeconds,
    );
  }

  void _onSubmit() {
    final err = _controller!.submitMove();
    if (err == null) {
      HapticFeedback.lightImpact();
      SoundService.instance.play(SFX.wordValid);
      SoundService.instance.play(SFX.scoreUp);
      if (_error.isNotEmpty) setState(() => _error = '');
    } else {
      SoundService.instance.play(SFX.wordInvalid);
      setState(() => _error = err);
    }
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

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Skor/faz/kalan — sadece _scoreNotifier değişince rebuild
          ValueListenableBuilder<int>(
            valueListenable: _scoreNotifier,
            builder: (_, __, ___) => _TopBar(
              playerScore: ctrl.playerScore,
              aiScore: ctrl.aiScore,
              tilesLeft: ctrl.tilesLeft,
              phase: ctrl.phase,
              onNewGame: _loadGame,
              canGoBack: Navigator.canPop(context),
            ),
          ),

          // Kelime önizleme — sadece _boardNotifier değişince rebuild
          ValueListenableBuilder<int>(
            valueListenable: _boardNotifier,
            builder: (_, __, ___) => _WordPreviewBar(words: ctrl.pendingWords),
          ),

          // Tahta — sadece _boardNotifier değişince rebuild
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _boardNotifier,
                  builder: (_, __, ___) => ScrabbleBoardWidget(
                    board: ctrl.board,
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
                        ? (row, col) {
                            ctrl.recallTile(row, col);
                          }
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
          ),

          // Raf + alt panel — sadece _rackNotifier değişince rebuild
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
              onSubmit: _onSubmit,
              onRestart: _loadGame,
            ),
          ),
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
    super.dispose();
  }
}

// ── Top bar ─────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int playerScore;
  final int aiScore;
  final int tilesLeft;
  final GamePhase phase;
  final VoidCallback onNewGame;
  final bool canGoBack;

  const _TopBar({
    required this.playerScore,
    required this.aiScore,
    required this.tilesLeft,
    required this.phase,
    required this.onNewGame,
    this.canGoBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kTopStart, _kTopEnd],
        ),
      ),
      child: Row(
        children: [
          if (canGoBack)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 20),
              ),
            ),
          Expanded(child: _ScoreCard(label: _s('Sen', 'Ez'), score: playerScore, isActive: phase == GamePhase.playerTurn, alignLeft: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$tilesLeft',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 2),
                Text(L.remaining, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onNewGame,
                      child: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kPrimary.withOpacity(0.45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_rounded, color: _kPrimary, size: 12),
                            const SizedBox(width: 4),
                            Text(L.chat, style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _ScoreCard(label: 'AI', score: aiScore, isActive: phase == GamePhase.aiTurn, alignLeft: false)),
        ],
      ),
    );
  }

  static String _s(String tr, String ku) => L.current == AppLocale.tr ? tr : ku;
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
  final VoidCallback onSubmit;
  final VoidCallback onRestart;
  final VoidCallback? onMenuTap;

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
    required this.onSubmit,
    required this.onRestart,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _kBottomBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: error.isNotEmpty
                ? Padding(
                    key: ValueKey(error),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _kErrorColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kErrorColor.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: _kErrorColor, size: 15),
                          const SizedBox(width: 6),
                          Flexible(child: Text(error, style: const TextStyle(color: _kErrorColor, fontSize: 12))),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          if (phase == GamePhase.aiTurn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
                  ),
                  const SizedBox(width: 8),
                  Text(L.aiTurn, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: LetterRackWidget(
              tiles: tiles,
              enabled: isEnabled,
              selectedTileId: selectedTileId,
              onTileTap: onTileTap,
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: isEnabled ? onMenuTap : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isEnabled ? 0.07 : 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(isEnabled ? 0.2 : 0.08),
                      ),
                    ),
                    child: Icon(Icons.more_horiz_rounded,
                        color: isEnabled ? Colors.white60 : Colors.white24, size: 22),
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isEnabled ? onRecall : null,
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: Text(L.recall, style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isEnabled ? Colors.white70 : Colors.white24,
                      side: BorderSide(color: isEnabled ? Colors.white30 : Colors.white12),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isEnabled ? onShuffle : null,
                    icon: const Icon(Icons.shuffle_rounded, size: 16),
                    label: Text(L.shuffle, style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isEnabled ? Colors.white70 : Colors.white24,
                      side: BorderSide(color: isEnabled ? Colors.white30 : Colors.white12),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: isEnabled ? onSubmit : null,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(L.play, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: isEnabled ? 4 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (phase == GamePhase.gameOver)
            _GameOverBanner(playerScore: playerScore, aiScore: aiScore, onRestart: onRestart),
        ],
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
    if (words.isEmpty) return const SizedBox(height: 4);
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
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
