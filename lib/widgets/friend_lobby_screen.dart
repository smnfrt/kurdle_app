import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/widgets/friend_game_screen.dart';

const _kBg      = Color(0xFF0D1520);
const _kCard    = Color(0xFF162030);
const _kBorder  = Color(0xFF243650);
const _kPrimary = Color(0xFF4CAF50);
const _kBlue    = Color(0xFF64B5F6);

class FriendLobbyScreen extends StatefulWidget {
  final int? turnTimeLimitSeconds;
  const FriendLobbyScreen({Key? key, this.turnTimeLimitSeconds}) : super(key: key);

  @override
  State<FriendLobbyScreen> createState() => _FriendLobbyScreenState();
}

class _FriendLobbyScreenState extends State<FriendLobbyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Create tab
  bool _creating = false;
  String? _myCode;
  StreamSubscription<MultiplayerRoom?>? _waitSub;

  // Join tab
  final _codeCtrl = TextEditingController();
  bool _joining = false;
  String _joinError = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _waitSub?.cancel();
    _codeCtrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  // ── Create ──────────────────────────────────────────────────────

  Future<void> _createRoom() async {
    setState(() => _creating = true);
    try {
      final uid = AuthService.instance.effectiveUid;
      if (uid == null) throw Exception('Lütfen giriş yapın');
      String name = AuthService.instance.effectiveDisplayName;
      if (AuthService.instance.currentUser != null) {
        final profile = await FirestoreService.instance.getProfile(uid);
        name = profile?.displayName ?? AuthService.instance.currentUser!.displayName ?? name;
      }
      final code = await MultiplayerService.instance.createRoom(uid, name);
      setState(() { _myCode = code; _creating = false; });

      _waitSub = MultiplayerService.instance.roomStream(code).listen((room) {
        if (room?.status == 'active' && mounted) {
          _waitSub?.cancel();
          Navigator.pushReplacement(context, _slide(
            FriendGameScreen(roomCode: code, myUid: uid),
          ));
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        _showErr(e.toString());
      }
    }
  }

  void _cancelRoom() {
    _waitSub?.cancel();
    if (_myCode != null) {
      MultiplayerService.instance.leaveRoom(
        _myCode!,
        AuthService.instance.effectiveUid ?? '',
      );
    }
    setState(() { _myCode = null; _creating = false; });
  }

  // ── Join ────────────────────────────────────────────────────────

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _joinError = '6 karakterli kodu girin');
      return;
    }
    setState(() { _joining = true; _joinError = ''; });
    try {
      final uid = AuthService.instance.effectiveUid;
      if (uid == null) throw Exception('Lütfen giriş yapın');
      String name = AuthService.instance.effectiveDisplayName;
      if (AuthService.instance.currentUser != null) {
        final profile = await FirestoreService.instance.getProfile(uid);
        name = profile?.displayName ?? AuthService.instance.currentUser!.displayName ?? name;
      }
      final err = await MultiplayerService.instance.joinRoom(code, uid, name);
      if (!mounted) return;
      if (err != null) {
        setState(() { _joinError = err; _joining = false; });
        return;
      }
      Navigator.pushReplacement(context, _slide(
        FriendGameScreen(roomCode: code, myUid: uid),
      ));
    } catch (e) {
      if (mounted) setState(() { _joinError = e.toString(); _joining = false; });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  Route _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
  );

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          L.friendPlay,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: _kPrimary,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _kPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: L.createRoom),
            Tab(text: L.joinRoom),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CreateTab(
            creating: _creating,
            myCode: _myCode,
            onCreate: _createRoom,
            onCancel: _cancelRoom,
          ),
          _JoinTab(
            codeCtrl: _codeCtrl,
            joining: _joining,
            error: _joinError,
            onJoin: _joinRoom,
          ),
        ],
      ),
    );
  }
}

// ── Create Tab ───────────────────────────────────────────────────

class _CreateTab extends StatelessWidget {
  final bool creating;
  final String? myCode;
  final VoidCallback onCreate;
  final VoidCallback onCancel;

  const _CreateTab({
    required this.creating,
    required this.myCode,
    required this.onCreate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (myCode != null) return _WaitingView(code: myCode!, onCancel: onCancel);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withOpacity(0.15),
                border: Border.all(color: _kPrimary.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.group_add_rounded, color: _kPrimary, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              L.createRoomDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: creating ? null : onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: _kPrimary.withOpacity(0.4),
                ),
                child: creating
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(L.createRoom,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingView extends StatefulWidget {
  final String code;
  final VoidCallback onCancel;

  const _WaitingView({required this.code, required this.onCancel});

  @override
  State<_WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<_WaitingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kBlue.withOpacity(0.15),
                  border: Border.all(color: _kBlue.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: _kBlue, size: 36),
              ),
            ),
            const SizedBox(height: 24),
            Text(L.waitingForOpponent,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 24),
            // Code display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: [
                  Text(L.roomCodeLabel,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    widget.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CodeBtn(
                        icon: Icons.copy_rounded,
                        label: L.copyCode,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(L.codeCopied), duration: const Duration(seconds: 2)),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _CodeBtn(
                        icon: Icons.share_rounded,
                        label: L.shareCode,
                        onTap: () {
                          final box = context.findRenderObject() as RenderBox?;
                          Share.share(
                            L.shareInviteMessage(widget.code),
                            sharePositionOrigin: box != null
                                ? box.localToGlobal(Offset.zero) & box.size
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: widget.onCancel,
              child: Text(L.cancelRoom, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CodeBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white60, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Join Tab ─────────────────────────────────────────────────────

class _JoinTab extends StatelessWidget {
  final TextEditingController codeCtrl;
  final bool joining;
  final String error;
  final VoidCallback onJoin;

  const _JoinTab({
    required this.codeCtrl,
    required this.joining,
    required this.error,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBlue.withOpacity(0.15),
                border: Border.all(color: _kBlue.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.login_rounded, color: _kBlue, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              L.joinRoomDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 28, letterSpacing: 8),
                filled: true,
                fillColor: _kCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBlue, width: 2),
                ),
                errorText: error.isNotEmpty ? error : null,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: joining ? null : onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: _kBlue.withOpacity(0.4),
                ),
                child: joining
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(L.joinRoom,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
