import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/game_store.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/services/daily_word_service.dart';
import 'package:kurdle_app/services/stats_service.dart';
import 'package:kurdle_app/widgets/auth_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_home_screen.dart';
import 'package:kurdle_app/widgets/how_to_play_screen.dart';
import 'package:kurdle_app/widgets/onboarding_screen.dart';
import 'package:kurdle_app/services/onboarding_service.dart';
import 'package:kurdle_app/widgets/profile_screen.dart';
import 'package:kurdle_app/widgets/scrabble_game_screen.dart';
import 'package:kurdle_app/widgets/tournament_screen.dart';
import 'package:kurdle_app/widgets/daily_challenge_screen.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/services/notification_service.dart';
import 'package:kurdle_app/widgets/friend_game_screen.dart';
import 'package:kurdle_app/widgets/friend_lobby_screen.dart';
import 'package:kurdle_app/widgets/random_match_screen.dart';
import 'package:kurdle_app/widgets/username_match_screen.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/app_theme.dart';

const _kBg       = Color(0xFF080E18);
const _kSurface  = Color(0xFF121C2B);
const _kPrimary  = Color(0xFF3FBE6F);
const _kGold     = Color(0xFFFFD27A);
const _kGoldDim  = Color(0xFFB8860B);

// Premium surface tonu — kart yüzeyi için tutarlı çok katmanlı kaplama
class _PremiumSurface {
  static BoxDecoration build({
    Color? accent,
    double radius = 22,
    double accentOpacity = 0.22,
    double topHighlight = 0.06,
  }) {
    final a = accent ?? Colors.white;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(const Color(0xFF182233), a, 0.04)!,
          const Color(0xFF0E1622),
        ],
      ),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: a.withOpacity(accentOpacity),
          blurRadius: 30,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.40),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

