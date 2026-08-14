import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/helpers/a11y.dart';
import 'package:kurdle_app/domain.dart' as domain;
import 'package:kurdle_app/game.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/level_rewards.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/widgets/board.dart';
import 'package:kurdle_app/widgets/level_up_overlay.dart';
import 'package:kurdle_app/widgets/how_to.dart';
import 'package:kurdle_app/widgets/keyboard.dart';
import 'package:kurdle_app/widgets/settings.dart';
import 'package:kurdle_app/widgets/stats.dart';

const _kWordleBgTop = Color(0xFF111D2C);
const _kWordleBgBottom = Color(0xFF071018);
const _kWordleSurface = Color(0xFF142133);
const _kWordlePrimary = Color(0xFF3FBE6F);
const _kWordleGold = Color(0xFFFFD27A);

class WordleGameScreen extends StatefulWidget {
  const WordleGameScreen({super.key});

  @override
  State<WordleGameScreen> createState() => _WordleGameScreenState();
}

class _WordleGameScreenState extends State<WordleGameScreen> {
  final Kurdle _game = Kurdle();
  final StreamController<Settings> _streamController =
      StreamController.broadcast();
  Future<bool> _initialized = Future<bool>.value(false);
  domain.Dialog _currentDialog = domain.Dialog.none;

  @override
  void initState() {
    super.initState();

    _streamController.stream.listen((settings) {
      if (_game.settings.isDarkMode != settings.isDarkMode) {
        _game.settings.isDarkMode = settings.isDarkMode;
        _game.persist();
      } else {
        _game.updateKeyboardLayout();
        _game.persist();
      }
    });

    _initialized = _game.init().then((value) {
      _streamController.add(_game.settings);
      return value;
    });

    // Wordle XP ödülünü dinle — seviye atlama olduysa overlay göster.
    Kurdle.wordleLevelUp.addListener(_onLevelUp);
  }

  // ── Wordle Harf İpucu (L6+, 25 Peyv) ─────────────────────────────
  static const int _hintCost = 25;

  Future<void> _onHintTap() async {
    HapticFeedback.lightImpact();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) {
      _showHintMsg(
        title: 'Giriş gerekli',
        body: 'Harf ipucu için giriş yapman gerekiyor.',
        icon: Icons.login_rounded,
      );
      return;
    }
    final profile = await FirestoreService.instance.getProfile(uid);
    if (!mounted) return;
    final level = profile?.level ?? 1;
    final peyv = profile?.peyv ?? 0;

    if (!hasWordleHintUnlock(level)) {
      _showHintMsg(
        title: 'Seviye 6 gerekli',
        body: 'Harf İpucu Seviye 6\'da açılır. Şu an Seviye $level\'desin.',
        icon: Icons.lock_rounded,
      );
      return;
    }
    if (peyv < _hintCost) {
      _showHintMsg(
        title: 'Yeterli Peyv yok',
        body: '$_hintCost Peyv gerekli. Bakiyen: $peyv Peyv.',
        icon: Icons.savings_rounded,
      );
      return;
    }
    if (_game.context.remainingTries == 0) {
      _showHintMsg(
        title: 'Oyun bitti',
        body: 'Bu turda artık ipucu satın alamazsın.',
        icon: Icons.flag_rounded,
      );
      return;
    }

    final confirm = await _confirmHint(peyv);
    if (confirm != true || !mounted) return;

