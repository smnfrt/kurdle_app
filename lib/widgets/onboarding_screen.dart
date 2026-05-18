import 'package:flutter/material.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/onboarding_service.dart';

/// Peyvok onboarding — 6 sayfada tüm oyun modları tanıtılır,
/// son sayfada büyük "Hemen Oyna" CTA'sı.
///
/// Sayfalar: Welcome → Wordle → Scrabble → Multiplayer → Ferheng → CTA.
/// Tüm metinler L.* getter'larından gelir (TR/KMR runtime'da değişir).

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _kPrimary = Color(0xFF4CAF50);
  static const _kPrimaryDark = Color(0xFF1B5E20);

  late final List<_SlideData> _pages = [
    _SlideData(
      builder: (ctx) => const _LogoVisual(),
      titleFn: () => L.onboardingWelcomeTitle,
      subtitleFn: () => L.onboardingWelcomeSubtitle,
    ),
    _SlideData(
      builder: (ctx) => const _WordleBoardPreview(),
      titleFn: () => L.onboardingWordleTitle,
      subtitleFn: () => L.onboardingWordleSubtitle,
    ),
    _SlideData(
      builder: (ctx) => const _ScrabbleVisual(),
      titleFn: () => L.onboardingScrabbleTitle,
      subtitleFn: () => L.onboardingScrabbleSubtitle,
    ),
    _SlideData(
      builder: (ctx) => const _MultiplayerVisual(),
      titleFn: () => L.onboardingMultiplayerTitle,
      subtitleFn: () => L.onboardingMultiplayerSubtitle,
    ),
    _SlideData(
      builder: (ctx) => const _FerhengVisual(),
      titleFn: () => L.onboardingFerhengTitle,
      subtitleFn: () => L.onboardingFerhengSubtitle,
    ),
    _SlideData(
      builder: (ctx) => const _StreakVisual(),
      titleFn: () => L.onboardingStreakTitle,
      subtitleFn: () => L.onboardingStreakSubtitle,
      isLast: true,
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OnboardingService.instance.markSeen();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1923) : const Color(0xFFE6EEF2);
    final textColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF52636E);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withValues(alpha: 0.06),
              ),
            ),
          ),
          if (!isLast)
            Positioned(
              top: top + 16,
              right: 24,
              child: GestureDetector(
                onTap: _finish,
                child: Text(
                  L.onboardingSkip,
                  style: TextStyle(
                      color: mutedColor.withValues(alpha: 0.7), fontSize: 13),
                ),
              ),
            ),
          Column(
            children: [
              SizedBox(height: top + 56),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (ctx, i) => _buildSlide(_pages[i], textColor, mutedColor),
                ),
              ),
              _Dots(count: _pages.length, current: _page, isDark: isDark),
              const SizedBox(height: 28),
              Padding(
                padding: EdgeInsets.fromLTRB(32, 0, 32, bottom + 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      shadowColor: _kPrimary.withValues(alpha: 0.4),
                    ),
                    child: Text(
                      isLast ? L.onboardingStart : L.onboardingNext,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(
      _SlideData data, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          data.builder(context),
          const SizedBox(height: 36),
          Text(
            data.titleFn(),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitleFn(),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: mutedColor, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final Widget Function(BuildContext) builder;
  final String Function() titleFn;
  final String Function() subtitleFn;
  final bool isLast;
  const _SlideData({
    required this.builder,
    required this.titleFn,
    required this.subtitleFn,
    this.isLast = false,
  });
}

// ── Visual: Logo (welcome) ───────────────────────────────────────
class _LogoVisual extends StatelessWidget {
  const _LogoVisual();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_OnboardingScreenState._kPrimary, _OnboardingScreenState._kPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: _OnboardingScreenState._kPrimary.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10)),
        ],
      ),
      child: const Center(
        child: Text('P',
            style: TextStyle(
                color: Colors.white,
                fontSize: 58,
                fontWeight: FontWeight.bold,
                height: 1)),
      ),
    );
  }
}

