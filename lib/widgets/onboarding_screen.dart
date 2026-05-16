import 'package:flutter/material.dart';
import 'package:kurdle_app/services/onboarding_service.dart';

const _kBg      = Color(0xFF0F1923);
const _kSurface = Color(0xFF1A2533);
const _kPrimary = Color(0xFF4CAF50);

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _pages = [
    _SlideData(
      icon: null,
      title: 'Bi Xêr Hatî Peyvok!',
      subtitle: 'Lîstika peyvên\nKürmancî',
      isLogo: true,
    ),
    _SlideData(
      icon: Icons.grid_4x4_rounded,
      title: 'Çawa tê lîstin?',
      subtitle: 'Di 6 hewlan de peyveke\n5 tîpî ya Kürmancî bibîne',
      isBoard: true,
    ),
    _SlideData(
      icon: null,
      title: 'Rengên Alîkar',
      subtitle: 'Reng riya te nîşan didin',
      isColors: true,
    ),
    _SlideData(
      icon: Icons.emoji_events_rounded,
      title: 'Tu amade yî?',
      subtitle: 'Her roj peyveke nû\nli benda te ye!',
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
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top    = MediaQuery.of(context).padding.top;
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Background gradient accent
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

          // Skip button
          if (!isLast)
            Positioned(
              top: top + 16,
              right: 24,
              child: GestureDetector(
                onTap: _finish,
                child: Text(
                  'Derbas bike',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                ),
              ),
            ),

          Column(
            children: [
              SizedBox(height: top + 56),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _buildSlide(_pages[i]),
                ),
              ),

              // Dots
              _Dots(count: _pages.length, current: _page),
              const SizedBox(height: 28),

              // Button
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
                      isLast ? 'Destpê bike' : 'Berdewam bike',
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

  Widget _buildSlide(_SlideData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data.isLogo) _LogoWidget(),
          if (data.isBoard) _BoardPreview(),
          if (data.isColors) _ColorHints(),
          if (!data.isLogo && !data.isBoard && !data.isColors && data.icon != null)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withValues(alpha: 0.12),
                border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Icon(data.icon!, color: _kPrimary, size: 44),
            ),
          const SizedBox(height: 36),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ── Logo slaydı ───────────────────────────────────────────────────

class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10)),
        ],
      ),
      child: const Center(
        child: Text('P',
            style: TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.bold,
                height: 1)),
      ),
    );
  }
}

// ── Tahta önizlemesi ──────────────────────────────────────────────

class _BoardPreview extends StatelessWidget {
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
            children: List.generate(5, (c) {
              return _BoardTile(
                  letter: _letters[r][c], type: _rows[r][c]);
            }),
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
    Color bg;
    switch (type) {
      case _TC.correct:
        bg = const Color(0xFF538D4E);
        break;
      case _TC.present:
        bg = const Color(0xFFB59F3B);
        break;
      case _TC.absent:
        bg = const Color(0xFF3A3A3C);
        break;
    }
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      ),
    );
  }
}

// ── Renk ipuçları ─────────────────────────────────────────────────

class _ColorHints extends StatelessWidget {
  static const _hints = [
    (color: Color(0xFF538D4E), label: 'Tîpa rast, cîhê rast', letter: 'R'),
    (color: Color(0xFFB59F3B), label: 'Di peyvê de ye, cîhê şaş', letter: 'O'),
    (color: Color(0xFF3A3A3C), label: 'Di peyvê de tune ye', letter: 'J'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _hints.map((h) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: h.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(h.letter,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                h.label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Sayfa noktaları ───────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Slayt verisi ──────────────────────────────────────────────────

class _SlideData {
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool isLogo;
  final bool isBoard;
  final bool isColors;
  final bool isLast;

  const _SlideData({
    this.icon,
    required this.title,
    required this.subtitle,
    this.isLogo = false,
    this.isBoard = false,
    this.isColors = false,
    this.isLast = false,
  });
}