    final ok = await FirestoreService.instance.spendPeyv(
      uid: uid,
      amount: _hintCost,
      reason: 'wordle_hint',
    );
    if (!mounted) return;
    if (!ok) {
      _showHintMsg(
        title: 'Satın alma başarısız',
        body: 'Tekrar dene.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    _revealRandomLetter();
  }

  Future<bool?> _confirmHint(int currentPeyv) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lightbulb_rounded, color: Color(0xFFFFB300)),
            SizedBox(width: 8),
            Text('Harf İpucu'),
          ],
        ),
        content: Text(
          '$_hintCost Peyv harcayarak cevaptaki bir harfin pozisyonunu '
          'görmek ister misin?\n\nBakiyen: $currentPeyv Peyv',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              foregroundColor: Colors.white,
            ),
            child: Text('Harca ($_hintCost Peyv)'),
          ),
        ],
      ),
    );
  }

  void _revealRandomLetter() {
    final answer = _game.context.answer.toUpperCase();
    if (answer.isEmpty) return;
    final idx = Random().nextInt(answer.length);
    final letter = answer[idx];
    final position = idx + 1;
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lightbulb_rounded, color: Color(0xFFFFB300)),
            SizedBox(width: 8),
            Text('İpucu'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(ctx).style,
            children: [
              const TextSpan(text: 'Cevabın '),
              TextSpan(
                text: '$position.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' harfi: '),
              TextSpan(
                text: letter,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showHintMsg({
    required String title,
    required String body,
    required IconData icon,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFB300)),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _onLevelUp() {
    final reward = Kurdle.wordleLevelUp.value;
    if (reward == null || !mounted) return;
    // Her oyun sonunda kısa XP/Peyv özetini göster
    if (reward.xpGained > 0 || reward.peyvGained > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded,
                  color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 6),
              Text('+${reward.xpGained} XP',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (reward.peyvGained > 0) ...[
                const SizedBox(width: 14),
                const Icon(Icons.savings_rounded,
                    color: Color(0xFF00BFA5), size: 18),
                const SizedBox(width: 6),
                Text('+${reward.peyvGained} Peyv',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          backgroundColor: const Color(0xFF1A2535),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    // Sadece seviye atlanmış ise tam ekran overlay
    LevelUpOverlay.maybeShow(
      context: context,
      oldLevel: reward.oldLevel,
      newLevel: reward.newLevel,
      xpGained: reward.xpGained,
      peyvGained: reward.peyvGained,
    );
    // Reset so subsequent games can trigger again
    Kurdle.wordleLevelUp.value = null;
  }

  @override
  void dispose() {
    Kurdle.wordleLevelUp.removeListener(_onLevelUp);
    _streamController.close();
    super.dispose();
  }

  void _onKeyPressed(String val) {
    if (_game.context.remainingTries == 0 || _game.isEvaluating) return;
    setState(() {
      _game.evaluateTurn(val);
      if (_game.context.turnResult == TurnResult.unsuccessful) {
        SoundService.instance.play(SFX.wordInvalid);
        var index = (_game.context.remainingTries - Kurdle.totalTries).abs();
        _game.shakeKeys[index].currentState?.forward();
        _game.isEvaluating = false;
      } else if (_game.context.turnResult == TurnResult.successful) {
        for (var i = 0; i < _game.context.attempt.length; i++) {
          var offset = i +
              ((Kurdle.totalTries - _game.context.remainingTries) *
                  Kurdle.rowLength);
          Timer(Duration(milliseconds: i * 200), () {
            if (!mounted) return;
            setState(() {
              _game.context.board.tiles[offset] = _game.context.attempt[i];
            });
          });
        }
        final didWin = _game.didWin(_game.context.attempt);
        // Oyun-hissi: Wordle artık sessiz değil (Scrabble'daki SoundService).
        if (didWin) {
          SoundService.instance.play(SFX.win);
        } else if (_game.context.remainingTries <= 1) {
          SoundService.instance.play(SFX.lose); // son tahmin, kazanılmadı
        } else {
          SoundService.instance.play(SFX.wordValid);
        }
        final delay = didWin ? 4 : 2;
        if (didWin) {
          Timer(const Duration(seconds: 2), () {
            for (var i = 0; i < _game.context.attempt.length; i++) {
              var offset = i +
                  ((Kurdle.totalTries - _game.context.remainingTries) *
                      Kurdle.rowLength);
              Timer(Duration(milliseconds: i * 200), () {
                if (!mounted) return;
                setState(() {
                  _game.bounceKeys[offset].currentState?.forward();
                });
              });
            }
          });
        }
        Timer(Duration(seconds: delay), () {
          if (!mounted) return;
          setState(() {
            _game.updateAfterSuccessfulGuess().then((_) {
              if (mounted) setState(() {});
            });
            _resetMessage();
            _game.isEvaluating = false;
          });
        });
      } else {
        _game.isEvaluating = false;
      }
    });
    _resetMessage();
  }

  void _newGame() {
    setState(() {
      _game.init();
    });
    _resetMessage();
  }

  void _resetMessage() {
    if (_game.context.message.isNotEmpty) {
      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _game.context.message = '';
        });
        if (_game.context.remainingTries == 0) {
          Timer(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            _setDialog(domain.Dialog.stats);
          });
        }
      });
    }
  }

  void _setDialog(domain.Dialog dialog, {bool show = true}) {
    setState(() {
      _currentDialog = show ? dialog : domain.Dialog.none;
      announceA11y('${show ? 'Showing' : 'Closing'} ${_currentDialog.name}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialized,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Leyar')),
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          );
        }

        _resetMessage();

        return Stack(children: [
          Scaffold(
            backgroundColor: _kWordleBgBottom,
            appBar: AppBar(
              backgroundColor: _kWordleBgTop,
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16, right: 20),
                child: GestureDetector(
                  onTap: () => _setDialog(domain.Dialog.help),
                  child: Semantics(
                    label: 'Yardım',
                    child: const Icon(Icons.help_outline, size: 26),
                  ),
                ),
              ),
              title: const _WordleTitle(),
              centerTitle: true,
              actions: [
                _WordleIconAction(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Harf İpucu',
                  color: _kWordleGold,
                  onTap: _onHintTap,
                ),
                _WordleIconAction(
                  icon: Icons.leaderboard_rounded,
                  label: 'İstatistikler',
                  color: const Color(0xFF64B5F6),
                  onTap: () => _setDialog(domain.Dialog.stats),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
                    onTap: () => _setDialog(domain.Dialog.settings),
                    child: Semantics(
                      label: 'Ayarlar',
                      child: const Icon(Icons.settings, size: 26),
                    ),
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_kWordleBgTop, _kWordleBgBottom],
                        ),
                      ),
                    ),
                  ),
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 400,
                        height: 700,
                        child: Stack(children: [
                          Positioned(
                            top: 10,
                            left: 13,
                            child: _WordleBoardStage(
                              child: BoardWidget(
                                _game,
                                Kurdle.rowLength,
                                _game.shakeKeys,
                                _game.bounceKeys,
                                _game.settings,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 458,
                            left: 28,
                            right: 28,
                            child: _WordleStatusStrip(
                              gameNumber: _game.gameNumber,
                              remainingTries: _game.context.remainingTries,
                            ),
                          ),
                          Positioned(
                            top: 500,
                            left: 0,
                            child: _WordleKeyboardStage(
                              child: Keyboard(
                                _game.context.keys,
                                _game.settings,
                                _onKeyPressed,
                              ),
                            ),
                          ),
                          if (_currentDialog == domain.Dialog.stats) ...[
                            Positioned(
                              top: 50,
                              left: 0,
                              child: StatsWidget(
                                _game.stats,
                                _game.settings,
                                _setDialog,
                                _newGame,
                              ),
                            ),
                          ],
                          if (_currentDialog == domain.Dialog.settings) ...[
                            Positioned(
                              top: 50,
                              left: 0,
                              child: SettingsWidget(
                                _setDialog,
                                _streamController,
                                _game.settings,
                                _game.packageInfo,
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
          if (_currentDialog == domain.Dialog.help) ...[
            SafeArea(child: HowTo(_setDialog, _game.settings)),
          ],
        ]);
      },
    );
  }
}

class _WordleTitle extends StatelessWidget {
  const _WordleTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'Günün Kelimesi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 1),
        Text(
          'Leyar',
          style: TextStyle(
            color: Color(0xFFB7C0CD),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _WordleIconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WordleIconAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          label: label,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _WordleBoardStage extends StatelessWidget {
  final Widget child;

  const _WordleBoardStage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 374,
      height: 438,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17263A), Color(0xFF0E1825)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _kWordlePrimary.withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WordleStatusStrip extends StatelessWidget {
  final int gameNumber;
  final int remainingTries;

  const _WordleStatusStrip({
    required this.gameNumber,
    required this.remainingTries,
  });

  @override
  Widget build(BuildContext context) {
    final attemptsUsed = (Kurdle.totalTries - remainingTries).clamp(0, 6);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kWordleSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: _kWordleGold),
          const SizedBox(width: 6),
          Text(
            '#$gameNumber',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            '$attemptsUsed / ${Kurdle.totalTries}',
            style: const TextStyle(
              color: Color(0xFFB7C0CD),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          for (var i = 0; i < Kurdle.totalTries; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < attemptsUsed
                    ? _kWordlePrimary
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
        ],
      ),
    );
  }
}

class _WordleKeyboardStage extends StatelessWidget {
  final Widget child;

  const _WordleKeyboardStage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 200,
      padding: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kWordleSurface.withValues(alpha: 0.24),
            Colors.transparent,
          ],
        ),
      ),
      child: child,
    );
  }
}