void _showAboutDialog(BuildContext ctx) {
  HapticFeedback.selectionClick();
  showDialog(
    context: ctx,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1A2535),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: _kPrimary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: const Center(
                child: Text('P', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Peyvok', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(L.aboutTagline, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
            const SizedBox(height: 20),
            Container(height: 1, color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.version, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
                const Text('1.0.0', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.aboutDev, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
                const Text('Peyvok Team', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(
                  backgroundColor: _kPrimary.withOpacity(0.12),
                  foregroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _streak = 0;
  late AnimationController _entranceCtrl;
  List<MultiplayerRoom> _pendingInvites = [];
  final Set<String> _notifiedInviteCodes = <String>{};
  StreamSubscription<List<MultiplayerRoom>>? _inviteSub;
  late final void Function(String) _onNotificationInviteTap;
  late final VoidCallback _onOpenMyGames;
  List<MultiplayerRoom> _activeRooms = [];
  StreamSubscription<List<MultiplayerRoom>>? _activeRoomsSub;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _checkOnboarding();
    _loadStreak();
    _listenInvites();
    _listenActiveRooms();
    _onNotificationInviteTap = _handleNotificationInviteTap;
    NotificationService.instance.onInviteTap(_onNotificationInviteTap);
    _onOpenMyGames = _handleOpenMyGames;
    homeOpenMyGamesTick.addListener(_onOpenMyGames);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _inviteSub?.cancel();
    _activeRoomsSub?.cancel();
    NotificationService.instance.offInviteTap(_onNotificationInviteTap);
    homeOpenMyGamesTick.removeListener(_onOpenMyGames);
    super.dispose();
  }

  void _handleOpenMyGames() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MyGamesSheet(
          onResume: (ctrl) {
            Navigator.pop(context);
            Navigator.push(
              context,
              appRoute(ScrabbleGameScreen(existingController: ctrl)),
            ).then((_) => setState(() {}));
          },
          onAcceptInvite: (inv) async {
            Navigator.pop(context);
            final uid = AuthService.instance.effectiveUid;
            final name = AuthService.instance.effectiveDisplayName;
            if (uid == null) return;
            final err = await MultiplayerService.instance
                .joinRoom(inv.roomCode, uid, name);
            if (err == null && mounted) {
              Navigator.push(context,
                  appRoute(FriendGameScreen(roomCode: inv.roomCode, myUid: uid)));
            }
          },
          onDeclineInvite: (inv) =>
              MultiplayerService.instance.declineInvite(inv.roomCode),
          onOpenRoom: (room) {
            Navigator.pop(context);
            final uid = AuthService.instance.effectiveUid ?? '';
            Navigator.push(context,
                appRoute(FriendGameScreen(roomCode: room.roomCode, myUid: uid)));
          },
          invites: _pendingInvites,
          activeRooms: _activeRooms,
        ),
      );
    });
  }

  Future<void> _handleNotificationInviteTap(String roomCode) async {
    if (!mounted) return;
    final inv = _pendingInvites.firstWhere(
      (r) => r.roomCode == roomCode,
      orElse: () => MultiplayerRoom(
        roomCode: '', hostUid: '', hostName: '', status: '',
        currentTurnUid: '',
      ),
    );
    if (inv.roomCode.isEmpty) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.mail_rounded, color: Color(0xFF64B5F6)),
            SizedBox(width: 10),
            Text('Oyun Daveti', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '${inv.hostName} seni oyuna davet etti.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.decline, style: const TextStyle(color: Color(0xFFEF5350))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.accept),
          ),
        ],
      ),
    );
    if (!mounted || accepted == null) return;
    if (accepted == false) {
      await MultiplayerService.instance.declineInvite(inv.roomCode);
      return;
    }
    final uid = AuthService.instance.effectiveUid;
    final name = AuthService.instance.effectiveDisplayName;
    if (uid == null) return;
    final err = await MultiplayerService.instance.joinRoom(inv.roomCode, uid, name);
    if (err == null && mounted) {
      Navigator.push(context, appRoute(FriendGameScreen(roomCode: inv.roomCode, myUid: uid)));
    }
  }

  void _listenInvites() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    _inviteSub = MultiplayerService.instance.inviteStream(uid).listen((invites) {
      if (!mounted) return;
      for (final inv in invites) {
        if (_notifiedInviteCodes.add(inv.roomCode)) {
          NotificationService.instance.showInviteNotification(
            fromName: inv.hostName,
            roomCode: inv.roomCode,
          );
        }
      }
      final activeCodes = invites.map((i) => i.roomCode).toSet();
      _notifiedInviteCodes.removeWhere((c) => !activeCodes.contains(c));
      setState(() => _pendingInvites = invites);
    });
  }

  void _listenActiveRooms() {
    final uid = AuthService.instance.effectiveUid;
    if (uid == null || !FirebaseService.isAvailable) return;
    _activeRoomsSub = MultiplayerService.instance.myActiveRoomsStream(uid).listen((rooms) {
      if (mounted) setState(() => _activeRooms = rooms);
    });
  }

  Widget _stagger(int index, Widget child) {
    final start = (index * 0.10).clamp(0.0, 0.8);
    final end   = (start + 0.55).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }

  Future<void> _loadStreak() async {
    final stats = await StatsService().loadStats();
    if (mounted) setState(() => _streak = stats.streak.current);
  }

  Future<void> _checkOnboarding() async {
    final seen = await OnboardingService.instance.hasSeenOnboarding();
    if (!seen && mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => OnboardingScreen(
            onDone: () => Navigator.of(context).pop(),
          ),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Cinematic background: linear gradient + radial top glow + bottom vignette
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0E1827), Color(0xFF050810)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: [
                      const Color(0xFF4CAF50).withOpacity(0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.0,
                    colors: [
                      const Color(0xFF6CC0F5).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
        children: [
          // Header
          _HomeHeader(
            statusBarHeight: top,
            streak: _streak,
            onLocaleChanged: () => setState(() {}),
            onSettingsTap: () => _showSettingsSheet(context),
            onStatsTap: () => _showStatsSheet(context),
            onOptionsTap: (btnCtx) => _showOptionsMenu(btnCtx),
          ),

          // Menu cards
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 22, 18, bottom + 28),
              child: Column(
                children: [
                  _stagger(0, _QuickPlayCard(
                    onTap: () => Navigator.push(
                      context,
                      appRoute(const ScrabbleGameScreen()),
                    ).then((_) => setState(() {})),
                  )),
                  const SizedBox(height: 16),
                  _stagger(1, _GamePairPanel(
                    invites: _pendingInvites,
                    activeRooms: _activeRooms,
                    onAi: (seconds) => Navigator.push(
                      context, appRoute(ScrabbleGameScreen(turnTimeLimitSeconds: seconds)),
                    ).then((_) => setState(() {})),
                    onFriend: (seconds) => Navigator.push(
                      context, appRoute(FriendLobbyScreen(turnTimeLimitSeconds: seconds)),
                    ),
                    onUsername: () => Navigator.push(
                      context, appRoute(const UsernameMatchScreen()),
                    ),
                    onRandom: () => Navigator.push(
                      context, appRoute(const RandomMatchScreen()),
                    ),
                    onResume: (ctrl) => Navigator.push(
                      context,
                      appRoute(ScrabbleGameScreen(existingController: ctrl)),
                    ).then((_) => setState(() {})),
                    onAcceptInvite: (inv) async {
                      final uid  = AuthService.instance.effectiveUid;
                      final name = AuthService.instance.effectiveDisplayName;
                      if (uid == null) return;
                      final err = await MultiplayerService.instance.joinRoom(inv.roomCode, uid, name);
                      if (err == null && context.mounted) {
                        Navigator.push(context, appRoute(FriendGameScreen(roomCode: inv.roomCode, myUid: uid)));
                      }
                    },
                    onDeclineInvite: (inv) => MultiplayerService.instance.declineInvite(inv.roomCode),
                    onOpenRoom: (room) {
                      final uid = AuthService.instance.effectiveUid ?? '';
                      Navigator.push(context, appRoute(FriendGameScreen(roomCode: room.roomCode, myUid: uid)));
                    },
                  )),
                  const SizedBox(height: 16),
                  _stagger(2, _TurnuvaModuCard(
                    onTap: () => Navigator.push(
                      context,
                      appRoute(const TournamentScreen()),
                    ),
                  )),
                  const SizedBox(height: 16),
                  _stagger(3, _GununKelimesiCard()),
                  const SizedBox(height: 16),
                  _stagger(4, _SiralamalarCard()),
                ],
              ),
            ),
          ),
        ],
        ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(
        onLocaleChanged: () => setState(() {}),
        onHowToTap: () => _showHowTo(context),
      ),
    );
  }

  void _showStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _StatsSheet(),
    );
  }

  void _showOptionsMenu(BuildContext btnCtx) {
    final RenderBox btn = btnCtx.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = btn.localToGlobal(Offset.zero, ancestor: overlay);
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + btn.size.height + 4,
      offset.dx + btn.size.width,
      0,
    );
    final isSignedIn = AuthService.instance.isSignedIn && !AuthService.instance.isAnonymous;
    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 12,
      items: [
        PopupMenuItem(
          value: 'ferheng',
          child: _MenuRow(icon: Icons.menu_book_rounded, label: L.ferheng),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'how_to_play',
          child: _MenuRow(icon: Icons.help_outline_rounded, label: L.howToPlayShort),
        ),
        PopupMenuItem(
          value: 'about',
          child: _MenuRow(icon: Icons.info_outline_rounded, label: L.about),
        ),
        if (FirebaseService.isAvailable) ...[
          const PopupMenuDivider(),
          if (!isSignedIn)
            PopupMenuItem(
              value: 'google_signin',
              child: _MenuRow(icon: Icons.login_rounded, label: 'Google ile Giriş Yap'),
            )
          else
            PopupMenuItem(
              value: 'signout',
              child: _MenuRow(icon: Icons.logout_rounded, label: 'Çıkış Yap'),
            ),
        ],
      ],
    ).then((val) {
      if (val == 'ferheng') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const FerhengHomeScreen(),
        ));
      } else if (val == 'how_to_play') {
        _showHowTo(context);
      } else if (val == 'about') {
        _showAboutDialog(context);
      } else if (val == 'google_signin') {
        _doGoogleSignIn();
      } else if (val == 'signout') {
        _doSignOut();
      }
    });
  }

  Future<void> _doGoogleSignIn() async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hoş geldin, ${user.displayName ?? user.email}!'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      setState(() {});
    }
  }

  Future<void> _doSignOut() async {
    await AuthService.instance.signOut();
    if (mounted) setState(() {});
  }

  void _showHowTo(BuildContext context) {
    Navigator.push(context, appRoute(const HowToPlayScreen()));
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(L.comingSoon, style: const TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: const Color(0xFF1E2A3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Sıralamalar ──────────────────────────────────────────────────

class _SiralamalarCard extends StatefulWidget {
  const _SiralamalarCard();

  @override
  State<_SiralamalarCard> createState() => _SiralamalarCardState();
}

class _SiralamalarCardState extends State<_SiralamalarCard> {
  int _tab = 0;
  List<LeaderboardEntry> _weekly = [];
  List<LeaderboardEntry> _allTime = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!FirebaseService.isAvailable) {
      setState(() => _loading = false);
      return;
    }
    final weekly  = await FirestoreService.instance.getWeeklyLeaderboard();
    final allTime = await FirestoreService.instance.getAllTimeLeaderboard();
    if (mounted) setState(() { _weekly = weekly; _allTime = allTime; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF141E2B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kGold.withOpacity(0.25), width: 1.2),
        ),
        child: const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
      );
    }

    final entries = _tab == 0 ? _weekly : _allTime;
    final myUid = AuthService.instance.currentUser?.uid;
    final myIdx = myUid != null ? entries.indexWhere((e) => e.uid == myUid) : -1;
    final myRank  = myIdx >= 0 ? myIdx + 1 : null;
    final myScore = myIdx >= 0 ? entries[myIdx].score : null;

    final board = entries.map((e) => (
      name: e.displayName,
      score: e.score,
      isMe: e.uid == myUid,
    )).toList();
    final top3 = board.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141E2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withOpacity(0.25), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Başlık + tab
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.leaderboard_rounded, color: _kGold, size: 18),
                const SizedBox(width: 8),
                Text(L.ranking, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                _TabBtn(label: L.weekly,  active: _tab == 0, onTap: () { setState(() => _tab = 0); _load(); }),
                const SizedBox(width: 6),
                _TabBtn(label: L.allTime, active: _tab == 1, onTap: () { setState(() => _tab = 1); _load(); }),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),

          // İki sütun: global top3 | benim sıram
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sol: global top 3
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.globalRanking, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ...top3.asMap().entries.map((e) {
                          final rank  = e.key + 1;
                          final entry = e.value;
                          final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                Text(medal, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(entry.name,
                                      style: TextStyle(
                                        color: entry.isMe ? _kPrimary : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: entry.isMe ? FontWeight.bold : FontWeight.normal,
                                      )),
                                ),
                                Text(_fmtScore(entry.score),
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Dikey ayraç
                Container(width: 1, color: Colors.white.withOpacity(0.05)),

                // Sağ: benim sıram
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.myRank, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        const SizedBox(height: 10),
                        if (myRank == null)
                          Text(
                            L.noScoreYet,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          )
                        else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('#$myRank',
                                  style: TextStyle(
                                    color: myRank <= 3 ? _kGold : Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  )),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('/ ${board.length}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kPrimary.withOpacity(0.3)),
                            ),
                            child: Text('${_fmtScore(myScore!)} ${L.points}',
                                style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            myRank <= 3
                                ? L.rankingGreat
                                : L.rankingBehind(myRank - 1, _fmtScore(board[myRank - 2].score - myScore)),
                            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtScore(int s) => s >= 1000 ? '${(s / 1000).toStringAsFixed(1)}K' : '$s';
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(8),
        splashColor: _kGold.withOpacity(0.15),
        highlightColor: _kGold.withOpacity(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _kGold.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? _kGold.withOpacity(0.5) : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                color: active ? _kGold : Colors.white.withOpacity(0.35),
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}

class _GununKelimesiCard extends StatefulWidget {
  const _GununKelimesiCard();

  @override
  State<_GununKelimesiCard> createState() => _GununKelimesiCardState();
}

class _GununKelimesiCardState extends State<_GununKelimesiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _hasPlayed = false;
  int _challengePlays = 0;
  int _perfectRuns   = 0;
  bool _loading = true;
  int _activeStage = 0; // 0=kolay, 1=orta, 2=zor
  Timer? _stageTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _loadState();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted && !_hasPlayed) {
        setState(() => _activeStage = (_activeStage + 1) % 3);
      }
    });
  }

  Future<void> _loadState() async {
    final svc = DailyWordService.instance;
    final played = svc.hasPlayedTodayLocal || await svc.hasPlayedToday();
    final stats  = await svc.fetchTodayStats();
    if (mounted) {
      setState(() {
        _hasPlayed     = played;
        _challengePlays = stats?.totalPlayed ?? 0;
        _perfectRuns   = stats?.totalWon ?? 0;
        _loading       = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stageTimer?.cancel();
    super.dispose();
  }

  void _openChallenge() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DailyChallengeScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ).then((_) => _loadState());
  }

  // Gece yarısına kalan süre
  String _nextResetCountdown() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final t = _pulseCtrl.value;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1538), Color(0xFF0F0E27)],
            ),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withOpacity(0.22 + 0.10 * t),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.18 + 0.06 * t),
                blurRadius: 26,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.40),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _loading
              ? const SizedBox(
                  height: 60,
                  child: Center(child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF)))))
              : _body(),
        );
      },
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık satırı ───────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFB39DDB), size: 14),
              const SizedBox(width: 6),
              Text(L.dailyChallenge,
                  style: const TextStyle(
                      color: Color(0xFFB39DDB),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const Spacer(),
              if (_hasPlayed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
                  ),
                  child: Text(L.alreadyPlayed,
                      style: const TextStyle(
                          color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Bugünkü hedef + kalan süre ───────────────────────────
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Color(0xFF9575CD), size: 13),
              const SizedBox(width: 5),
              Text(
                L.dailyGoal,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Text('⏳', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                '${_nextResetCountdown()} ${L.timeRemaining}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── 3 Aşama göstergesi ───────────────────────────────────
          Row(
            children: [
              _StagePreview(
                color: const Color(0xFF4CAF50),
                label: L.stageEasy,
                icon: '🟢',
                percent: '30%',
                seconds: '5s',
                isActive: !_hasPlayed && _activeStage == 0,
              ),
              const SizedBox(width: 8),
              _StagePreview(
                color: const Color(0xFFFFB74D),
                label: L.stageMedium,
                icon: '🟡',
                percent: '50%',
                seconds: '7s',
                isActive: !_hasPlayed && _activeStage == 1,
              ),
              const SizedBox(width: 8),
              _StagePreview(
                color: const Color(0xFFEF5350),
                label: L.stageHard,
                icon: '🔴',
                percent: '70%',
                seconds: '10s',
                isActive: !_hasPlayed && _activeStage == 2,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Alt satır: istatistik + buton ────────────────────────
          Row(
            children: [
              if (_challengePlays > 0) ...[
                Icon(Icons.people_alt_rounded,
                    color: const Color(0xFFB39DDB).withOpacity(0.5), size: 12),
                const SizedBox(width: 4),
                Text(
                  '$_challengePlays',
                  style: TextStyle(
                      color: const Color(0xFFB39DDB).withOpacity(0.5),
                      fontSize: 10),
                ),
                const SizedBox(width: 8),
                Icon(Icons.emoji_events_rounded,
                    color: const Color(0xFFFFD700).withOpacity(0.5), size: 12),
                const SizedBox(width: 4),
                Text(
                  '$_perfectRuns',
                  style: TextStyle(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      fontSize: 10),
                ),
              ],
              const Spacer(),
              if (_hasPlayed)
                // Sonraki oyuna geri sayım
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined,
                        color: Colors.white.withOpacity(0.3), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _nextResetCountdown(),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ],
                )
              else
                // Oyna butonu
                GestureDetector(
                  onTap: _openChallenge,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFF512DA8)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF7C4DFF).withOpacity(0.35),
                            blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Text(
                      L.play,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StagePreview extends StatelessWidget {
  final Color color;
  final String label;
  final String icon;
  final String percent;
  final String seconds;
  final bool isActive;

  const _StagePreview({
    required this.color,
    required this.label,
    required this.icon,
    required this.percent,
    required this.seconds,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.16) : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withOpacity(0.7) : color.withOpacity(0.25),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(percent,
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(seconds,
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Hızlı Oyna CTA kartı ─────────────────────────────────────────

class _QuickPlayCard extends StatefulWidget {
  final VoidCallback onTap;
  const _QuickPlayCard({required this.onTap});

  @override
  State<_QuickPlayCard> createState() => _QuickPlayCardState();
}

class _QuickPlayCardState extends State<_QuickPlayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            HapticFeedback.mediumImpact();
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B5E20).withOpacity(0.28 + 0.10 * t),
                    blurRadius: 32,
                    spreadRadius: -4,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    // Layer 1: deep diagonal base
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF14502B), Color(0xFF071E11)],
                        ),
                      ),
                    ),
                    // Layer 2: ambient radial glow (pulses)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(-0.4 + 0.3 * t, -0.5),
                              radius: 1.2,
                              colors: [
                                const Color(0xFF66E093).withOpacity(0.35 + 0.10 * t),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Layer 3: top inner highlight
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Border ring
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFF66E093).withOpacity(0.30 + 0.18 * t),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      L.quickPlay,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.flash_on_rounded,
                                      color: const Color(0xFFFFD27A).withOpacity(0.85 + 0.15 * t),
                                      size: 19,
                                      shadows: [
                                        Shadow(
                                          color: const Color(0xFFFFB300).withOpacity(0.55),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  L.quickPlaySub,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.62),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.1,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Premium play button — double ring + pulse
                          SizedBox(
                            width: 60, height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer pulse ring
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.10 + 0.10 * t),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                // Main play button
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFFFFFF), Color(0xFFC8E6C9)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.30 + 0.15 * t),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF1B5E20).withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Color(0xFF1B5E20),
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Yeni Oyun + Oyunlarım ikili panel ────────────────────────────

class _GamePairPanel extends StatefulWidget {
  final void Function(int? seconds) onAi;
  final void Function(int? seconds) onFriend;
  final VoidCallback onUsername;
  final VoidCallback onRandom;
  final void Function(dynamic) onResume;
  final void Function(MultiplayerRoom) onAcceptInvite;
  final void Function(MultiplayerRoom) onDeclineInvite;
  final void Function(MultiplayerRoom) onOpenRoom;
  final List<MultiplayerRoom> invites;
  final List<MultiplayerRoom> activeRooms;

  const _GamePairPanel({
    required this.onAi,
    required this.onFriend,
    required this.onUsername,
    required this.onRandom,
    required this.onResume,
    required this.onAcceptInvite,
    required this.onDeclineInvite,
    required this.onOpenRoom,
    this.invites = const [],
    this.activeRooms = const [],
  });

  @override
  State<_GamePairPanel> createState() => _GamePairPanelState();
}

class _GamePairPanelState extends State<_GamePairPanel> {

  void _showMyGamesSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MyGamesSheet(
        onResume: (ctrl) { Navigator.pop(context); widget.onResume(ctrl); },
        onAcceptInvite: (inv) { Navigator.pop(context); widget.onAcceptInvite(inv); },
        onDeclineInvite: (inv) { widget.onDeclineInvite(inv); },
        onOpenRoom: (room) { Navigator.pop(context); widget.onOpenRoom(room); },
        invites: widget.invites,
        activeRooms: widget.activeRooms,
      ),
    );
  }

  void _showNewGameSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewGameSheet(
        onAi: widget.onAi,
        onFriend: widget.onFriend,
        onUsername: widget.onUsername,
        onRandom: widget.onRandom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStore.instance;
    final hasActiveGame = store.activeController != null &&
        store.activeRecord != null &&
        !store.activeRecord!.isFinished;
    final totalActive = (hasActiveGame ? 1 : 0) + widget.activeRooms.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF141E2B), Color(0xFF0F1923)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sol: Yeni Oyun ─────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(17)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showNewGameSheet(context),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(17)),
                          splashColor: _kPrimary.withOpacity(0.10),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: _kPrimary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _kPrimary.withOpacity(0.3)),
                                  ),
                                  child: const Icon(Icons.play_circle_fill_rounded, color: _kPrimary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(L.newGame,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(L.howToPlay,
                                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: Colors.white38, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Dikey ayraç ────────────────────────────────────
            Container(width: 1, color: Colors.white.withOpacity(0.08)),

            // ── Sağ: Oyunlarım ─────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(17)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showMyGamesSheet(context),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(17)),
                      splashColor: _kGold.withOpacity(0.10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 16, 14, 16),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: _kGold.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _kGold.withOpacity(0.3)),
                                  ),
                                  child: const Icon(Icons.grid_view_rounded, color: _kGold, size: 20),
                                ),
                                if (widget.invites.isNotEmpty)
                                  Positioned(
                                    right: -4, top: -4,
                                    child: Container(
                                      width: 14, height: 14,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF5252),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('${widget.invites.length}',
                                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(L.myGames,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    totalActive > 0 ? L.gamesCount(totalActive) : L.noGames,
                                    style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 10),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompakt alt seçenek — yarım genişlik için optimize
class _CompactOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _CompactOption({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        splashColor: color.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Yeni Oyun tam ekran seçenekler ──────────────────────────────

class _NewGameSheet extends StatelessWidget {
  final void Function(int? seconds) onAi;
  final void Function(int? seconds) onFriend;
  final VoidCallback onUsername;
  final VoidCallback onRandom;

  const _NewGameSheet({
    required this.onAi,
    required this.onFriend,
    required this.onUsername,
    required this.onRandom,
  });

  void _pickDirect(BuildContext ctx, VoidCallback action) {
    Navigator.pop(ctx);
    action();
  }

  void _pickWithTime(BuildContext ctx, void Function(int? seconds) action) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimeControlSheet(
        onSelected: (seconds) {
          Navigator.pop(ctx);
          action(seconds);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101824),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // pill
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // başlık
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withOpacity(0.35)),
                ),
                child: const Icon(Icons.play_circle_fill_rounded, color: _kPrimary, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.newGame,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(L.howToPlay,
                      style: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // seçenekler
          _SheetOption(
            icon: Icons.smart_toy_rounded,
            color: _kPrimary,
            label: L.aiPlay,
            onTap: () => _pickWithTime(context, onAi),
          ),
          const SizedBox(height: 12),
          _SheetOption(
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF64B5F6),
            label: L.friendPlay,
            onTap: () => _pickWithTime(context, onFriend),
          ),
          const SizedBox(height: 12),
          _SheetOption(
            icon: Icons.alternate_email_rounded,
            color: const Color(0xFFBA68C8),
            label: L.byUsername,
            onTap: () => _pickDirect(context, onUsername),
          ),
          const SizedBox(height: 12),
          _SheetOption(
            icon: Icons.search_rounded,
            color: const Color(0xFFFFB74D),
            label: L.findPlayer,
            onTap: () => _pickDirect(context, onRandom),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.25), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Oyunlarım tam ekran çekmece ─────────────────────────────────

class _MyGamesSheet extends StatefulWidget {
  final void Function(dynamic) onResume;
  final void Function(MultiplayerRoom) onAcceptInvite;
  final void Function(MultiplayerRoom) onDeclineInvite;
  final void Function(MultiplayerRoom) onOpenRoom;
  final List<MultiplayerRoom> invites;
  final List<MultiplayerRoom> activeRooms;

  const _MyGamesSheet({
    required this.onResume,
    required this.onAcceptInvite,
    required this.onDeclineInvite,
    required this.onOpenRoom,
    this.invites = const [],
    this.activeRooms = const [],
  });

  @override
  State<_MyGamesSheet> createState() => _MyGamesSheetState();
}

class _MyGamesSheetState extends State<_MyGamesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60)  return L.current == AppLocale.tr ? 'Az önce' : 'Nû';
    if (d.inMinutes < 60)  return L.current == AppLocale.tr ? '${d.inMinutes} dk önce' : '${d.inMinutes} xul berê';
    if (d.inHours < 24)    return L.current == AppLocale.tr ? '${d.inHours} sa önce' : '${d.inHours} st berê';
    return L.current == AppLocale.tr ? '${d.inDays} gün önce' : '${d.inDays} roj berê';
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _tabView(List<Widget> items, String emptyTr, String emptyKu) {
    final mq = MediaQuery.of(context);
    if (items.isEmpty) {
      return Center(
        child: _EmptyHint(L.current == AppLocale.tr ? emptyTr : emptyKu),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + mq.viewPadding.bottom),
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store    = GameStore.instance;
    final active   = store.records.where((r) => !r.isFinished).toList();
    final finished = store.records.where((r) => r.isFinished).toList();
    final mq       = MediaQuery.of(context);
    final myUid    = AuthService.instance.effectiveUid ?? '';

    final isTr = L.current == AppLocale.tr;

    final activeItems = active.map((rec) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ActiveGameCard(
        record: rec,
        onTap: () => widget.onResume(store.activeController),
      ),
    )).toList();

    final multiplayerItems = widget.activeRooms.map((room) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _MultiplayerGameCard(
        room: room,
        myUid: myUid,
        onTap: () => widget.onOpenRoom(room),
      ),
    )).toList();

    final finishedItems = finished.map((rec) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _FinishedGameCard(record: rec),
    )).toList();

    final inviteItems = widget.invites.map((inv) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InviteCard(
        invite: inv,
        onAccept: () => widget.onAcceptInvite(inv),
        onDecline: () { widget.onDeclineInvite(inv); setState(() {}); },
      ),
    )).toList();

    return Container(
      height: mq.size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF101824),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // pill
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)),
          ),
          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGold.withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: _kGold, size: 24),
                ),
                const SizedBox(width: 14),
                Text(L.myGames, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // TabBar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: _kPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPrimary.withOpacity(0.5)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text(isTr ? 'Devam Eden' : 'Berdewam'),
                          if (active.isNotEmpty || multiplayerItems.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            _TabBadge(active.length + multiplayerItems.length, _kPrimary),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flag_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text(isTr ? 'Biten' : 'Qediyayî'),
                          if (finished.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            _TabBadge(finished.length, Colors.white38),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mail_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text(isTr ? 'Davetler' : 'Vexwendin'),
                          if (widget.invites.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            _TabBadge(widget.invites.length, const Color(0xFF64B5F6)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _tabView([...activeItems, ...multiplayerItems], 'Aktif oyun yok', 'Lîstikek çalak tune'),
                _tabView(finishedItems, 'Biten oyun yok', 'Lîstikeke qediyayî tune'),
                _tabView(inviteItems, 'Bekleyen davet yok', 'Vexwendinek li bendê tune'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _TabBadge(this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  const _SectionHeader({required this.icon, required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('$count', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13)),
  );
}

class _ActiveGameCard extends StatelessWidget {
  final GameRecord record;
  final VoidCallback onTap;
  const _ActiveGameCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kPrimary.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L.current == AppLocale.tr ? 'AI ile Oyun' : 'Lîstik bi AI',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${record.playerScore} — ${record.aiScore}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    if (record.lastMoveAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _MyGamesSheetState._timeAgo(record.lastMoveAt!),
                        style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kPrimary.withOpacity(0.4)),
                ),
                child: Text(
                  L.current == AppLocale.tr ? 'Devam Et' : 'Berdewam bike',
                  style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiplayerGameCard extends StatelessWidget {
  final MultiplayerRoom room;
  final String myUid;
  final VoidCallback onTap;
  const _MultiplayerGameCard({required this.room, required this.myUid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = room.currentTurnUid == myUid;
    final isHost   = room.hostUid == myUid;
    final myScore  = isHost ? room.hostScore : room.guestScore;
    final oppScore = isHost ? room.guestScore : room.hostScore;
    final oppName  = isHost ? (room.guestName ?? 'Rakip') : room.hostName;
    final dotColor = isMyTurn ? _kPrimary : Colors.white38;
    final isTr     = L.current == AppLocale.tr;

    final lastBy = room.lastMoveBy;
    final lastScore = room.lastMoveScore;
    String? lastMoveText;
    if (lastBy != null && lastScore != null) {
      final byMe = (lastBy == 'host' && isHost) || (lastBy == 'guest' && !isHost);
      final who = byMe ? (isTr ? 'Sen' : 'Tu') : oppName;
      final sign = lastScore >= 0 ? '+' : '';
      lastMoveText = isTr
          ? '$who: $sign$lastScore puan'
          : '$who: $sign$lastScore xal';
    }

    return Opacity(
      opacity: isMyTurn ? 1.0 : 0.45,
      child: Material(
        color: isMyTurn
            ? const Color(0xFF1A3A2A)
            : const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () { HapticFeedback.selectionClick(); onTap(); },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        oppName,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$myScore — $oppScore',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      if (lastMoveText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          lastMoveText,
                          style: TextStyle(
                            color: (lastScore ?? 0) >= 0
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFFEF9A9A),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        isMyTurn
                            ? (isTr ? 'Senin sıran' : 'Nöbeta te')
                            : (isTr ? 'Rakip sırası' : 'Nöbeta hevrik'),
                        style: TextStyle(
                          color: isMyTurn ? _kPrimary.withOpacity(0.8) : Colors.white38,
                          fontSize: 11,
                          fontWeight: isMyTurn ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMyTurn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kPrimary.withOpacity(0.4)),
                    ),
                    child: Text(
                      isTr ? 'Oyna' : 'Bilîze',
                      style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const Icon(Icons.hourglass_bottom_rounded, color: Colors.white24, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishedGameCard extends StatelessWidget {
  final GameRecord record;
  const _FinishedGameCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final won = record.playerScore > record.aiScore;
    final color = won ? const Color(0xFFFFD700) : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Text(won ? '🏆' : '💀', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  won
                      ? (L.current == AppLocale.tr ? 'Kazandın' : 'Tu biri')
                      : (L.current == AppLocale.tr ? 'Kaybettin' : 'Tu şikestî'),
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text('${record.playerScore} — ${record.aiScore}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                Text(_MyGamesSheetState._timeAgo(record.startedAt),
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final MultiplayerRoom invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _InviteCard({required this.invite, required this.onAccept, required this.onDecline});

  static const _blue = Color(0xFF64B5F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_blue.withOpacity(0.10), _blue.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withOpacity(0.35), width: 1.2),
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Üst: kim davet etti
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _blue.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.sports_esports_rounded, color: _blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invite.hostName,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(L.inviteFrom,
                          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6,
                          decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(L.current == AppLocale.tr ? 'Bekliyor' : 'Hêvî dike',
                          style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Alt: butonlar tam genişlik yan yana
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: _blue.withOpacity(0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                // Reddet
                Expanded(
                  child: GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); onDecline(); },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: Center(
                        child: Text(L.decline,
                            style: TextStyle(color: Colors.white.withOpacity(0.55),
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Kabul Et
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () { HapticFeedback.mediumImpact(); onAccept(); },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(L.accept,
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Süre seçim sayfası ──────────────────────────────────────────

class _TimeControlSheet extends StatelessWidget {
  final void Function(int? seconds) onSelected;
  const _TimeControlSheet({required this.onSelected});

  static const _options = [
    (label: '48 Saat', sublabel: 'Her hamle için 48 saat', seconds: 48 * 3600, icon: Icons.calendar_today_rounded, color: Color(0xFF64B5F6)),
    (label: '24 Saat', sublabel: 'Her hamle için 24 saat', seconds: 24 * 3600, icon: Icons.wb_sunny_rounded, color: Color(0xFFFFB74D)),
    (label: '12 Saat', sublabel: 'Her hamle için 12 saat', seconds: 12 * 3600, icon: Icons.schedule_rounded, color: Color(0xFFBA68C8)),
    (label: '5 Dakika', sublabel: 'Canlı hızlı oyun', seconds: 5 * 60, icon: Icons.bolt_rounded, color: Color(0xFFFF5252)),
  ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101824),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.35)),
                ),
                child: const Icon(Icons.timer_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.selectTime,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(L.timePerMove,
                      style: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._options.map((opt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(opt.seconds);
                },
                borderRadius: BorderRadius.circular(16),
                splashColor: opt.color.withOpacity(0.10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: opt.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: opt.color.withOpacity(0.3)),
                        ),
                        child: Icon(opt.icon, color: opt.color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.label,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(opt.sublabel,
                                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.25), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Oyun modları kartı ────────────────────────────────────────────

class _YeniOyunCard extends StatefulWidget {
  final VoidCallback onAi;
  final VoidCallback onFriend;
  final VoidCallback onUsername;
  final VoidCallback onRandom;

  const _YeniOyunCard({
    required this.onAi,
    required this.onFriend,
    required this.onUsername,
    required this.onRandom,
  });

  @override
  State<_YeniOyunCard> createState() => _YeniOyunCardState();
}

class _YeniOyunCardState extends State<_YeniOyunCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3A2A), Color(0xFF1A2533)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPrimary.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(18),
                bottom: _expanded ? Radius.zero : const Radius.circular(18),
              ),
              splashColor: _kPrimary.withOpacity(0.10),
              highlightColor: _kPrimary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kPrimary.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded, color: _kPrimary, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(L.newGame,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(L.howToPlay,
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withOpacity(0.4), size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
            _SubOption(
              icon: Icons.smart_toy_rounded,
              iconColor: _kPrimary,
              title: L.aiPlay,
              onTap: widget.onAi,
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.04)),
            _SubOption(
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF64B5F6),
              title: L.friendPlay,
              onTap: widget.onFriend,
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.04)),
            _SubOption(
              icon: Icons.alternate_email_rounded,
              iconColor: const Color(0xFFBA68C8),
              title: L.byUsername,
              onTap: widget.onUsername,
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.04)),
            _SubOption(
              icon: Icons.search_rounded,
              iconColor: const Color(0xFFFFB74D),
              title: L.findPlayer,
              onTap: widget.onRandom,
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _SubOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? badge;
  final VoidCallback onTap;

  const _SubOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        splashColor: iconColor.withOpacity(0.12),
        highlightColor: iconColor.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withOpacity(0.2)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!,
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9, fontWeight: FontWeight.w600)),
                ),
              if (badge == null)
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home Header ──────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final double statusBarHeight;
  final int streak;
  final VoidCallback onLocaleChanged;
  final VoidCallback onSettingsTap;
  final VoidCallback onStatsTap;
  final void Function(BuildContext) onOptionsTap;

  const _HomeHeader({
    required this.statusBarHeight,
    required this.streak,
    required this.onLocaleChanged,
    required this.onSettingsTap,
    required this.onStatsTap,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 10, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6111A28), Color(0x99111A28)],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sol grup
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                icon: Icons.settings_rounded,
                tooltip: L.settings,
                onTap: onSettingsTap,
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.bar_chart_rounded,
                tooltip: L.statistics,
                onTap: onStatsTap,
              ),
            ],
          ),

          // Orta: Logo + başlık + streak
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF66E093), Color(0xFF1B5E20)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withOpacity(0.45),
                            blurRadius: 14,
                            spreadRadius: -1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('P',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -0.5,
                            )),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'Peyvok',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6F00).withOpacity(0.20),
                          const Color(0xFFFF6F00).withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF8F00).withOpacity(0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: Color(0xFFFFB74D), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$streak gün streak',
                          style: const TextStyle(
                            color: Color(0xFFFFB74D),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    L.appSubtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.42),
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Sağ grup
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LangSwitcher(onChanged: onLocaleChanged),
              const SizedBox(width: 8),
              Builder(
                builder: (btnCtx) => _IconBtn(
                  icon: Icons.more_vert_rounded,
                  tooltip: L.options,
                  onTap: () => onOptionsTap(btnCtx),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tekil ikon butonu ────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { HapticFeedback.selectionClick(); onTap(); },
          borderRadius: BorderRadius.circular(13),
          splashColor: Colors.white.withOpacity(0.10),
          highlightColor: Colors.white.withOpacity(0.04),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.78), size: 19),
          ),
        ),
      ),
    );
  }
}

// ── Popup menü satırı ────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}

// ── Ayarlar sheet ────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  final VoidCallback onLocaleChanged;
  final VoidCallback onHowToTap;
  const _SettingsSheet({required this.onLocaleChanged, required this.onHowToTap});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _sound       = true;
  bool _haptic      = true;
  bool _notifs      = false;
  bool _darkMode    = true;

  @override
  void initState() {
    super.initState();
    _darkMode = themeNotifier.value == ThemeMode.dark;
  }

  void _showAuthScreen(BuildContext ctx) {
    Navigator.push(
      ctx,
      appRoute(AuthScreen(
        onSuccess: () {
          if (mounted) setState(() {});
        },
      )),
    );
  }

  void _showAbout(BuildContext ctx) => _showAboutDialog(ctx);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141E2B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // Handle + başlık
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2535),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_rounded, color: _kPrimary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(L.settings, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            // İçerik
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
                children: [

                  // ── Hesap / Profil ──────────────────────────────
                  _SectionLabel(L.accountProfile),
                  const SizedBox(height: 10),
                  _ProfileCard(
                    onSignInTap: () {
                      Navigator.pop(context);
                      _showAuthScreen(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.edit_rounded,
                    iconColor: const Color(0xFF64B5F6),
                    label: L.editProfile,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, appRoute(const ProfileScreen()));
                    },
                  ),
                  if (AuthService.instance.isAnonymous)
                    _SettingsTile(
                      icon: Icons.link_rounded,
                      iconColor: _kPrimary,
                      label: L.linkWithGoogle,
                      onTap: () {
                        Navigator.pop(context);
                        _showAuthScreen(context);
                      },
                    )
                  else
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFEF5350),
                      label: L.signOut,
                      onTap: () async {
                        await AuthService.instance.signOut();
                        if (context.mounted) {
                          Navigator.pop(context);
                          setState(() {});
                        }
                      },
                    ),

                  const SizedBox(height: 24),

                  // ── Oyun Ayarları ───────────────────────────────
                  _SectionLabel(L.gameSettings),
                  const SizedBox(height: 10),
                  _SettingsToggle(
                    icon: Icons.volume_up_rounded,
                    iconColor: const Color(0xFFFFB74D),
                    label: L.sound,
                    value: _sound,
                    onChanged: (v) {
                      setState(() => _sound = v);
                      SoundService.instance.setEnabled(v);
                    },
                  ),
                  _SettingsToggle(
                    icon: Icons.vibration_rounded,
                    iconColor: const Color(0xFF81C784),
                    label: L.haptic,
                    value: _haptic,
                    onChanged: (v) => setState(() => _haptic = v),
                  ),
                  _SettingsToggle(
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFFBA68C8),
                    label: L.notifications,
                    value: _notifs,
                    onChanged: (v) => setState(() => _notifs = v),
                  ),
                  _SettingsToggle(
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF4FC3F7),
                    label: _darkMode ? L.darkMode : L.darkModeOff,
                    value: _darkMode,
                    onChanged: (v) {
                      setState(() => _darkMode = v);
                      themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Genel ───────────────────────────────────────
                  _SectionLabel(L.general),
                  const SizedBox(height: 10),
                  _SettingsTileTrailing(
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF4CAF50),
                    label: L.language,
                    trailing: _LangSwitcher(
                      onChanged: () {
                        setState(() {});
                        widget.onLocaleChanged();
                      },
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFFFFD54F),
                    label: L.howToPlayShort,
                    onTap: widget.onHowToTap,
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.white38,
                    label: L.about,
                    trailing: Text('v1.0.0', style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 12)),
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profil kartı ─────────────────────────────────────────────────

class _ProfileCard extends StatefulWidget {
  final VoidCallback? onSignInTap;
  const _ProfileCard({this.onSignInTap});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  int _level = 1;
  int _xp    = 0;
  String? _profileName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    final profile = await FirestoreService.instance.getProfile(uid);
    if (mounted && profile != null) {
      setState(() {
        _level = profile.level;
        _xp = profile.xp;
        _profileName = profile.displayName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user       = AuthService.instance.currentUser;
    final isAnon     = AuthService.instance.isAnonymous;
    final name       = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!
        : (_profileName?.trim().isNotEmpty == true
            ? _profileName!
            : AuthService.instance.effectiveDisplayName);
    final email      = user?.email ?? '';
    final initial    = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final photoUrl   = user?.photoURL;

    return GestureDetector(
      onTap: isAnon ? widget.onSignInTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2535),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAnon
                ? _kPrimary.withOpacity(0.3)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isAnon
                      ? [Colors.grey.shade700, Colors.grey.shade900]
                      : [const Color(0xFF4CAF50), const Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(photoUrl, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Text(initial,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 26, fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (email.isNotEmpty)
                    Text(email,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.38), fontSize: 12))
                  else if (isAnon)
                    Text(L.signInToSaveScores,
                        style: TextStyle(
                            color: _kPrimary.withOpacity(0.8), fontSize: 11)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAnon
                          ? Colors.white.withOpacity(0.06)
                          : _kPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAnon
                            ? Colors.white12
                            : _kPrimary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isAnon ? L.guestBadge : L.levelXp(_level, _xp),
                      style: TextStyle(
                        color: isAnon ? Colors.white60 : _kPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isAnon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPrimary.withOpacity(0.4)),
                ),
                child: Text(L.signIn,
                    style: const TextStyle(color: _kPrimary,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              )
            else
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }
}

// ── Ayarlar bileşenleri ──────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () { HapticFeedback.mediumImpact(); onTap!(); } : null,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withOpacity(0.06),
        highlightColor: Colors.white.withOpacity(0.03),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2535),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
              trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.18), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTileTrailing extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget trailing;

  const _SettingsTileTrailing({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2535),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2535),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Switch(
            value: value,
            onChanged: (v) { HapticFeedback.mediumImpact(); onChanged(v); },
            activeColor: _kPrimary,
            activeTrackColor: _kPrimary.withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ── İstatistik sheet ─────────────────────────────────────────────

class _StatsSheet extends StatefulWidget {
  const _StatsSheet();

  @override
  State<_StatsSheet> createState() => _StatsSheetState();
}

class _StatsSheetState extends State<_StatsSheet> {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2535),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 28),
      child: FutureBuilder(
        future: StatsService().loadStats(),
        builder: (ctx, snap) {
          final stats = snap.data;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: Colors.white54, size: 20),
                  const SizedBox(width: 10),
                  Text(L.statistics, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              if (stats == null)
                const Center(child: CircularProgressIndicator(color: _kPrimary))
              else
                Row(
                  children: [
                    _StatCell(label: L.totalGames,  value: '${stats.played}'),
                    _StatCell(label: L.winRate,     value: '${stats.percentWon}%'),
                    _StatCell(label: L.bestScore,   value: '${stats.highScore}'),
                    _StatCell(label: 'Streak',      value: '${stats.streak.current}'),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Dil seçici ───────────────────────────────────────────────────

class _LangSwitcher extends StatelessWidget {
  final VoidCallback onChanged;
  const _LangSwitcher({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cur = L.current;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangBtn(label: 'KU', active: cur == AppLocale.ku,
              onTap: () { L.set(AppLocale.ku); onChanged(); }),
          const SizedBox(width: 4),
          _LangBtn(label: 'TR', active: cur == AppLocale.tr,
              onTap: () { L.set(AppLocale.tr); onChanged(); }),
        ],
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(8),
        splashColor: _kPrimary.withOpacity(0.2),
        highlightColor: _kPrimary.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final Color borderColor;
  final String? badge;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.borderColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.04),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iconColor.withOpacity(0.25)),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 22),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Turnuva Modu Kartı ───────────────────────────────────────────

class _TurnuvaModuCard extends StatefulWidget {
  final VoidCallback onTap;
  const _TurnuvaModuCard({required this.onTap});

  @override
  State<_TurnuvaModuCard> createState() => _TurnuvaModuCardState();
}

class _TurnuvaModuCardState extends State<_TurnuvaModuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
          onTap: () { HapticFeedback.mediumImpact(); widget.onTap(); },
          borderRadius: BorderRadius.circular(22),
          splashColor: _kGold.withOpacity(0.08),
          highlightColor: _kGold.withOpacity(0.04),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F1809), Color(0xFF130C04)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kGold.withOpacity(0.30 + 0.08 * t), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB8860B).withOpacity(0.18 + 0.06 * t),
                  blurRadius: 28,
                  spreadRadius: -4,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Üst başlık ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      // Kupa ikonu
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _kGold.withOpacity(0.25 + 0.1 * _pulse.value),
                              _kGoldDim.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _kGold.withOpacity(0.4 + 0.2 * _pulse.value)),
                        ),
                        child: const Center(
                          child: Text('🏆', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  L.current == AppLocale.tr
                                      ? 'Turnuva Modu'
                                      : 'Moda Turnuvayê',
                                  style: const TextStyle(
                                    color: _kGold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kPrimary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: _kPrimary.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    L.current == AppLocale.tr ? 'YENİ' : 'NÛ',
                                    style: const TextStyle(
                                      color: _kPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              L.current == AppLocale.tr
                                  ? 'Haftalık 8 kişilik eleme turnuvası'
                                  : 'Turnuvaya hefteyî ya 8 lîstikvan',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _kGold.withOpacity(0.5),
                        size: 22,
                      ),
                    ],
                  ),
                ),

                // ── Ayraç ──────────────────────────────────────
                Container(height: 1, color: _kGold.withOpacity(0.12)),

                // ── Alt görsel kısım ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Mini bracket görseli
                      Expanded(child: _MiniBracket()),
                      const SizedBox(width: 14),
                      // Sağ: Katılımcı + buton
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Oyuncu sayısı
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_alt_rounded,
                                  color: _kGold.withOpacity(0.7), size: 13),
                              const SizedBox(width: 5),
                              RichText(
                                text: TextSpan(children: [
                                  const TextSpan(
                                    text: '6',
                                    style: TextStyle(
                                      color: _kGold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/8',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Progress bar
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: 6 / 8,
                                backgroundColor: Colors.white12,
                                color: _kGold,
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // "Son 2 yer!" uyarısı
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3D00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFFF6E40).withOpacity(0.5)),
                            ),
                            child: Text(
                              L.lastTwoSpots,
                              style: const TextStyle(
                                color: Color(0xFFFF6E40),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Katıl butonu — premium pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFD27A), Color(0xFFB8860B)],
                              ),
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFB300).withOpacity(0.30 + 0.12 * t),
                                  blurRadius: 14,
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  L.current == AppLocale.tr ? 'Katıl' : 'Tevlî bibe',
                                  style: const TextStyle(
                                    color: Color(0xFF2A1A00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: Color(0xFF2A1A00),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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

// ── Mini bracket görseli (home card için) ───────────────────────

class _MiniBracket extends StatelessWidget {
  const _MiniBracket();

  static const _kGold   = Color(0xFFFFD700);
  static const _kGoldDim = Color(0xFFB8860B);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          // Sol: 4 oyuncu yuvası
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniSlot(name: 'Roja',  filled: true),
              _MiniSlot(name: 'Dilan', filled: true),
              _MiniSlot(name: 'Baran', filled: true),
              _MiniSlot(name: L.you,  filled: true, isMe: true),
            ],
          ),
          // Bağlantı çizgileri
          SizedBox(
            width: 14,
            height: 80,
            child: CustomPaint(
              painter: _MiniLinePainter(),
            ),
          ),
          // Orta: 2 yarı final
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniSlot(name: '?', filled: false),
              _MiniSlot(name: '?', filled: false),
            ],
          ),
          // Bağlantı çizgileri 2
          SizedBox(
            width: 14,
            height: 80,
            child: CustomPaint(
              painter: _MiniLinePainter(pairs: 1),
            ),
          ),
          // Final
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 2),
                Text(
                  '???',
                  style: TextStyle(
                    color: _kGold.withOpacity(0.5),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSlot extends StatelessWidget {
  final String name;
  final bool filled;
  final bool isMe;

  static const _kGold   = Color(0xFFFFD700);
  static const _kPrimary = Color(0xFF4CAF50);

  const _MiniSlot({required this.name, required this.filled, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? (isMe
                ? _kPrimary.withOpacity(0.18)
                : Colors.white.withOpacity(0.07))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: filled
              ? (isMe ? _kPrimary.withOpacity(0.5) : _kGold.withOpacity(0.3))
              : Colors.white12,
          width: 0.8,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isMe
              ? _kPrimary
              : filled
                  ? Colors.white60
                  : Colors.white24,
          fontSize: 8,
          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final int pairs;
  const _MiniLinePainter({this.pairs = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B).withOpacity(0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final segH = size.height / pairs;
    for (var i = 0; i < pairs ~/ 2; i++) {
      final y1 = segH * (i * 2) + segH * 0.5;
      final y2 = segH * (i * 2 + 1) + segH * 0.5;
      final yMid = (y1 + y2) / 2;
      canvas.drawLine(Offset(0, y1), Offset(size.width / 2, y1), paint);
      canvas.drawLine(Offset(0, y2), Offset(size.width / 2, y2), paint);
      canvas.drawLine(Offset(size.width / 2, y1), Offset(size.width / 2, y2), paint);
      canvas.drawLine(Offset(size.width / 2, yMid), Offset(size.width, yMid), paint);
    }
  }

  @override
  bool shouldRepaint(_MiniLinePainter old) => false;
}

class _OyunlarimCard extends StatefulWidget {
  final void Function(dynamic ctrl) onResume;

  const _OyunlarimCard({required this.onResume});

  @override
  State<_OyunlarimCard> createState() => _OyunlarimCardState();
}

class _OyunlarimCardState extends State<_OyunlarimCard> {
  bool _expanded = false;
  List<Map<String, dynamic>> _firestoreGames = [];
  bool _loadingGames = false;

  @override
  void initState() {
    super.initState();
    _loadFirestoreGames();
  }

  Future<void> _loadFirestoreGames() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    if (mounted) setState(() => _loadingGames = true);
    final games = await FirestoreService.instance.getRecentGames(uid);
    if (mounted) setState(() { _firestoreGames = games; _loadingGames = false; });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24)   return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }

  String _timeAgoFromTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      return _timeAgo(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStore.instance;
    final hasActiveGame = store.activeController != null &&
        store.activeRecord != null &&
        !store.activeRecord!.isFinished;
    final hasGame = hasActiveGame || _firestoreGames.isNotEmpty || _loadingGames;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2010), Color(0xFF1A2533)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Başlık satırı — tıklanabilir
          GestureDetector(
            onTap: hasGame ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kGold.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.grid_view_rounded, color: _kGold, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.myGames,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(
                          _loadingGames
                              ? '...'
                              : hasGame
                                  ? L.gamesCount(_firestoreGames.length + (hasActiveGame ? 1 : 0))
                                  : L.noGames,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hasGame)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withOpacity(0.4), size: 22),
                    ),
                ],
              ),
            ),
          ),

          // Oyun listesi
          if (hasGame && _expanded) ...[
            Container(height: 1, color: Colors.white.withOpacity(0.06)),

            // Aktif (devam eden) oyun — memory'den
            if (hasActiveGame)
              Material(
                color: Colors.transparent,
                child: InkWell(
                onTap: store.activeController != null
                    ? () => widget.onResume(store.activeController)
                    : null,
                splashColor: _kPrimary.withOpacity(0.10),
                highlightColor: _kPrimary.withOpacity(0.05),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.05),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: _kPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(L.active,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              'Sen ${store.activeRecord!.playerScore} — AI ${store.activeRecord!.aiScore}  •  ${_timeAgo(store.activeRecord!.startedAt)}',
                              style: const TextStyle(color: Colors.white30, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kPrimary.withOpacity(0.4)),
                        ),
                        child: Text(L.resume,
                            style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                ),
              ),

            // Yükleniyor
            if (_loadingGames)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _kGold))),
              ),

            // Geçmiş oyunlar — Firestore'dan
            ..._firestoreGames.take(3).map((game) {
              final won = game['won'] as bool? ?? false;
              final playerScore = game['playerScore'] as int? ?? 0;
              final aiScore = game['aiScore'] as int? ?? 0;
              final timeAgo = _timeAgoFromTimestamp(game['playedAt']);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: won ? _kPrimary.withOpacity(0.6) : Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            won ? L.finished : L.finished,
                            style: TextStyle(
                              color: won ? Colors.white70 : Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sen $playerScore — AI $aiScore${timeAgo.isNotEmpty ? '  •  $timeAgo' : ''}',
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      won ? Icons.emoji_events_rounded : Icons.close_rounded,
                      color: won ? _kGold : Colors.white24,
                      size: 16,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ── Gelen davet banner'ı ─────────────────────────────────────────

class _InviteBanner extends StatelessWidget {
  final MultiplayerRoom invite;
  final String myUid;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteBanner({
    required this.invite,
    required this.myUid,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3040), Color(0xFF0F2030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF64B5F6).withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF64B5F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF64B5F6).withOpacity(0.3)),
            ),
            child: const Icon(Icons.sports_esports_rounded, color: Color(0xFF64B5F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invite.hostName,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(L.inviteFrom,
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { HapticFeedback.mediumImpact(); onAccept(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _kPrimary.withOpacity(0.5)),
              ),
              child: Text(L.accept,
                  style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onDecline(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(L.decline,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
