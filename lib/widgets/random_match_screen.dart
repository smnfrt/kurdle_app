import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/widgets/friend_game_screen.dart';

const _kBg = Color(0xFF080E18);
const _kPrimary = Color(0xFF4CAF50);
const _kBlue = Color(0xFF64B5F6);

class RandomMatchScreen extends StatefulWidget {
  const RandomMatchScreen({super.key});

  @override
  State<RandomMatchScreen> createState() => _RandomMatchScreenState();
}

class _RandomMatchScreenState extends State<RandomMatchScreen>
    with TickerProviderStateMixin {
  late AnimationController _sonarCtrl;
  late AnimationController _dotCtrl;

  String? _roomCode;
  StreamSubscription<MultiplayerRoom?>? _roomSub;

  bool _found = false;
  String? _error;
  String _opponentName = '';

  @override
  void initState() {
    super.initState();

    _sonarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _startSearch();
  }

  @override
  void dispose() {
    _sonarCtrl.dispose();
    _dotCtrl.dispose();
    _roomSub?.cancel();
    super.dispose();
  }

  // ── Arama mantığı ────────────────────────────────────────────────

  Future<void> _startSearch() async {
    final uid = AuthService.instance.effectiveUid;
    final name = AuthService.instance.effectiveDisplayName;
    if (uid == null) {
      if (mounted) setState(() => _error = L.needSignIn);
      return;
    }

    try {
      final code =
          await MultiplayerService.instance.findOrCreateRandomRoom(uid, name);
      if (!mounted) return;

      // Direkt aktif olduysa (var olan odaya katıldık)
      final snap = await MultiplayerService.instance.roomStream(code).first;
      if (snap != null && snap.status == 'active') {
        _onMatched(code, snap, uid);
        return;
      }

      setState(() => _roomCode = code);

      _roomSub = MultiplayerService.instance.roomStream(code).listen((room) {
        if (!mounted || room == null) return;
        if (room.status == 'active') {
          _onMatched(code, room, uid);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = L.searchError);
    }
  }

  void _onMatched(String code, MultiplayerRoom room, String myUid) {
    _roomSub?.cancel();
    final isHost = room.hostUid == myUid;
    final opp = isHost ? (room.guestName ?? '') : room.hostName;
    setState(() {
      _found = true;
      _opponentName = opp;
    });
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        appRoute(FriendGameScreen(roomCode: code, myUid: myUid)),
      );
    });
  }

  Future<void> _cancel() async {
    HapticFeedback.mediumImpact();
    _roomSub?.cancel();
    final code = _roomCode;
    if (code != null) {
      await MultiplayerService.instance.cancelRandomSearch(code);
    }
    if (mounted) Navigator.pop(context);
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kBg : const Color(0xFFE6EEF2);
    final gradient = isDark
        ? const [Color(0xFF0D1B2E), Color(0xFF060A10)]
        : const [Color(0xFFE6EEF2), Color(0xFFDDE8ED)];
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor = isDark ? Colors.white54 : const Color(0xFF52636E);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _cancel();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradient,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.fromLTRB(16, top + 12, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF1A2535), Color(0xFF0F1923)]
                        : const [Color(0xFFF4F8FA), Color(0xFFEAF1F4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _found ? null : _cancel,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFF4F8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFD6E1E7)),
                        ),
                        child: Icon(Icons.close_rounded,
                            color: _found
                                ? mutedColor.withValues(alpha: 0.35)
                                : mutedColor,
                            size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(L.findPlayer,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // İçerik
              Expanded(
                child: _error != null
                    ? _buildError()
                    : _found
                        ? _buildFound()
                        : _buildSearching(),
              ),

              // Alt buton
              if (!_found && _error == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 28),
                  child: _CancelBtn(onTap: _cancel),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Arama animasyonu
  Widget _buildSearching() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF667681);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sonar halkaları
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _SonarRing(ctrl: _sonarCtrl, delay: 0.0, color: _kBlue),
                _SonarRing(ctrl: _sonarCtrl, delay: 0.33, color: _kBlue),
                _SonarRing(ctrl: _sonarCtrl, delay: 0.66, color: _kBlue),
                // Merkez ikon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF0D2240)],
                    ),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: _kBlue.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: _kBlue.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.person_search_rounded,
                      color: _kBlue, size: 34),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Arama metni + animasyonlu noktalar
          AnimatedBuilder(
            animation: _dotCtrl,
            builder: (_, __) {
              final dots = '.' * (1 + (_dotCtrl.value * 2.99).floor());
              return Text(
                '${L.searchingPlayer}$dots',
                style: TextStyle(
                    color: titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              );
            },
          ),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              L.searchingDesc,
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
          ),

          const SizedBox(height: 28),

          // Süre sayacı
          _SearchTimer(),
        ],
      ),
    );
  }

  // Eşleşme bulundu
  Widget _buildFound() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF667681);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.4),
                      blurRadius: 22,
                      spreadRadius: 3),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 28),
          Text(L.matchFound,
              style: TextStyle(
                  color: titleColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
            ),
            child: Text(
              _opponentName,
              style: const TextStyle(
                  color: _kPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text(L.matchFoundDesc,
              style: TextStyle(color: mutedColor, fontSize: 13)),
        ],
      ),
    );
  }

  // Hata ekranı
  Widget _buildError() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF52636E);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: mutedColor.withValues(alpha: 0.5), size: 56),
            const SizedBox(height: 20),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor, fontSize: 15)),
            const SizedBox(height: 28),
            _CancelBtn(onTap: () {
              if (mounted) Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }
}

// ── Sonar halkası ─────────────────────────────────────────────────

class _SonarRing extends StatelessWidget {
  final AnimationController ctrl;
  final double delay;
  final Color color;

  const _SonarRing(
      {required this.ctrl, required this.delay, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ((ctrl.value + delay) % 1.0);
        final size = 70.0 + t * 130.0;
        final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: opacity), width: 1.5),
          ),
        );
      },
    );
  }
}

// ── Süre sayacı ───────────────────────────────────────────────────

class _SearchTimer extends StatefulWidget {
  const _SearchTimer();

  @override
  State<_SearchTimer> createState() => _SearchTimerState();
}

class _SearchTimerState extends State<_SearchTimer> {
  int _seconds = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    final label =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
          color:
              isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF667681),
          fontSize: 14,
          fontFamily: 'monospace'),
    );
  }
}

// ── İptal butonu ──────────────────────────────────────────────────

class _CancelBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor:
              isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF4F8FA),
          foregroundColor: isDark ? Colors.white54 : const Color(0xFF52636E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(L.cancel),
      ),
    );
  }
}
