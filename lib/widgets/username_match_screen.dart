import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/logging_service.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/widgets/friend_game_screen.dart';

const _kBg = Color(0xFF080E18);
const _kCard = Color(0xFF1A2535);
const _kPrimary = Color(0xFF4CAF50);
const _kBlue = Color(0xFF64B5F6);

class UsernameMatchScreen extends StatefulWidget {
  const UsernameMatchScreen({super.key});

  @override
  State<UsernameMatchScreen> createState() => _UsernameMatchScreenState();
}

class _UsernameMatchScreenState extends State<UsernameMatchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  List<UserProfile> _results = [];
  bool _searching = false;
  Timer? _debounce;

  // Davet gönderildi durumu
  String? _inviteRoomCode;
  String? _inviteeName;
  StreamSubscription<MultiplayerRoom?>? _roomSub;
  bool _waitingAccept = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _focus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }

  // ── Arama ────────────────────────────────────────────────────────

  void _onTextChanged() {
    _debounce?.cancel();
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String query) async {
    final myUid = AuthService.instance.effectiveUid;
    final results = await FirestoreService.instance
        .searchUsersByName(query, excludeUid: myUid);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  // ── Davet ────────────────────────────────────────────────────────

  Future<void> _invite(UserProfile target) async {
    HapticFeedback.mediumImpact();
    final uid = AuthService.instance.effectiveUid;
    if (uid == null) return;

    final myName = AuthService.instance.effectiveDisplayName;

    setState(() {
      _waitingAccept = true;
      _inviteeName = target.displayName;
    });

    try {
      final code = await MultiplayerService.instance
          .createInviteRoom(uid, myName, target.uid);
      if (!mounted) return;
      setState(() => _inviteRoomCode = code);

      _roomSub = MultiplayerService.instance.roomStream(code).listen((room) {
        if (!mounted || room == null) return;
        if (room.status == 'active') {
          _roomSub?.cancel();
          Navigator.pushReplacement(
            context,
            appRoute(FriendGameScreen(roomCode: code, myUid: uid)),
          );
        }
      });
    } catch (e) {
      Log.error('UsernameMatchScreen', 'createInviteRoom failed', e);
      if (!mounted) return;
      setState(() {
        _waitingAccept = false;
        _inviteRoomCode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.inviteFailed),
          backgroundColor: const Color(0xFFD32F2F),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _cancelInvite() async {
    HapticFeedback.selectionClick();
    _roomSub?.cancel();
    final code = _inviteRoomCode;
    if (code != null) {
      await MultiplayerService.instance.cancelRandomSearch(code);
    }
    if (mounted) {
      setState(() {
        _waitingAccept = false;
        _inviteRoomCode = null;
        _inviteeName = null;
      });
    }
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

    return PopScope(
      canPop: !_waitingAccept,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _waitingAccept) await _cancelInvite();
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
              _buildHeader(top),
              Expanded(
                child: _waitingAccept
                    ? _buildWaiting(bottom)
                    : _buildSearch(bottom),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double top) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor = isDark ? Colors.white54 : const Color(0xFF52636E);
    final buttonBg =
        isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF4F8FA);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFD6E1E7);
    return Container(
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
            onTap: () async {
              HapticFeedback.selectionClick();
              if (_waitingAccept) {
                await _cancelInvite();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: mutedColor, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Text(L.byUsername,
              style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Arama ekranı
  Widget _buildSearch(double bottom) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? _kCard : const Color(0xFFF4F8FA);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFD6E1E7);
    final textColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF667681);
    return Column(
      children: [
        // Arama kutusu
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              onTap: () {
                if (!_focus.hasFocus) _focus.requestFocus();
              },
              style: TextStyle(color: textColor, fontSize: 15),
              cursorColor: _kBlue,
              decoration: InputDecoration(
                hintText: L.searchByUsername,
                hintStyle: TextStyle(color: mutedColor, fontSize: 14),
                prefixIcon:
                    Icon(Icons.search_rounded, color: mutedColor, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          setState(() => _results = []);
                        },
                        child: Icon(Icons.close_rounded,
                            color: mutedColor, size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        // Sonuçlar
        Expanded(
          child: _searching
              ? const Center(
                  child:
                      CircularProgressIndicator(color: _kBlue, strokeWidth: 2))
              : _results.isEmpty
                  ? _ctrl.text.trim().isNotEmpty
                      ? _buildEmpty()
                      : const SizedBox.shrink()
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UserTile(
                        user: _results[i],
                        onInvite: () => _invite(_results[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF667681);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_rounded,
              color: mutedColor.withValues(alpha: 0.45), size: 52),
          const SizedBox(height: 14),
          Text(L.noUsersFound,
              style: TextStyle(color: mutedColor, fontSize: 14)),
        ],
      ),
    );
  }

  // Davet gönderildi — kabul bekleniyor
  Widget _buildWaiting(double bottom) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF667681);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF64B5F6), Color(0xFF1565C0)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: _kBlue.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                (_inviteeName ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(_inviteeName ?? '',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(L.inviteSent,
              style: const TextStyle(
                  color: _kPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(L.waitingAccept,
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 12)),
          const SizedBox(height: 36),
          _AnimatedDots(),
          const SizedBox(height: 48),
          Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _cancelInvite,
                style: TextButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF4F8FA),
                  foregroundColor:
                      isDark ? Colors.white54 : const Color(0xFF52636E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(L.cancel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kullanıcı kartı ───────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onInvite;
  const _UserTile({required this.user, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    final initial =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? _kCard : const Color(0xFFF4F8FA);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFD6E1E7);
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF667681);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF1B5E20)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 14),
          // İsim + seviye
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(
                    L.levelGames(user.level, user.stats.played),
                    style: TextStyle(color: mutedColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          // Davet butonu
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: onInvite,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.4)),
                ),
                child: Text(L.invitePlayer,
                    style: const TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animasyonlu noktalar ─────────────────────────────────────────

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final dots = '.' * (1 + (_ctrl.value * 2.99).floor());
        return Text(dots,
            style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : const Color(0xFF667681).withValues(alpha: 0.65),
                fontSize: 22,
                letterSpacing: 4));
      },
    );
  }
}