// ── Visual: Wordle board preview ─────────────────────────────────
class _WordleBoardPreview extends StatelessWidget {
  const _WordleBoardPreview();
  static const _rows = [
    [_TC.absent, _TC.correct, _TC.absent, _TC.absent, _TC.present],
    [_TC.present, _TC.absent, _TC.correct, _TC.absent, _TC.absent],
    [_TC.correct, _TC.correct, _TC.correct, _TC.correct, _TC.correct],
  ];
  static const _letters = [
    ['B', 'I', 'Y', 'A', 'N'],
    ['H', 'E', 'V', 'A', 'L'],
    ['R', 'O', 'J', 'A', 'V'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_rows.length, (r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (c) => _BoardTile(letter: _letters[r][c], type: _rows[r][c]),
            ),
          ),
        );
      }),
    );
  }
}

enum _TC { correct, present, absent }

class _BoardTile extends StatelessWidget {
  final String letter;
  final _TC type;
  const _BoardTile({required this.letter, required this.type});

  @override
  Widget build(BuildContext context) {
    final c = switch (type) {
      _TC.correct => const Color(0xFF6AAA64),
      _TC.present => const Color(0xFFC9B458),
      _TC.absent => const Color(0xFF787C7E),
    };
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ── Visual: Scrabble rack + board hint ───────────────────────────
class _ScrabbleVisual extends StatelessWidget {
  const _ScrabbleVisual();
  static const _tiles = [
    ('H', 4),
    ('E', 1),
    ('V', 4),
    ('A', 1),
    ('L', 1),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tile rack (Scrabble-style wooden background)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF5C3B1A),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in _tiles) _ScrabbleTile(letter: t.$1, score: t.$2),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Mini board hint with 2L/2W premium squares
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final lbl in ['2W', '', '2L', '', '3W'])
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: switch (lbl) {
                    '2W' => const Color(0xFFC5825A),
                    '3W' => const Color(0xFFB54343),
                    '2L' => const Color(0xFF548AC1),
                    _ => const Color(0xFFEFEAD8),
                  },
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: Text(
                    lbl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ScrabbleTile extends StatelessWidget {
  final String letter;
  final int score;
  const _ScrabbleTile({required this.letter, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E0A6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFC9A66B), width: 1),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              letter,
              style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Positioned(
            right: 3,
            bottom: 1,
            child: Text(
              '$score',
              style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 9,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Visual: Multiplayer (two avatars + lightning bolt) ───────────
class _MultiplayerVisual extends StatelessWidget {
  const _MultiplayerVisual();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Avatar(letter: 'M', color: const Color(0xFF64B5F6)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _OnboardingScreenState._kPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded,
                color: _OnboardingScreenState._kPrimary, size: 26),
          ),
        ),
        _Avatar(letter: 'R', color: const Color(0xFFFFAB91)),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;
  final Color color;
  const _Avatar({required this.letter, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ── Visual: Ferheng (book/dict) ─────────────────────────────────
class _FerhengVisual extends StatelessWidget {
  const _FerhengVisual();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: _OnboardingScreenState._kPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: _OnboardingScreenState._kPrimary.withValues(alpha: 0.3),
            width: 1.5),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded,
            color: _OnboardingScreenState._kPrimary, size: 56),
      ),
    );
  }
}

// ── Visual: Streak flame ─────────────────────────────────────────
class _StreakVisual extends StatelessWidget {
  const _StreakVisual();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB74D), Color(0xFFE65100)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFE65100).withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 10)),
        ],
      ),
      child: const Center(
        child: Icon(Icons.local_fire_department_rounded,
            color: Colors.white, size: 60),
      ),
    );
  }
}

// ── Sayfa noktaları ──────────────────────────────────────────────
class _Dots extends StatelessWidget {
  final int count;
  final int current;
  final bool isDark;
  const _Dots(
      {required this.count, required this.current, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        final inactiveColor = isDark
            ? Colors.white.withValues(alpha: 0.15)
            : const Color(0xFF000000).withValues(alpha: 0.15);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: isActive ? 24 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color:
                isActive ? _OnboardingScreenState._kPrimary : inactiveColor,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
