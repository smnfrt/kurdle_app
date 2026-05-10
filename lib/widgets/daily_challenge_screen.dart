import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/daily_challenge_service.dart';
import 'package:kurdle_app/services/daily_word_service.dart';
import 'package:kurdle_app/services/game_store.dart';

// ── Renkler ────────────────────────────────────────────────────────
const _kBg   = Color(0xFF0F1923);
const _kCard = Color(0xFF1A2535);

const _kStageColors = [
  Color(0xFF4CAF50), // easy — yeşil
  Color(0xFFFFB74D), // medium — amber
  Color(0xFFEF5350), // hard — kırmızı
];
const _kTimerWarn = Color(0xFFFF5722);

enum _Phase { playing, correctFeedback, wrongFeedback, timeoutFeedback, result }

// ─────────────────────────────────────────────────────────────────
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen>
    with TickerProviderStateMixin {
  // Challenge data
  late final List<ChallengeWord> _words;
  int _stageIndex = 0;

  // Game state
  _Phase _phase = _Phase.playing;
  List<String> _inputLetters = [];
  int _totalScore = 0;
  final List<int?> _stageScores = [null, null, null];

  // Animation controllers
  late final AnimationController _timerCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _feedbackCtrl;
  late final AnimationController _stageInCtrl;

  late final Animation<double> _shakeAnim;
  late final Animation<Offset> _stageSlide;

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _words = DailyChallengeService.getTodaysWords();

    _timerCtrl = AnimationController(vsync: this);
    _timerCtrl.addStatusListener(_onTimerStatus);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 20.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 20.0, end: -20.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -20.0, end: 20.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 20.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _feedbackCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _stageInCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _stageSlide = Tween<Offset>(
            begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _stageInCtrl, curve: Curves.easeOutCubic));

    _startStage();
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _shakeCtrl.dispose();
    _feedbackCtrl.dispose();
    _stageInCtrl.dispose();
    super.dispose();
  }

  // ── Stage management ─────────────────────────────────────────────

  void _startStage() {
    _inputLetters = [];
    _phase = _Phase.playing;
    _timerCtrl.duration = _words[_stageIndex].stageDuration;
    _timerCtrl.forward(from: 0);
    _stageInCtrl.forward(from: 0);
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _phase == _Phase.playing) {
      _onTimeout();
    }
  }

  // ── Input handling ───────────────────────────────────────────────

  void _onLetterTap(String letter) {
    if (_phase != _Phase.playing) return;
    final maxLen = _words[_stageIndex].hiddenIndices.length;
    if (_inputLetters.length >= maxLen) return;
    setState(() => _inputLetters = [..._inputLetters, letter]);
    HapticFeedback.selectionClick();
    if (_inputLetters.length == maxLen) {
      Future.microtask(_checkAnswer);
    }
  }

  void _onBackspace() {
    if (_phase != _Phase.playing || _inputLetters.isEmpty) return;
    setState(
        () => _inputLetters = _inputLetters.sublist(0, _inputLetters.length - 1));
    HapticFeedback.lightImpact();
  }

  void _checkAnswer() {
    if (DailyChallengeService.isCorrect(_inputLetters, _words[_stageIndex])) {
      _onCorrect();
    } else {
      _onWrong();
    }
  }

  void _onCorrect() {
    HapticFeedback.mediumImpact();
    _timerCtrl.stop();
    final remainingMs = (_words[_stageIndex].stageDuration.inMilliseconds *
            (1.0 - _timerCtrl.value))
        .round();
    final score = DailyChallengeService.calcScore(
        _words[_stageIndex].difficulty, remainingMs);

    setState(() {
      _phase = _Phase.correctFeedback;
      _stageScores[_stageIndex] = score;
      _totalScore += score;
    });
    _feedbackCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      _advanceStage();
    });
  }

  void _onWrong() {
    HapticFeedback.heavyImpact();
    setState(() => _phase = _Phase.wrongFeedback);
    _shakeCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.playing;
        _inputLetters = [];
      });
    });
  }

  void _onTimeout() {
    HapticFeedback.heavyImpact();
    _timerCtrl.stop();
    setState(() => _phase = _Phase.timeoutFeedback);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _goToResult();
    });
  }

  void _advanceStage() {
    if (_stageIndex < 2) {
      setState(() {
        _stageIndex++;
        _feedbackCtrl.reset();
      });
      _startStage();
    } else {
      _goToResult();
    }
  }

  void _goToResult() {
    _timerCtrl.stop();
    final completed = _stageScores.whereType<int>().length;
    final isPerfect = completed == 3;
    if (isPerfect) _totalScore += DailyChallengeService.perfectBonus;

    GameStore.instance.dailyBonusPoints += _totalScore;
    DailyWordService.instance.recordChallengeResult(
      stagesCompleted: completed,
      totalScore: _totalScore,
      perfectRun: isPerfect,
    );
    setState(() => _phase = _Phase.result);
  }

  // ── Computed helpers ─────────────────────────────────────────────

  Color get _stageColor => _kStageColors[_stageIndex];
  ChallengeWord get _currentWord => _words[_stageIndex];

  int get _remainingSeconds {
    if (_timerCtrl.duration == null) return 0;
    return (_timerCtrl.duration!.inMilliseconds * (1.0 - _timerCtrl.value) / 1000)
        .ceil()
        .clamp(0, _timerCtrl.duration!.inSeconds);
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.result) {
      return _ResultScreen(
        words: _words,
        stageScores: _stageScores,
        totalScore: _totalScore,
        onClose: () => Navigator.of(context).pop(),
      );
    }

    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_timerCtrl, _shakeCtrl, _feedbackCtrl]),
        builder: (context, _) {
          final bgFlash = _phase == _Phase.correctFeedback
              ? Color.lerp(
                      _kBg,
                      _stageColor.withValues(alpha: 0.12),
                      _feedbackCtrl.value)!
              : (_phase == _Phase.wrongFeedback || _phase == _Phase.timeoutFeedback)
                  ? Color.lerp(_kBg, const Color(0xFFEF5350).withValues(alpha: 0.08), 1.0)!
                  : _kBg;

          return Container(
            color: bgFlash,
            child: Column(
              children: [
                // ── App bar ──────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPad + 14, 16, 0),
                  child: Row(
                    children: [
                      _CircleBtn(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          L.wordOfDay,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3),
                        ),
                      ),
                      _StageDots(
                        stageIndex: _stageIndex,
                        stageScores: _stageScores,
                        colors: _kStageColors,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── Countdown arc ────────────────────────────────────
                _CountdownArc(
                  progress: 1.0 - _timerCtrl.value,
                  seconds: _remainingSeconds,
                  stageColor: _stageColor,
                  warn: _remainingSeconds <= 3,
                ),

                const SizedBox(height: 22),

                // ── Meaning hint ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.translate_rounded,
                          color: _stageColor.withValues(alpha: 0.7), size: 13),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _currentWord.meaning,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── Word display with shake ───────────────────────────
                Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: SlideTransition(
                    position: _stageSlide,
                    child: _WordDisplay(
                      word: _currentWord,
                      inputLetters: _inputLetters,
                      phase: _phase,
                      stageColor: _stageColor,
                      feedbackValue: _feedbackCtrl.value,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Feedback text ────────────────────────────────────
                SizedBox(
                  height: 24,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _feedbackText(),
                  ),
                ),

                // ── Backspace ────────────────────────────────────────
                const SizedBox(height: 10),
                if (_phase == _Phase.playing && _inputLetters.isNotEmpty)
                  GestureDetector(
                    onTap: _onBackspace,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.backspace_outlined,
                              color: Colors.white38, size: 14),
                          const SizedBox(width: 6),
                          Text('Sil',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 30),

                const Spacer(),

                // ── Options grid ─────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, botPad + 36),
                  child: _OptionsGrid(
                    word: _currentWord,
                    onTap: _onLetterTap,
                    stageColor: _stageColor,
                    enabled: _phase == _Phase.playing,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _feedbackText() {
    return switch (_phase) {
      _Phase.correctFeedback => Text(
          L.correctAnswer,
          key: const ValueKey('correct'),
          style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
      _Phase.wrongFeedback => Text(
          L.wrongAnswer,
          key: const ValueKey('wrong'),
          style: const TextStyle(
              color: Color(0xFFEF5350),
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      _Phase.timeoutFeedback => Text(
          L.timeUp,
          key: const ValueKey('timeout'),
          style: const TextStyle(
              color: Color(0xFFFF7043),
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
      _ => const SizedBox.shrink(key: ValueKey('none')),
    };
  }
}

// ── Stage dots ────────────────────────────────────────────────────

class _StageDots extends StatelessWidget {
  final int stageIndex;
  final List<int?> stageScores;
  final List<Color> colors;

  const _StageDots(
      {required this.stageIndex,
      required this.stageScores,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isDone = stageScores[i] != null;
        final isActive = i == stageIndex;
        final color = colors[i];
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? color.withValues(alpha: 0.85)
                : isActive
                    ? color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: isDone
                  ? color
                  : isActive
                      ? color.withValues(alpha: 0.8)
                      : Colors.white24,
              width: isActive ? 1.8 : 1.2,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: isDone
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 11)
              : isActive
                  ? Container(
                      margin: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    )
                  : null,
        );
      }),
    );
  }
}

// ── Countdown arc ─────────────────────────────────────────────────

class _CountdownArc extends StatelessWidget {
  final double progress; // 1.0 = full time remaining, 0.0 = done
  final int seconds;
  final Color stageColor;
  final bool warn;

  const _CountdownArc(
      {required this.progress,
      required this.seconds,
      required this.stageColor,
      required this.warn});

  @override
  Widget build(BuildContext context) {
    final color = warn ? _kTimerWarn : stageColor;
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(74, 74),
            painter: _ArcPainter(progress: progress, color: color),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: warn ? _kTimerWarn : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
            child: Text('$seconds'),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Track
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);

    if (progress <= 0) return;

    // Arc — starts at top (-90°), sweeps clockwise
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Word display ─────────────────────────────────────────────────

class _WordDisplay extends StatelessWidget {
  final ChallengeWord word;
  final List<String> inputLetters;
  final _Phase phase;
  final Color stageColor;
  final double feedbackValue;

  const _WordDisplay({
    required this.word,
    required this.inputLetters,
    required this.phase,
    required this.stageColor,
    required this.feedbackValue,
  });

  @override
  Widget build(BuildContext context) {
    final chars = word.original.characters.toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(chars.length, (i) {
        final isHidden = word.hiddenIndices.contains(i);

        if (!isHidden) {
          return _LetterBox(
            letter: chars[i],
            state: _BoxState.revealed,
            color: stageColor,
          );
        }

        // Find which input this blank corresponds to
        final blankOrder = word.hiddenIndices.indexOf(i);
        final isFilled = blankOrder < inputLetters.length;
        final filledLetter = isFilled ? inputLetters[blankOrder] : null;

        _BoxState state;
        if (phase == _Phase.correctFeedback) {
          state = _BoxState.correct;
        } else if (isFilled && phase == _Phase.wrongFeedback) {
          state = _BoxState.wrong;
        } else if (isFilled) {
          state = _BoxState.filled;
        } else {
          state = _BoxState.blank;
        }

        return _LetterBox(
          letter: filledLetter ?? '_',
          state: state,
          color: stageColor,
          feedbackValue: feedbackValue,
        );
      }),
    );
  }
}

enum _BoxState { revealed, blank, filled, correct, wrong }

class _LetterBox extends StatelessWidget {
  final String letter;
  final _BoxState state;
  final Color color;
  final double feedbackValue;

  const _LetterBox({
    required this.letter,
    required this.state,
    required this.color,
    this.feedbackValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textColor;

    switch (state) {
      case _BoxState.revealed:
        bg = Colors.white.withValues(alpha: 0.06);
        border = Colors.white.withValues(alpha: 0.15);
        textColor = Colors.white;
      case _BoxState.blank:
        bg = Colors.transparent;
        border = Colors.white.withValues(alpha: 0.2);
        textColor = Colors.transparent;
      case _BoxState.filled:
        bg = color.withValues(alpha: 0.12);
        border = color.withValues(alpha: 0.6);
        textColor = color;
      case _BoxState.correct:
        final v = feedbackValue;
        bg = Color.lerp(
            color.withValues(alpha: 0.12), color.withValues(alpha: 0.35), v)!;
        border = color;
        textColor = Colors.white;
      case _BoxState.wrong:
        bg = const Color(0xFFEF5350).withValues(alpha: 0.15);
        border = const Color(0xFFEF5350);
        textColor = const Color(0xFFEF5350);
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey('${state.name}-$letter'),
      tween: Tween(begin: state == _BoxState.blank ? 1.0 : 0.8, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 36,
        height: 42,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1.6),
          boxShadow: state == _BoxState.correct
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)]
              : null,
        ),
        child: Center(
          child: Text(
            state == _BoxState.blank ? '' : letter,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Options grid ──────────────────────────────────────────────────

class _OptionsGrid extends StatelessWidget {
  final ChallengeWord word;
  final void Function(String) onTap;
  final Color stageColor;
  final bool enabled;

  const _OptionsGrid({
    required this.word,
    required this.onTap,
    required this.stageColor,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final options = DailyChallengeService.buildOptions(word);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: options.map((letter) {
        return _OptionBtn(
          letter: letter,
          color: stageColor,
          enabled: enabled,
          onTap: () => onTap(letter),
        );
      }).toList(),
    );
  }
}

class _OptionBtn extends StatefulWidget {
  final String letter;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionBtn(
      {required this.letter,
      required this.color,
      required this.enabled,
      required this.onTap});

  @override
  State<_OptionBtn> createState() => _OptionBtnState();
}

class _OptionBtnState extends State<_OptionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, __) => Transform.scale(
          scale: 1.0 - 0.10 * _press.value,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.enabled
                    ? widget.color.withValues(alpha: 0.55)
                    : Colors.white12,
                width: 1.4,
              ),
              boxShadow: widget.enabled
                  ? [
                      BoxShadow(
                          color: widget.color.withValues(alpha: 0.15),
                          blurRadius: 8)
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.letter,
                style: TextStyle(
                  color: widget.enabled ? widget.color : Colors.white24,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Circle icon button ────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white54, size: 20),
      ),
    );
  }
}

// ── Result screen ─────────────────────────────────────────────────

class _ResultScreen extends StatefulWidget {
  final List<ChallengeWord> words;
  final List<int?> stageScores;
  final int totalScore;
  final VoidCallback onClose;

  const _ResultScreen({
    required this.words,
    required this.stageScores,
    required this.totalScore,
    required this.onClose,
  });

  @override
  State<_ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<_ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  int get _stagesCompleted => widget.stageScores.whereType<int>().length;
  bool get _isPerfect => _stagesCompleted == 3;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              SizedBox(height: topPad + 20),

              // ── Trophy / Emoji ──────────────────────────────────
              Text(
                _isPerfect ? '🏆' : _stagesCompleted >= 2 ? '🎯' : _stagesCompleted == 1 ? '👍' : '😔',
                style: const TextStyle(fontSize: 64),
              ),

              const SizedBox(height: 16),

              // ── Title ───────────────────────────────────────────
              Text(
                _isPerfect
                    ? L.perfectBonus
                    : L.stagesResult(_stagesCompleted),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // ── Total score ──────────────────────────────────────
              Text(
                L.earnedPoints(widget.totalScore),
                style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 28,
                    fontWeight: FontWeight.w900),
              ),

              if (_isPerfect) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '+${DailyChallengeService.perfectBonus} ${L.perfectBonus}',
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Stage breakdown ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: List.generate(3, (i) {
                    final score = widget.stageScores[i];
                    final color = _kStageColors[i];
                    final diffLabel = [L.stageEasy, L.stageMedium, L.stageHard][i];
                    final word = widget.words[i];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: score != null
                              ? color.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Stage color dot
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: score != null ? color : Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Diff label
                          Text(diffLabel,
                              style: TextStyle(
                                  color: score != null ? color : Colors.white38,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),

                          const SizedBox(width: 10),

                          // Word
                          Expanded(
                            child: Text(
                              word.original,
                              style: TextStyle(
                                  color: score != null
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2),
                            ),
                          ),

                          // Score or X
                          if (score != null)
                            Text('+$score',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold))
                          else
                            const Icon(Icons.close_rounded,
                                color: Colors.white24, size: 18),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const Spacer(),

              // ── Bottom button ─────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(28, 0, 28, botPad + 28),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onClose();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Text(
                        L.useInGame,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
