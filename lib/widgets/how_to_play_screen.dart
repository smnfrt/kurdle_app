import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';

// ── Design tokens ────────────────────────────────────────────────
const _kBg = Color(0xFF0F1923);
const _kSurface = Color(0xFF1A2535);
const _kPrimary = Color(0xFF4CAF50);
const _kGold = Color(0xFFFFD700);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
Color _helpBg(BuildContext context) =>
    _isDark(context) ? _kBg : const Color(0xFFE6EEF2);
Color _helpSurface(BuildContext context) =>
    _isDark(context) ? _kSurface : const Color(0xFFF4F8FA);
Color _helpSurfaceAlt(BuildContext context) =>
    _isDark(context) ? const Color(0xFF141E2B) : const Color(0xFFEAF1F4);
Color _helpTitle(BuildContext context) =>
    _isDark(context) ? Colors.white : const Color(0xFF18242C);
Color _helpMuted(BuildContext context) =>
    _isDark(context) ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF52636E);
Color _helpWeak(BuildContext context) =>
    _isDark(context) ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF667681);
Color _helpBorder(BuildContext context) =>
    _isDark(context) ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD6E1E7);

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen>
    with TickerProviderStateMixin {
  // ── Demo animasyonu ──────────────────────────────────────────
  late AnimationController _demoCtrl;
  final List<_DemoTile> _tiles = [];
  bool _wordValid = false;
  bool _scoreShown = false;
  int _scoreValue = 0;

  // ── Staggered adımlar ────────────────────────────────────────
  final List<AnimationController> _stepCtrls = [];
  final List<Animation<double>> _stepFades = [];
  final List<Animation<Offset>> _stepSlides = [];

  static const _demoWord = ['B', 'A', 'J', 'A', 'R'];
  static const _demoPoints = [2, 1, 4, 1, 1]; // her harfin puanı

  static const _steps = [
    (
      icon: Icons.drag_indicator_rounded,
      color: Color(0xFF64B5F6),
      titleKey: 'step1Title',
      bodyKey: 'step1Body'
    ),
    (
      icon: Icons.spellcheck_rounded,
      color: Color(0xFF81C784),
      titleKey: 'step2Title',
      bodyKey: 'step2Body'
    ),
    (
      icon: Icons.smart_toy_rounded,
      color: Color(0xFFFFB74D),
      titleKey: 'step3Title',
      bodyKey: 'step3Body'
    ),
    (
      icon: Icons.star_rounded,
      color: Color(0xFFFFD700),
      titleKey: 'step4Title',
      bodyKey: 'step4Body'
    ),
    (
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFBA68C8),
      titleKey: 'step5Title',
      bodyKey: 'step5Body'
    ),
  ];

  @override
  void initState() {
    super.initState();

    _demoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    for (var i = 0; i < _steps.length; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 450));
      _stepCtrls.add(ctrl);
      _stepFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _stepSlides.add(Tween<Offset>(
              begin: const Offset(0.18, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
    }

    // Biraz gecikmeyle demo başlasın
    Future.delayed(const Duration(milliseconds: 600), _runDemo);
  }

  @override
  void dispose() {
    _demoCtrl.dispose();
    for (final c in _stepCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Demo sekansı ─────────────────────────────────────────────

  Future<void> _runDemo() async {
    if (!mounted) return;
    setState(() {
      _tiles.clear();
      _wordValid = false;
      _scoreShown = false;
      _scoreValue = 0;
    });

    // Harfleri tek tek yerleştir
    for (var i = 0; i < _demoWord.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 320));
      HapticFeedback.selectionClick();
      setState(() {
        _tiles.add(_DemoTile(
            letter: _demoWord[i],
            points: _demoPoints[i],
            state: _TileState.pending));
      });
    }

    // Kısa bekleme → doğrulama
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Harfleri sırayla yeşile çevir
    for (var i = 0; i < _tiles.length; i++) {
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _tiles[i] = _DemoTile(
            letter: _tiles[i].letter,
            points: _tiles[i].points,
            state: _TileState.valid,
          ));
    }

    // Skor sayacı
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _wordValid = true;
      _scoreShown = true;
    });

    final total = _demoPoints.fold(0, (a, b) => a + b);
    for (var v = 1; v <= total; v++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _scoreValue = v);
    }

    // Adımları staggered göster
    await Future.delayed(const Duration(milliseconds: 500));
    for (var i = 0; i < _stepCtrls.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 140));
      _stepCtrls[i].forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDark = _isDark(context);

    return Scaffold(
      backgroundColor: _helpBg(context),
      body: Column(
        children: [
          // ── App bar ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14),
            decoration: BoxDecoration(
              color: _helpSurface(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : const Color(0xFFEAF1F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: _helpMuted(context), size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(L.howToPlayShort,
                          style: TextStyle(
                              color: _helpTitle(context),
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text(L.appSubtitle,
                          style: TextStyle(
                              color: _helpWeak(context), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── İçerik ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, bottom + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Günün Kelimesi bölümü ────────────────────────
                  _SectionHeader(
                    icon: Icons.today_rounded,
                    color: const Color(0xFF4CAF50),
                    title: L.wordleSectionTitle,
                  ),
                  const SizedBox(height: 12),
                  _WordleDemoCard(),
                  const SizedBox(height: 32),

                  // ── Scrabble bölümü ──────────────────────────────
                  _SectionHeader(
                    icon: Icons.grid_4x4_rounded,
                    color: const Color(0xFF64B5F6),
                    title: L.scrabbleSectionTitle,
                  ),
                  const SizedBox(height: 12),

                  // Demo kartı
                  _DemoCard(
                    tiles: _tiles,
                    wordValid: _wordValid,
                    scoreShown: _scoreShown,
                    scoreValue: _scoreValue,
                    totalLetters: _demoWord.length,
                  ),

                  const SizedBox(height: 16),

                  // Tahta yerleştirme demo
                  const _BoardDemoCard(),

                  const SizedBox(height: 32),

                  // Bölüm başlığı
                  Text(
                    L.rulesTitle.toUpperCase(),
                    style: TextStyle(
                      color: _helpWeak(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Staggered adımlar
                  for (var i = 0; i < _steps.length; i++)
                    FadeTransition(
                      opacity: _stepFades[i],
                      child: SlideTransition(
                        position: _stepSlides[i],
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StepCard(
                            step: i + 1,
                            icon: _steps[i].icon,
                            color: _steps[i].color,
                            title: _stepTitle(i),
                            body: _stepBody(i),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Harf değerleri legend
                  _PointsLegend(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stepTitle(int i) {
    final titles = [
      L.step1Title,
      L.step2Title,
      L.step3Title,
      L.step4Title,
      L.step5Title,
    ];
    return titles[i];
  }

  String _stepBody(int i) {
    final bodies = [
      L.step1Body,
      L.step2Body,
      L.step3Body,
      L.step4Body,
      L.step5Body,
    ];
    return bodies[i];
  }
}

// ── Demo kartı ───────────────────────────────────────────────────

class _DemoCard extends StatelessWidget {
  final List<_DemoTile> tiles;
  final bool wordValid;
  final bool scoreShown;
  final int scoreValue;
  final int totalLetters;

  const _DemoCard({
    required this.tiles,
    required this.wordValid,
    required this.scoreShown,
    required this.scoreValue,
    required this.totalLetters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _helpSurface(context),
            _helpSurfaceAlt(context),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: wordValid ? _kPrimary.withValues(alpha: 0.5) : _helpBorder(context),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: wordValid
                ? _kPrimary.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: wordValid ? _kPrimary : Colors.white24,
                  shape: BoxShape.circle,
                  boxShadow: wordValid
                      ? [
                          BoxShadow(
                              color: _kPrimary.withValues(alpha: 0.6), blurRadius: 6)
                        ]
                      : [],
                ),
              ),
              Text(
                L.demoLabel,
                style: TextStyle(
                  color: _helpMuted(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tile slotları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalLetters, (i) {
              if (i < tiles.length) {
                return _AnimatedTileWidget(tile: tiles[i]);
              }
              // Boş slot
              return Container(
                width: 50,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFE2EBF0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _helpBorder(context), width: 1.5),
                ),
              );
            }),
          ),

          // Skor
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 400),
            firstChild: const SizedBox(height: 16),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, color: _kGold, size: 16),
                  const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 80),
                    child: Text(
                      '+$scoreValue ${L.points}',
                      key: ValueKey(scoreValue),
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(L.validWord,
                        style: const TextStyle(
                            color: _kPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            crossFadeState: scoreShown
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

// ── Animasyonlu tile ─────────────────────────────────────────────

class _AnimatedTileWidget extends StatefulWidget {
  final _DemoTile tile;
  const _AnimatedTileWidget({required this.tile});

  @override
  State<_AnimatedTileWidget> createState() => _AnimatedTileWidgetState();
}

class _AnimatedTileWidgetState extends State<_AnimatedTileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.12), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _flip = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedTileWidget old) {
    super.didUpdateWidget(old);
    if (old.tile.state != widget.tile.state &&
        widget.tile.state == _TileState.valid) {
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = widget.tile.state == _TileState.valid;
    final isDark = _isDark(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final flipVal = _flip.value;
        // 0→0.5 ön yüz, 0.5→1 arka yüz (renk değişimi simüle etmek için)
        final showBack = flipVal > 0.5 && isValid;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(
                (flipVal * 3.14159).clamp(0, 3.14159) * (isValid ? 1 : 0)),
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 50,
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: showBack
                    ? _kPrimary.withValues(alpha: 0.85)
                    : (isDark
                        ? const Color(0xFF253345)
                        : const Color(0xFFF4F8FA)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: showBack
                      ? _kPrimary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.22)
                          : const Color(0xFFD6E1E7)),
                  width: 1.8,
                ),
                boxShadow: showBack
                    ? [
                        BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ]
                    : [
                        BoxShadow(
                            color:
                                Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      widget.tile.letter,
                      style: TextStyle(
                        color: showBack
                            ? Colors.white
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.9)
                                : const Color(0xFF18242C)),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 5,
                    bottom: 4,
                    child: Text(
                      '${widget.tile.points}',
                      style: TextStyle(
                        color: showBack
                            ? Colors.white70
                            : (isDark
                                ? Colors.white30
                                : const Color(0xFF667681)),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Adım kartı ───────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _helpSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _helpBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Adım numarası + ikon
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$step',
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(title,
                    style: TextStyle(
                        color: _helpTitle(context),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(body,
                    style: TextStyle(
                        color: _helpMuted(context), fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Harf puanları legend ─────────────────────────────────────────

class _PointsLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = _isDark(context);
    final groups = [
      (
        label: '1 ${L.points}',
        letters: 'A E I N R T',
        color: isDark ? Colors.white60 : const Color(0xFF52636E)
      ),
      (
        label: '2 ${L.points}',
        letters: 'B D K L M S U',
        color: const Color(0xFF81C784)
      ),
      (
        label: '3-4 ${L.points}',
        letters: 'C G H O V Y Ç Ş',
        color: const Color(0xFF64B5F6)
      ),
      (label: '5+ ${L.points}', letters: 'Ê Î Û Q X', color: _kGold),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _helpSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _helpBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded,
                  color: _helpWeak(context), size: 15),
              const SizedBox(width: 8),
              Text(
                L.letterValues.toUpperCase(),
                style: TextStyle(
                  color: _helpWeak(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final g in groups) ...[
            Row(
              children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: g.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: g.color.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(g.label,
                        style: TextStyle(
                            color: g.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(g.letters,
                      style: TextStyle(
                          color: _helpMuted(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Tahta yerleştirme demo ────────────────────────────────────────

class _BoardDemoCard extends StatefulWidget {
  const _BoardDemoCard();
  @override
  State<_BoardDemoCard> createState() => _BoardDemoCardState();
}

class _BoardDemoCardState extends State<_BoardDemoCard>
    with SingleTickerProviderStateMixin {
  // Geometry
  static const _cellSz = 30.0;
  static const _cellGap = 1.5;
  static const _gridN = 7;
  static const _tileSz = 42.0;
  static const _tileH = 50.0;
  static const _tileGap = 8.0;
  static const _boardY = 36.0;

  // Demo word
  static const _word = ['B', 'A', 'J', 'A', 'R'];
  static const _pts = [2, 1, 4, 1, 1];
  static const _targets = [(3, 1), (3, 2), (3, 3), (3, 4), (3, 5)];

  // Computed geometry
  double _boardX = 0, _rackX = 0, _rackY = 0, _cardH = 400;

  // State
  var _grid = List.generate(_gridN, (_) => List.filled(_gridN, ''));
  int _activeTile = -1;
  bool _isFlying = false;
  String _flyLetter = '';
  int _flyPts = 0;
  Offset _flyFrom = Offset.zero;
  Offset _flyTo = Offset.zero;
  bool _wordValid = false;

  late AnimationController _flyCtrl;
  late Animation<double> _flyAnim;

  @override
  void initState() {
    super.initState();
    _flyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560));
    _flyAnim = CurvedAnimation(parent: _flyCtrl, curve: Curves.easeInOutCubic);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => Future.delayed(const Duration(milliseconds: 900), _runDemo));
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    super.dispose();
  }

  void _computeGeometry(double W) {
    final boardW = _gridN * _cellSz + (_gridN - 1) * _cellGap;
    final rackW = _word.length * _tileSz + (_word.length - 1) * _tileGap;
    _boardX = (W - boardW) / 2;
    _rackX = (W - rackW) / 2;
    _rackY = _boardY + _gridN * (_cellSz + _cellGap) + 18;
    _cardH = _rackY + _tileH + 28;
  }

  Future<void> _runDemo() async {
    if (!mounted) return;
    setState(() {
      _grid = List.generate(_gridN, (_) => List.filled(_gridN, ''));
      _wordValid = false;
      _activeTile = -1;
      _isFlying = false;
    });

    for (var i = 0; i < _word.length; i++) {
      if (!mounted) return;

      // 1) Harf kalkıyor
      HapticFeedback.selectionClick();
      setState(() => _activeTile = i);
      await Future.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;

      // 2) Uçuş başlıyor
      final col = _targets[i].$2;
      final row = _targets[i].$1;
      final fromCx = _rackX + i * (_tileSz + _tileGap) + _tileSz / 2;
      final fromCy = _rackY + _tileH / 2;
      final toCx = _boardX + col * (_cellSz + _cellGap) + _cellSz / 2;
      final toCy = _boardY + row * (_cellSz + _cellGap) + _cellSz / 2;

      setState(() {
        _flyLetter = _word[i];
        _flyPts = _pts[i];
        _flyFrom = Offset(fromCx, fromCy);
        _flyTo = Offset(toCx, toCy);
        _isFlying = true;
        _activeTile = -1;
      });

      _flyCtrl.reset();
      await _flyCtrl.forward();
      if (!mounted) return;

      // 3) Hücreye iniyor
      HapticFeedback.lightImpact();
      setState(() {
        _isFlying = false;
        _grid[row][col] = _word[i];
      });
      await Future.delayed(const Duration(milliseconds: 160));
    }

    // 4) Kelime onayı — yeşil
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _wordValid = true);

    // 5) Sıfırla & tekrar
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    setState(() {
      _wordValid = false;
      _grid = List.generate(_gridN, (_) => List.filled(_gridN, ''));
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _runDemo();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      _computeGeometry(constraints.maxWidth);
      final isDark = _isDark(context);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        height: _cardH,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_helpSurface(context), _helpSurfaceAlt(context)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                _wordValid ? _kPrimary.withValues(alpha: 0.5) : _helpBorder(context),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _wordValid
                  ? _kPrimary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Etiket
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_indicator_rounded,
                        color: Color(0xFF64B5F6), size: 13),
                    const SizedBox(width: 5),
                    Text(
                      L.boardDemoLabel,
                      style: TextStyle(
                        color: _helpWeak(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Mini tahta
            Positioned(
              left: _boardX,
              top: _boardY,
              child: _MiniBoard(
                grid: _grid,
                wordValid: _wordValid,
                targets: const [(3, 1), (3, 2), (3, 3), (3, 4), (3, 5)],
                cellSz: _cellSz,
                cellGap: _cellGap,
                gridN: _gridN,
              ),
            ),

            // Raf
            Positioned(
              left: _rackX,
              top: _rackY,
              child: _buildRack(),
            ),

            // Uçan harf
            if (_isFlying)
              AnimatedBuilder(
                animation: _flyAnim,
                builder: (_, __) {
                  final t = _flyAnim.value;
                  final arcY = -38.0 * math.sin(t * math.pi);
                  final w = _tileSz + (_cellSz - _tileSz) * t;
                  final h = _tileH + (_cellSz - _tileH) * t;
                  final cx = _flyFrom.dx + (_flyTo.dx - _flyFrom.dx) * t;
                  final cy = _flyFrom.dy + (_flyTo.dy - _flyFrom.dy) * t + arcY;
                  return Positioned(
                    left: cx - w / 2,
                    top: cy - h / 2,
                    child: _FlyingTile(
                        letter: _flyLetter, points: _flyPts, w: w, h: h),
                  );
                },
              ),

            // Puan rozeti
            if (_wordValid)
              Positioned(
                right: 14,
                top: _boardY + 3 * (_cellSz + _cellGap),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.5), blurRadius: 10)
                      ],
                    ),
                    child: Text('+9 ${L.points}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildRack() {
    final isDark = _isDark(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_word.length, (i) {
        final isActive = i == _activeTile;
        final row = _targets[i].$1;
        final col = _targets[i].$2;
        final isPlaced = _grid[row][col].isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: _tileSz,
          height: _tileH,
          margin: EdgeInsets.only(right: i < _word.length - 1 ? _tileGap : 0),
          transform: Matrix4.identity()..translate(0.0, isActive ? -10.0 : 0.0),
          decoration: BoxDecoration(
            gradient: isPlaced
                ? LinearGradient(colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2EBF0),
                    isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2EBF0),
                  ])
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isActive
                        ? [const Color(0xFFFFF8E1), const Color(0xFFE8C46A)]
                        : [const Color(0xFFFFF3C7), const Color(0xFFDEB887)],
                  ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPlaced
                  ? (isDark ? Colors.white12 : const Color(0xFFD6E1E7))
                  : isActive
                      ? const Color(0xFFB8860B)
                      : const Color(0xFFB8860B).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ]
                : isPlaced
                    ? []
                    : const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 3,
                            offset: Offset(0, 2))
                      ],
          ),
          child: isPlaced
              ? null
              : Stack(children: [
                  Center(
                    child: Text(_word[i],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? const Color(0xFF3E2723)
                              : const Color(0xFF5D4037),
                          height: 1,
                        )),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 3,
                    child: Text('${_pts[i]}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D6E63),
                        )),
                  ),
                ]),
        );
      }),
    );
  }
}

// ── Mini tahta ────────────────────────────────────────────────────

class _MiniBoard extends StatelessWidget {
  final List<List<String>> grid;
  final bool wordValid;
  final List<(int, int)> targets;
  final double cellSz, cellGap;
  final int gridN;

  const _MiniBoard({
    required this.grid,
    required this.wordValid,
    required this.targets,
    required this.cellSz,
    required this.cellGap,
    required this.gridN,
  });

  static const _bonusMap = {
    (0, 0): ('TW', Color(0xFFFF6B6B)),
    (0, 6): ('TW', Color(0xFFFF6B6B)),
    (6, 0): ('TW', Color(0xFFFF6B6B)),
    (6, 6): ('TW', Color(0xFFFF6B6B)),
    (1, 1): ('DW', Color(0xFFFFB347)),
    (2, 2): ('DW', Color(0xFFFFB347)),
    (4, 4): ('DW', Color(0xFFFFB347)),
    (5, 5): ('DW', Color(0xFFFFB347)),
    (1, 5): ('DW', Color(0xFFFFB347)),
    (5, 1): ('DW', Color(0xFFFFB347)),
    (2, 4): ('DW', Color(0xFFFFB347)),
    (4, 2): ('DW', Color(0xFFFFB347)),
    (0, 3): ('DL', Color(0xFFA8D8EA)),
    (3, 0): ('DL', Color(0xFFA8D8EA)),
    (3, 6): ('DL', Color(0xFFA8D8EA)),
    (6, 3): ('DL', Color(0xFFA8D8EA)),
    (3, 3): ('★', Color(0xFFFFD93D)),
  };

  @override
  Widget build(BuildContext context) {
    final targetSet = targets.toSet();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFBECFB0),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            gridN,
            (row) => Padding(
                  padding:
                      EdgeInsets.only(bottom: row < gridN - 1 ? cellGap : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(gridN, (col) {
                      final letter = grid[row][col];
                      final bonus = _bonusMap[(row, col)];
                      final isTarget = targetSet.contains((row, col));
                      final hasLetter = letter.isNotEmpty;

                      Color bg;
                      String label;
                      Color labelColor;

                      if (hasLetter) {
                        bg = wordValid
                            ? const Color(0xFF388E3C)
                            : const Color(0xFFFFF3C7);
                        label = letter;
                        labelColor =
                            wordValid ? Colors.white : const Color(0xFF3E2723);
                      } else if (bonus != null) {
                        bg = bonus.$2;
                        label = bonus.$1;
                        labelColor = Colors.white;
                      } else {
                        bg = isTarget
                            ? const Color(0xFFCCDDBD)
                            : const Color(0xFFDDE8D0);
                        label = '';
                        labelColor = Colors.white;
                      }

                      return Padding(
                        padding: EdgeInsets.only(
                            right: col < gridN - 1 ? cellGap : 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: cellSz,
                          height: cellSz,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(2),
                            border: isTarget && !hasLetter
                                ? Border.all(color: Colors.white54, width: 0.8)
                                : null,
                          ),
                          child: Center(
                            child: Text(label,
                                style: TextStyle(
                                  fontSize: hasLetter ? 11 : 6,
                                  fontWeight: FontWeight.bold,
                                  color: labelColor,
                                  height: 1,
                                )),
                          ),
                        ),
                      );
                    }),
                  ),
                )),
      ),
    );
  }
}

// ── Uçan harf ─────────────────────────────────────────────────────

class _FlyingTile extends StatelessWidget {
  final String letter;
  final int points;
  final double w, h;
  const _FlyingTile(
      {required this.letter,
      required this.points,
      required this.w,
      required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFE8C46A)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB8860B), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(2, 4))
        ],
      ),
      child: Stack(children: [
        Center(
          child: Text(letter,
              style: TextStyle(
                fontSize: w > 28 ? 16 : 9,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3E2723),
                height: 1,
              )),
        ),
        if (w > 24)
          Positioned(
            right: 3,
            bottom: 2,
            child: Text('$points',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                )),
          ),
      ]),
    );
  }
}

// ── Bölüm başlığı ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _SectionHeader(
      {required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: _helpWeak(context),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Wordle demo kartı ─────────────────────────────────────────────

class _WordleDemoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_helpSurface(context), _helpSurfaceAlt(context)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _helpBorder(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Giriş
          Text(
            L.wordleIntro,
            style: TextStyle(
                color: _helpMuted(context), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Renk ipuçları
          _WordleHintRow(
            color: const Color(0xFF538D4E),
            letter: 'R',
            title: L.wordleCorrectTitle,
            body: L.wordleCorrectBody,
          ),
          const SizedBox(height: 10),
          _WordleHintRow(
            color: const Color(0xFFB59F3B),
            letter: 'O',
            title: L.wordlePresentTitle,
            body: L.wordlePresentBody,
          ),
          const SizedBox(height: 10),
          _WordleHintRow(
            color: const Color(0xFF3A3A3C),
            letter: 'J',
            title: L.wordleAbsentTitle,
            body: L.wordleAbsentBody,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: _kPrimary, size: 15),
                const SizedBox(width: 8),
                Text(L.wordleTip,
                    style: TextStyle(
                        color: _kPrimary.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordleHintRow extends StatelessWidget {
  final Color color;
  final String letter;
  final String title;
  final String body;
  const _WordleHintRow({
    required this.color,
    required this.letter,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Center(
            child: Text(letter,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: _helpTitle(context),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(body,
                  style: TextStyle(
                      color: _helpWeak(context), fontSize: 11, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Veri modelleri ────────────────────────────────────────────────

enum _TileState { pending, valid }

class _DemoTile {
  final String letter;
  final int points;
  final _TileState state;
  const _DemoTile(
      {required this.letter, required this.points, required this.state});
}
