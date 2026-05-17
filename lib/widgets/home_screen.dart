import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/game_store.dart';
import 'package:kurdle_app/services/haptic_service.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/services/daily_word_service.dart';
import 'package:kurdle_app/services/stats_service.dart';
import 'package:kurdle_app/domain.dart' show AiDifficulty;
import 'package:kurdle_app/services/daily_streak_service.dart';
import 'package:kurdle_app/services/settings_service.dart';
import 'package:kurdle_app/services/version_service.dart';
import 'package:kurdle_app/widgets/auth_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_home_screen.dart';
import 'package:kurdle_app/widgets/how_to_play_screen.dart';
import 'package:kurdle_app/widgets/onboarding_screen.dart';
import 'package:kurdle_app/services/onboarding_service.dart';
import 'package:kurdle_app/widgets/privacy_policy_screen.dart';
import 'package:kurdle_app/widgets/profile_screen.dart';
import 'package:kurdle_app/widgets/scrabble_game_screen.dart';
import 'package:kurdle_app/widgets/daily_challenge_screen.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/services/notification_service.dart';
import 'package:kurdle_app/widgets/friend_game_screen.dart';
import 'package:kurdle_app/widgets/friend_lobby_screen.dart';
import 'package:kurdle_app/widgets/random_match_screen.dart';
import 'package:kurdle_app/widgets/username_match_screen.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/app_theme.dart';

const _kPrimary = Color(0xFF3FBE6F);
const _kGold = Color(0xFFFFD27A);
const _kGoldDim = Color(0xFFB8860B);

void _showAboutDialog(BuildContext ctx) {
  HapticFeedback.selectionClick();
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  final dialogBg = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
  final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
  final mutedColor =
      isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF52636E);
  final valueColor = isDark ? Colors.white70 : const Color(0xFF25313A);
  final dividerColor =
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD6E1E7);
  showDialog(
    context: ctx,
    builder: (_) => Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Center(
                child: Text('P',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        height: 1)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Peyvok',
                style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(L.aboutTagline,
                style: TextStyle(color: mutedColor, fontSize: 13)),
            const SizedBox(height: 20),
            Container(height: 1, color: dividerColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.version,
                    style: TextStyle(color: mutedColor, fontSize: 13)),
                Text(VersionService.currentVersion,
                    style: TextStyle(
                        color: valueColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.aboutDev,
                    style: TextStyle(color: mutedColor, fontSize: 13)),
                Text('Peyvok Team',
                    style: TextStyle(
                        color: valueColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
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
                  backgroundColor: _kPrimary.withValues(alpha: 0.12),
                  foregroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _streak = 0;
  bool _streakAtRisk = false;
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
              Navigator.push(
                  context,
                  appRoute(
                      FriendGameScreen(roomCode: inv.roomCode, myUid: uid)));
            }
          },
          onDeclineInvite: (inv) =>
              MultiplayerService.instance.declineInvite(inv.roomCode),
          onOpenRoom: (room) {
            Navigator.pop(context);
            final uid = AuthService.instance.effectiveUid ?? '';
            Navigator.push(
                context,
                appRoute(
                    FriendGameScreen(roomCode: room.roomCode, myUid: uid)));
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
        roomCode: '',
        hostUid: '',
        hostName: '',
        status: '',
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
            Text('Oyun Daveti',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '${inv.hostName} seni oyuna davet etti.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.decline,
                style: const TextStyle(color: Color(0xFFEF5350))),
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
    final err =
        await MultiplayerService.instance.joinRoom(inv.roomCode, uid, name);
    if (err == null && mounted) {
      Navigator.push(context,
          appRoute(FriendGameScreen(roomCode: inv.roomCode, myUid: uid)));
    }
  }

  void _listenInvites() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    _inviteSub =
        MultiplayerService.instance.inviteStream(uid).listen((invites) {
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
    _activeRoomsSub =
        MultiplayerService.instance.myActiveRoomsStream(uid).listen((rooms) {
      if (mounted) setState(() => _activeRooms = rooms);
    });
  }

  Widget _stagger(int index, Widget child) {
    final start = (index * 0.10).clamp(0.0, 0.8);
    final end = (start + 0.55).clamp(0.0, 1.0);
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
    // Yeni günlük streak (her gün herhangi bir oyun oynamak)
    final daily = await DailyStreakService.instance.getState();
    if (mounted) {
      setState(() {
        _streak = daily.current;
        _streakAtRisk = daily.atRisk;
      });
    }
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
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1827), Color(0xFF050810)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F8FA), Color(0xFFE6EEF2)],
          );
    final topGlow = isDark
        ? const Color(0xFF4CAF50).withValues(alpha: 0.07)
        : const Color(0xFF4CAF50).withValues(alpha: 0.10);
    final bottomGlow = isDark
        ? const Color(0xFF6CC0F5).withValues(alpha: 0.05)
        : const Color(0xFFB8C8D0).withValues(alpha: 0.22);

    return Scaffold(
      body: Stack(
        children: [
          // Cinematic background: linear gradient + radial top glow + bottom vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: bgGradient,
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
                      topGlow,
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
                      bottomGlow,
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
                      if (_streakAtRisk) ...[
                        _StreakRiskBanner(
                          current: _streak,
                          onPlay: () => Navigator.push(
                            context,
                            appRoute(const ScrabbleGameScreen()),
                          ).then((_) {
                            _loadStreak();
                            setState(() {});
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _stagger(
                          0,
                          SizedBox(
                            height: 134,
                            child: _QuickPlayCard(
                              onTap: () => _showQuickPlayDifficulty(context),
                            ),
                          )),
                      const SizedBox(height: 14),
                      _stagger(
                          1,
                          SizedBox(
                            height: 134,
                            child: _GamePairPanel(
                              invites: _pendingInvites,
                              activeRooms: _activeRooms,
                              onAi: (seconds) => Navigator.push(
                                context,
                                appRoute(ScrabbleGameScreen(
                                    turnTimeLimitSeconds: seconds)),
                              ).then((_) => setState(() {})),
                              onFriend: (seconds) => Navigator.push(
                                context,
                                appRoute(FriendLobbyScreen(
                                    turnTimeLimitSeconds: seconds)),
                              ),
                              onUsername: () => Navigator.push(
                                context,
                                appRoute(const UsernameMatchScreen()),
                              ),
                              onRandom: () => Navigator.push(
                                context,
                                appRoute(const RandomMatchScreen()),
                              ),
                              onResume: (ctrl) => Navigator.push(
                                context,
                                appRoute(ScrabbleGameScreen(
                                    existingController: ctrl)),
                              ).then((_) => setState(() {})),
                              onAcceptInvite: (inv) async {
                                final uid = AuthService.instance.effectiveUid;
                                final name =
                                    AuthService.instance.effectiveDisplayName;
                                if (uid == null) return;
                                final err = await MultiplayerService.instance
                                    .joinRoom(inv.roomCode, uid, name);
                                if (err == null && context.mounted) {
                                  Navigator.push(
                                      context,
                                      appRoute(FriendGameScreen(
                                          roomCode: inv.roomCode, myUid: uid)));
                                }
                              },
                              onDeclineInvite: (inv) => MultiplayerService
                                  .instance
                                  .declineInvite(inv.roomCode),
                              onOpenRoom: (room) {
                                final uid =
                                    AuthService.instance.effectiveUid ?? '';
                                Navigator.push(
                                    context,
                                    appRoute(FriendGameScreen(
                                        roomCode: room.roomCode, myUid: uid)));
                              },
                            ),
                          )),
                      const SizedBox(height: 12),
                      // Turnuva modu yeterli kullanıcı olmadığından gizlendi.
                      // Geri açmak için: bu kartı + appRoute(TournamentScreen) yorumunu kaldır.
                      // _stagger(2, _TurnuvaModuCard(
                      //   onTap: () => Navigator.push(
                      //     context,
                      //     appRoute(const TournamentScreen()),
                      //   ),
                      // )),
                      // const SizedBox(height: 16),
                      _stagger(2, _GununKelimesiCard()),
                      const SizedBox(height: 12),
                      _stagger(3, _SiralamalarCard()),
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

  void _showQuickPlayDifficulty(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _QuickPlayDifficultySheet(
        onSelected: (difficulty) {
          Navigator.pop(sheetCtx);
          _startQuickPlay(difficulty);
        },
      ),
    );
  }

  void _startQuickPlay(AiDifficulty difficulty) {
    Navigator.push(
      context,
      appRoute(ScrabbleGameScreen(aiDifficulty: difficulty)),
    ).then((_) {
      _loadStreak();
      setState(() {});
    });
  }

  void _showStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _StatsSheet(),
    );
  }

  Future<void> _showOptionsMenu(BuildContext btnCtx) async {
    final RenderBox btn = btnCtx.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = btn.localToGlobal(Offset.zero, ancestor: overlay);
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + btn.size.height + 4,
      offset.dx + btn.size.width,
      0,
    );
    final isSignedIn =
        AuthService.instance.isSignedIn && !AuthService.instance.isAnonymous;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final val = await showMenu<String>(
      context: context,
      position: position,
      color: isDark ? const Color(0xFF1E2A3A) : const Color(0xFFF4F8FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF78868F).withValues(alpha: 0.65),
        ),
      ),
      elevation: 12,
      items: [
        PopupMenuItem(
          value: 'ferheng',
          child: _MenuRow(icon: Icons.menu_book_rounded, label: L.ferheng),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'how_to_play',
          child: _MenuRow(
              icon: Icons.help_outline_rounded, label: L.howToPlayShort),
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
              child: _MenuRow(
                  icon: Icons.login_rounded, label: 'Google ile Giriş Yap'),
            )
          else
            PopupMenuItem(
              value: 'signout',
              child: _MenuRow(icon: Icons.logout_rounded, label: 'Çıkış Yap'),
            ),
        ],
      ],
    );
    if (!mounted || val == null) return;
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
  }

  Future<void> _doGoogleSignIn() async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hoş geldin, ${user.displayName ?? user.email}!'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final weekly = await FirestoreService.instance.getWeeklyLeaderboard();
    final allTime = await FirestoreService.instance.getAllTimeLeaderboard();
    if (mounted) {
      setState(() {
        _weekly = weekly;
        _allTime = allTime;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF202830);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF67727A);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFF96A2AA).withValues(alpha: 0.42);
    if (_loading) {
      return Container(
        height: 104,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141E2B) : const Color(0xFFF4F8FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kGold.withValues(alpha: 0.25), width: 1.2),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
      );
    }

    final entries = _tab == 0 ? _weekly : _allTime;
    final myUid = AuthService.instance.currentUser?.uid;
    final myIdx =
        myUid != null ? entries.indexWhere((e) => e.uid == myUid) : -1;
    final myRank = myIdx >= 0 ? myIdx + 1 : null;
    final myScore = myIdx >= 0 ? entries[myIdx].score : null;

    final board = entries
        .map((e) => (
              name: e.displayName,
              score: e.score,
              isMe: e.uid == myUid,
            ))
        .toList();
    final top3 = board.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF141E2B), Color(0xFF101824)]
              : const [Color(0xFFF4F8FA), Color(0xFFE6EEF2)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? _kGold.withValues(alpha: 0.25)
                : const Color(0xFF8E9AA2).withValues(alpha: 0.60),
            width: 1.2),
        boxShadow: [
          BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : const Color(0xFF7F8D95).withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          // Başlık + tab
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.leaderboard_rounded, color: _kGold, size: 18),
                const SizedBox(width: 8),
                Text(L.ranking,
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                _TabBtn(
                    label: L.weekly,
                    active: _tab == 0,
                    onTap: () {
                      setState(() => _tab = 0);
                      _load();
                    }),
                const SizedBox(width: 6),
                _TabBtn(
                    label: L.allTime,
                    active: _tab == 1,
                    onTap: () {
                      setState(() => _tab = 1);
                      _load();
                    }),
              ],
            ),
          ),

          const SizedBox(height: 9),
          Container(height: 1, color: dividerColor),

          // İki sütun: global top3 | benim sıram
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sol: global top 3
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.globalRanking,
                            style: TextStyle(
                                color: mutedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        ...top3.asMap().entries.map((e) {
                          final rank = e.key + 1;
                          final entry = e.value;
                          final medal = rank == 1
                              ? '🥇'
                              : rank == 2
                                  ? '🥈'
                                  : '🥉';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                Text(medal,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(entry.name,
                                      style: TextStyle(
                                        color: entry.isMe
                                            ? _kPrimary
                                            : titleColor.withValues(
                                                alpha: 0.78),
                                        fontSize: 12,
                                        fontWeight: entry.isMe
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      )),
                                ),
                                Text(_fmtScore(entry.score),
                                    style: TextStyle(
                                        color: mutedColor, fontSize: 11)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Dikey ayraç
                Container(width: 1, color: dividerColor),

                // Sağ: benim sıram
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.myRank,
                            style: TextStyle(
                                color: mutedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        if (myRank == null)
                          Text(
                            L.noScoreYet,
                            style: TextStyle(color: mutedColor, fontSize: 12),
                          )
                        else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('#$myRank',
                                  style: TextStyle(
                                    color: myRank <= 3 ? _kGold : titleColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  )),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('/ ${board.length}',
                                    style: TextStyle(
                                        color:
                                            mutedColor.withValues(alpha: 0.75),
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _kPrimary.withValues(alpha: 0.3)),
                            ),
                            child: Text('${_fmtScore(myScore!)} ${L.points}',
                                style: const TextStyle(
                                    color: _kPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            myRank <= 3
                                ? L.rankingGreat
                                : L.rankingBehind(
                                    myRank - 1,
                                    _fmtScore(
                                        board[myRank - 2].score - myScore)),
                            style: TextStyle(color: mutedColor, fontSize: 10),
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

  String _fmtScore(int s) =>
      s >= 1000 ? '${(s / 1000).toStringAsFixed(1)}K' : '$s';
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: _kGold.withValues(alpha: 0.15),
        highlightColor: _kGold.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _kGold.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active
                    ? _kGold.withValues(alpha: 0.5)
                    : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                color: active
                    ? _kGold
                    : isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : const Color(0xFF69747C),
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
  int _perfectRuns = 0;
  bool _loading = true;
  int _activeStage = 0; // 0=kolay, 1=orta, 2=zor
  Timer? _stageTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
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
    final stats = await svc.fetchTodayStats();
    if (mounted) {
      setState(() {
        _hasPlayed = played;
        _challengePlays = stats?.totalPlayed ?? 0;
        _perfectRuns = stats?.totalWon ?? 0;
        _loading = false;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final t = _pulseCtrl.value;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF1A1538), Color(0xFF0F0E27)]
                  : const [Color(0xFFDAD8E4), Color(0xFFC4CAD8)],
            ),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.22 + 0.10 * t)
                  : const Color(0xFF7C8792).withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFF7C4DFF).withValues(alpha: 0.18 + 0.06 * t)
                    : const Color(0xFF7F8992).withValues(alpha: 0.22),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _loading
              ? const SizedBox(
                  height: 60,
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF7C4DFF)))))
              : _body(),
        );
      },
    );
  }

  Widget _body() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white70 : const Color(0xFF30363D);
    final mutedText =
        isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF6D7680);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık satırı ───────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFB39DDB), size: 14),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                  ),
                  child: Text(L.alreadyPlayed,
                      style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Bugünkü hedef + kalan süre ───────────────────────────
          Row(
            children: [
              const Icon(Icons.flag_rounded,
                  color: Color(0xFF9575CD), size: 13),
              const SizedBox(width: 5),
              Text(
                L.dailyGoal,
                style: TextStyle(
                    color: primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Text('⏳', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                '${_nextResetCountdown()} ${L.timeRemaining}',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

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
              const SizedBox(width: 6),
              _StagePreview(
                color: const Color(0xFFFFB74D),
                label: L.stageMedium,
                icon: '🟡',
                percent: '50%',
                seconds: '7s',
                isActive: !_hasPlayed && _activeStage == 1,
              ),
              const SizedBox(width: 6),
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

          const SizedBox(height: 6),

          // ── Alt satır: istatistik + buton ────────────────────────
          Row(
            children: [
              if (_challengePlays > 0) ...[
                Icon(Icons.people_alt_rounded,
                    color: const Color(0xFFB39DDB).withValues(alpha: 0.5),
                    size: 12),
                const SizedBox(width: 4),
                Text(
                  '$_challengePlays',
                  style: TextStyle(
                      color: const Color(0xFFB39DDB).withValues(alpha: 0.5),
                      fontSize: 10),
                ),
                const SizedBox(width: 8),
                Icon(Icons.emoji_events_rounded,
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    size: 12),
                const SizedBox(width: 4),
                Text(
                  '$_perfectRuns',
                  style: TextStyle(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
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
                        color: mutedText.withValues(alpha: 0.8), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _nextResetCountdown(),
                      style: TextStyle(
                          color: mutedText.withValues(alpha: 0.8),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFF512DA8)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.16)
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.7)
                : color.withValues(alpha: 0.25),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1)
                ]
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
            const SizedBox(height: 3),
            Text(percent,
                style: TextStyle(
                    color: isActive
                        ? (isDark ? Colors.white : const Color(0xFF273039))
                        : (isDark ? Colors.white70 : const Color(0xFF4E5963)),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(seconds,
                style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : const Color(0xFF6B747D),
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Streak risk uyarı banner'ı ──────────────────────────────────

class _StreakRiskBanner extends StatelessWidget {
  final int current;
  final VoidCallback onPlay;
  const _StreakRiskBanner({required this.current, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final isTr = L.current == AppLocale.tr;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6F00), Color(0xFFFF3D00)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3D00).withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr
                          ? '$current günlük serin tehlikede!'
                          : 'Rêza te ya $current rojan di xetereyê de ye!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTr
                          ? 'Bugün oyna, serini koru.'
                          : 'Îro bilîze, rêza xwe biparêze.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
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
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF17201B);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF344238);
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
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1B5E20)
                              .withValues(alpha: 0.28 + 0.10 * t),
                          blurRadius: 32,
                          spreadRadius: -4,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color:
                              const Color(0xFF7C8980).withValues(alpha: 0.26),
                          blurRadius: 24,
                          spreadRadius: -8,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    // Layer 1: deep diagonal base
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? const [Color(0xFF14502B), Color(0xFF071E11)]
                              : const [Color(0xFFC1CCC6), Color(0xFF92A69A)],
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
                                const Color(0xFF66E093).withValues(
                                    alpha: isDark
                                        ? 0.35 + 0.10 * t
                                        : 0.14 + 0.05 * t),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Layer 3: top inner highlight
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
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
                              color: isDark
                                  ? const Color(0xFF66E093)
                                      .withValues(alpha: 0.30 + 0.18 * t)
                                  : const Color(0xFF74A184)
                                      .withValues(alpha: 0.55),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
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
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.flash_on_rounded,
                                      color: const Color(0xFFFFD27A)
                                          .withValues(alpha: 0.85 + 0.15 * t),
                                      size: 19,
                                      shadows: [
                                        Shadow(
                                          color: const Color(0xFFFFB300)
                                              .withValues(alpha: 0.55),
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
                                    color: subtitleColor,
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
                            width: 66,
                            height: 66,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer pulse ring
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.10 + 0.10 * t),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                // Main play button
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFC8E6C9)
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white
                                            .withValues(alpha: 0.30 + 0.15 * t),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF1B5E20)
                                            .withValues(alpha: 0.4),
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

class _QuickPlayDifficultySheet extends StatelessWidget {
  final void Function(AiDifficulty difficulty) onSelected;

  const _QuickPlayDifficultySheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF141E2B) : const Color(0xFFE6EEF2);
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor = isDark ? Colors.white54 : const Color(0xFF4F5C65);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 10, 18, bottom + 18),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white24
                      : const Color(0xFF71808A).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              L.aiDifficulty,
              style: TextStyle(
                color: titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              L.current == AppLocale.tr
                  ? 'Hızlı oyunu hangi AI seviyesiyle başlatalım?'
                  : 'Em lîstika zû bi kîjan asta AI dest pê bikin?',
              style: TextStyle(color: mutedColor, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            _DifficultyOption(
              icon: Icons.spa_rounded,
              color: const Color(0xFF66BB6A),
              title: L.aiEasy,
              subtitle: L.aiEasyDesc,
              onTap: () => onSelected(AiDifficulty.easy),
            ),
            const SizedBox(height: 10),
            _DifficultyOption(
              icon: Icons.balance_rounded,
              color: const Color(0xFF64B5F6),
              title: L.aiNormal,
              subtitle: L.aiNormalDesc,
              onTap: () => onSelected(AiDifficulty.normal),
            ),
            const SizedBox(height: 10),
            _DifficultyOption(
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFFB74D),
              title: L.aiHard,
              subtitle: L.aiHardDesc,
              onTap: () => onSelected(AiDifficulty.hard),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DifficultyOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C252B);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.46) : const Color(0xFF56626B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFF7D8C95).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.14 : 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subtitleColor, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 22),
            ],
          ),
        ),
      ),
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
        onResume: (ctrl) {
          Navigator.pop(context);
          widget.onResume(ctrl);
        },
        onAcceptInvite: (inv) {
          Navigator.pop(context);
          widget.onAcceptInvite(inv);
        },
        onDeclineInvite: (inv) {
          widget.onDeclineInvite(inv);
        },
        onOpenRoom: (room) {
          Navigator.pop(context);
          widget.onOpenRoom(room);
        },
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
        onFriend: widget.onFriend,
        onUsername: widget.onUsername,
        onRandom: widget.onRandom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF16212A);
    final subtitleColor = isDark ? Colors.white38 : const Color(0xFF3F4E58);
    final chevronColor = isDark ? Colors.white38 : const Color(0xFF52636E);
    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD8E2E7);
    final panelBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.85);
    final panelShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : const Color(0xFF758691).withValues(alpha: 0.18);
    final newGameIconBg =
        isDark ? _kPrimary.withValues(alpha: 0.12) : const Color(0xFFE8F7ED);
    final myGamesIconBg =
        isDark ? _kGold.withValues(alpha: 0.12) : const Color(0xFFFFF4DA);
    final titleWeight = isDark ? FontWeight.bold : FontWeight.w800;
    final subtitleWeight = isDark ? FontWeight.normal : FontWeight.w700;
    final store = GameStore.instance;
    final hasActiveGame = store.activeController != null &&
        store.activeRecord != null &&
        !store.activeRecord!.isFinished;
    final totalActive = (hasActiveGame ? 1 : 0) + widget.activeRooms.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF141E2B), Color(0xFF0F1923)]
              : const [Color(0xFFF4F8FA), Color(0xFFE6EEF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: panelBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: panelShadowColor,
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sol: Yeni Oyun ─────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(17)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showNewGameSheet(context),
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(17)),
                          splashColor: _kPrimary.withValues(alpha: 0.10),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 22, 12, 22),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: newGameIconBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _kPrimary.withValues(
                                            alpha: isDark ? 0.3 : 0.45)),
                                  ),
                                  child: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: _kPrimary,
                                      size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(L.newGame,
                                          style: TextStyle(
                                              color: titleColor,
                                              fontSize: 15,
                                              fontWeight: titleWeight),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(L.howToPlay,
                                          style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 11,
                                              fontWeight: subtitleWeight),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: chevronColor, size: 20),
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
            Container(width: 1, color: dividerColor),

            // ── Sağ: Oyunlarım ─────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(17)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showMyGamesSheet(context),
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(17)),
                    splashColor: _kGold.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 22, 16, 22),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: myGamesIconBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _kGold.withValues(
                                          alpha: isDark ? 0.3 : 0.5)),
                                ),
                                child: const Icon(Icons.grid_view_rounded,
                                    color: _kGold, size: 24),
                              ),
                              if (widget.invites.isNotEmpty)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF5252),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text('${widget.invites.length}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(L.myGames,
                                    style: TextStyle(
                                        color: titleColor,
                                        fontSize: 15,
                                        fontWeight: titleWeight),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  totalActive > 0
                                      ? L.gamesCount(totalActive)
                                      : L.noGames,
                                  style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                      fontWeight: subtitleWeight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: chevronColor, size: 20),
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

// ── Yeni Oyun tam ekran seçenekler ──────────────────────────────

class _NewGameSheet extends StatelessWidget {
  final void Function(int? seconds) onFriend;
  final VoidCallback onUsername;
  final VoidCallback onRandom;

  const _NewGameSheet({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF101824) : const Color(0xFFE6EEF2);
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.40) : const Color(0xFF52636E);
    final handleColor =
        isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF9AABB5);
    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // pill
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // başlık
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.play_circle_fill_rounded,
                    color: _kPrimary, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.newGame,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(L.howToPlay,
                      style: TextStyle(color: mutedColor, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // seçenekler
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
  const _SheetOption(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF7B8992).withValues(alpha: 0.55);
    final textColor = isDark ? Colors.white70 : const Color(0xFF25313A);
    final chevronColor =
        isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF5E6B74);
    return Material(
      color: tileBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded, color: chevronColor, size: 20),
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
    if (d.inSeconds < 60) {
      return L.current == AppLocale.tr ? 'Az önce' : 'Nû';
    }
    if (d.inMinutes < 60) {
      return L.current == AppLocale.tr
          ? '${d.inMinutes} dk önce'
          : '${d.inMinutes} xul berê';
    }
    if (d.inHours < 24) {
      return L.current == AppLocale.tr
          ? '${d.inHours} sa önce'
          : '${d.inHours} st berê';
    }
    return L.current == AppLocale.tr
        ? '${d.inDays} gün önce'
        : '${d.inDays} roj berê';
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
    final store = GameStore.instance;
    final active = store.records.where((r) => !r.isFinished).toList();
    final finished = store.records.where((r) => r.isFinished).toList();
    final mq = MediaQuery.of(context);
    final myUid = AuthService.instance.effectiveUid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF101824) : const Color(0xFFE6EEF2);
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final tabBg =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF4F8FA);
    final handleColor =
        isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF9AABB5);
    final selectedTabColor =
        isDark ? _kPrimary.withValues(alpha: 0.2) : const Color(0xFFE8F7ED);
    final unselectedTabColor =
        isDark ? Colors.white54 : const Color(0xFF667681);

    final isTr = L.current == AppLocale.tr;

    final activeItems = active
        .map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActiveGameCard(
                record: rec,
                onTap: () => widget.onResume(store.activeController),
              ),
            ))
        .toList();

    final multiplayerItems = widget.activeRooms
        .map((room) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MultiplayerGameCard(
                room: room,
                myUid: myUid,
                onTap: () => widget.onOpenRoom(room),
              ),
            ))
        .toList();

    final finishedItems = finished
        .map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FinishedGameCard(record: rec),
            ))
        .toList();

    final inviteItems = widget.invites
        .map((inv) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InviteCard(
                invite: inv,
                onAccept: () => widget.onAcceptInvite(inv),
                onDecline: () {
                  widget.onDeclineInvite(inv);
                  setState(() {});
                },
              ),
            ))
        .toList();

    return Container(
      height: mq.size.height * 0.85,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // pill
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: handleColor, borderRadius: BorderRadius.circular(2)),
          ),
          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                      color: _kGold, size: 24),
                ),
                const SizedBox(width: 14),
                Text(L.myGames,
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // TabBar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: tabBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFD6E1E7),
                ),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: selectedTabColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.5)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: isDark ? Colors.white : const Color(0xFF1F5E37),
                unselectedLabelColor: unselectedTabColor,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
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
                          if (active.isNotEmpty ||
                              multiplayerItems.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            _TabBadge(active.length + multiplayerItems.length,
                                _kPrimary),
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
                            _TabBadge(
                                widget.invites.length, const Color(0xFF64B5F6)),
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
                _tabView([...activeItems, ...multiplayerItems],
                    'Aktif oyun yok', 'Lîstikek çalak tune'),
                _tabView(
                    finishedItems, 'Biten oyun yok', 'Lîstikeke qediyayî tune'),
                _tabView(inviteItems, 'Bekleyen davet yok',
                    'Vexwendinek li bendê tune'),
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
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$count',
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.25)
              : const Color(0xFF667681),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ActiveGameCard extends StatelessWidget {
  final GameRecord record;
  final VoidCallback onTap;
  const _ActiveGameCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg =
        isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF4F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF7B8992).withValues(alpha: 0.55);
    final textColor = isDark ? Colors.white70 : const Color(0xFF25313A);
    return Material(
      color: isDark ? _kPrimary.withValues(alpha: 0.07) : tileBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L.current == AppLocale.tr
                          ? 'AI ile Oyun'
                          : 'Lîstik bi AI',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${record.playerScore} — ${record.aiScore}',
                      style: TextStyle(
                          color:
                              isDark ? Colors.white38 : const Color(0xFF52636E),
                          fontSize: 12),
                    ),
                    if (record.lastMoveAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _MyGamesSheetState._timeAgo(record.lastMoveAt!),
                        style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFF667681),
                            fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  L.current == AppLocale.tr ? 'Devam Et' : 'Berdewam bike',
                  style: const TextStyle(
                      color: _kPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
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
  const _MultiplayerGameCard(
      {required this.room, required this.myUid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = room.currentTurnUid == myUid;
    final isHost = room.hostUid == myUid;
    final myScore = isHost ? room.hostScore : room.guestScore;
    final oppScore = isHost ? room.guestScore : room.hostScore;
    final oppName =
        isHost ? (room.guestName ?? L.opponentFallback) : room.hostName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isMyTurn
        ? _kPrimary
        : (isDark ? Colors.white38 : const Color(0xFF9AABB5));
    final tileColor = isDark
        ? (isMyTurn ? const Color(0xFF1A3A2A) : const Color(0xFF1A2030))
        : (isMyTurn ? const Color(0xFFF4F8FA) : const Color(0xFFEAF1F4));
    final borderColor = isDark
        ? Colors.transparent
        : (isMyTurn
            ? _kPrimary.withValues(alpha: 0.32)
            : const Color(0xFFD6E1E7));
    final titleColor = isDark ? Colors.white : const Color(0xFF25313A);
    final mutedColor = isDark ? Colors.white38 : const Color(0xFF52636E);

    final lastBy = room.lastMoveBy;
    final lastScore = room.lastMoveScore;
    String? lastMoveText;
    if (lastBy != null && lastScore != null) {
      final byMe =
          (lastBy == 'host' && isHost) || (lastBy == 'guest' && !isHost);
      final who = byMe ? L.you : oppName;
      lastMoveText = L.moveScoreLine(who, lastScore);
    }

    return Opacity(
      opacity: isMyTurn ? 1.0 : 0.45,
      child: Material(
        color: tileColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        oppName,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$myScore — $oppScore',
                        style: TextStyle(color: mutedColor, fontSize: 12),
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
                        isMyTurn ? L.yourTurnShort : L.opponentTurnShort,
                        style: TextStyle(
                          color: isMyTurn
                              ? _kPrimary.withValues(alpha: 0.8)
                              : mutedColor,
                          fontSize: 11,
                          fontWeight:
                              isMyTurn ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMyTurn)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: _kPrimary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      L.play,
                      style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Icon(Icons.hourglass_bottom_rounded,
                      color: isDark ? Colors.white24 : const Color(0xFF9AABB5),
                      size: 18),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = won
        ? const Color(0xFFFFB300)
        : (isDark ? Colors.white38 : const Color(0xFF667681));
    final tileBg =
        isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF4F8FA);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFD6E1E7);
    final mutedColor = isDark ? Colors.white38 : const Color(0xFF52636E);
    final timeColor =
        isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF667681);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
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
                      : (L.current == AppLocale.tr
                          ? 'Kaybettin'
                          : 'Tu şikestî'),
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text('${record.playerScore} — ${record.aiScore}',
                    style: TextStyle(color: mutedColor, fontSize: 12)),
                Text(_MyGamesSheetState._timeAgo(record.startedAt),
                    style: TextStyle(color: timeColor, fontSize: 11)),
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
  const _InviteCard(
      {required this.invite, required this.onAccept, required this.onDecline});

  static const _blue = Color(0xFF64B5F6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF7B8992).withValues(alpha: 0.55);
    final textColor = isDark ? Colors.white70 : const Color(0xFF25313A);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [_blue.withValues(alpha: 0.10), _blue.withValues(alpha: 0.04)]
              : const [Color(0xFFF4F8FA), Color(0xFFEAF1F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? _blue.withValues(alpha: 0.35) : borderColor,
            width: 1.2),
        boxShadow: [
          BoxShadow(
              color: _blue.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Üst: kim davet etti
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _blue.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.sports_esports_rounded,
                      color: _blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invite.hostName,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(L.inviteFrom,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : const Color(0xFF52636E),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: _blue, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(L.current == AppLocale.tr ? 'Bekliyor' : 'Hêvî dike',
                          style: const TextStyle(
                              color: _blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
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
            color: _blue.withValues(alpha: 0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                // Reddet
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDecline();
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF4F8FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : const Color(0xFFD6E1E7)),
                      ),
                      child: Center(
                        child: Text(L.decline,
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : const Color(0xFF52636E),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Kabul Et
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onAccept();
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: _blue.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(L.accept,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
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
    (
      seconds: 48 * 3600,
      icon: Icons.calendar_today_rounded,
      color: Color(0xFF64B5F6)
    ),
    (
      seconds: 24 * 3600,
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFFFB74D)
    ),
    (
      seconds: 12 * 3600,
      icon: Icons.schedule_rounded,
      color: Color(0xFFBA68C8)
    ),
    (seconds: 5 * 60, icon: Icons.bolt_rounded, color: Color(0xFFFF5252)),
  ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF101824) : const Color(0xFFE6EEF2);
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.40) : const Color(0xFF52636E);
    final handleColor =
        isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF9AABB5);
    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.timer_rounded,
                    color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.selectTime,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(L.timePerMove,
                      style: TextStyle(color: mutedColor, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._options.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF4F8FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFD6E1E7),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelected(opt.seconds);
                    },
                    borderRadius: BorderRadius.circular(16),
                    splashColor: opt.color.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: opt.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: opt.color.withValues(alpha: 0.3)),
                            ),
                            child: Icon(opt.icon, color: opt.color, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_timeLabel(opt.seconds),
                                    style: TextStyle(
                                        color: titleColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text(_timeSublabel(opt.seconds),
                                    style: TextStyle(
                                        color: mutedColor, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : const Color(0xFF5E6B74),
                              size: 20),
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

  String _timeLabel(int seconds) {
    if (seconds >= 3600 && seconds % 3600 == 0) {
      return L.hoursLabel(seconds ~/ 3600);
    }
    if (seconds >= 60 && seconds % 60 == 0) {
      return L.minutesLabel(seconds ~/ 60);
    }
    return '$seconds sn';
  }

  String _timeSublabel(int seconds) {
    if (seconds >= 3600 && seconds % 3600 == 0) {
      return L.hoursPerMove(seconds ~/ 3600);
    }
    if (seconds == 5 * 60) return L.liveFastGame;
    return L.timePerMove;
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
        border: Border.all(color: _kPrimary.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4)),
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
              splashColor: _kPrimary.withValues(alpha: 0.10),
              highlightColor: _kPrimary.withValues(alpha: 0.05),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _kPrimary.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded,
                          color: _kPrimary, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(L.newGame,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(L.howToPlay,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.4), size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            _SubOption(
              icon: Icons.smart_toy_rounded,
              iconColor: _kPrimary,
              title: L.aiPlay,
              onTap: widget.onAi,
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
            _SubOption(
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF64B5F6),
              title: L.friendPlay,
              onTap: widget.onFriend,
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
            _SubOption(
              icon: Icons.alternate_email_rounded,
              iconColor: const Color(0xFFBA68C8),
              title: L.byUsername,
              onTap: widget.onUsername,
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
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
  final VoidCallback onTap;

  const _SubOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
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
        splashColor: iconColor.withValues(alpha: 0.12),
        highlightColor: iconColor.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.2), size: 20),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF162027);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.42) : const Color(0xFF4B5860);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 10, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xE6111A28), Color(0x99111A28)]
              : const [Color(0xFFF4F8FA), Color(0xFFE6EEF2)],
        ),
        border: Border(
          bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFF77858E).withValues(alpha: 0.70),
              width: 1),
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
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.45),
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
                    Text(
                      'Peyvok',
                      style: TextStyle(
                        color: titleColor,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6F00).withValues(alpha: 0.20),
                          const Color(0xFFFF6F00).withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFFFF8F00).withValues(alpha: 0.45)),
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
                      color: mutedColor,
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

  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF8F9AA2).withValues(alpha: 0.55);
    final iconColor =
        isDark ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF303940);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(13),
          splashColor: _kPrimary.withValues(alpha: 0.10),
          highlightColor: _kPrimary.withValues(alpha: 0.04),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ]
                    : const [Color(0xFFE1E6E9), Color(0xFFC4CDD3)],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.42),
                  blurRadius: isDark ? 6 : 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 19),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconTone = isDark ? Colors.white54 : const Color(0xFF324049);
    final textTone = isDark ? Colors.white70 : const Color(0xFF1D2830);
    return Row(
      children: [
        Icon(icon, color: iconTone, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: textTone, fontSize: 14)),
      ],
    );
  }
}

// ── Ayarlar sheet ────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  final VoidCallback onLocaleChanged;
  final VoidCallback onHowToTap;
  const _SettingsSheet(
      {required this.onLocaleChanged, required this.onHowToTap});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _sound = true;
  bool _haptic = true;
  bool _notifs = false;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    _darkMode = themeNotifier.value == ThemeMode.dark;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await SettingsService().load();
    if (!mounted) return;
    setState(() {
      _darkMode = s.isDarkMode;
      _sound = s.soundEnabled;
      _haptic = s.hapticEnabled;
    });
    themeNotifier.value = s.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    SoundService.instance.setEnabled(s.soundEnabled);
    HapticService.instance.setEnabled(s.hapticEnabled);
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    final s = await SettingsService().load();
    s.isDarkMode = value;
    await SettingsService().save(s);
  }


  Future<void> _setSound(bool value) async {
    setState(() => _sound = value);
    SoundService.instance.setEnabled(value);
    final s = await SettingsService().load();
    s.soundEnabled = value;
    await SettingsService().save(s);
    if (value) {
      await SoundService.instance.play(SFX.tilePlace);
    }
  }

  Future<void> _setHaptic(bool value) async {
    setState(() => _haptic = value);
    HapticService.instance.setEnabled(value);
    final s = await SettingsService().load();
    s.hapticEnabled = value;
    await SettingsService().save(s);
    if (value) {
      HapticService.instance.submit();
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF141E2B) : const Color(0xFFE6EEF2);
    final sheetTop = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final handleColor = isDark
        ? Colors.white24
        : const Color(0xFF73818B).withValues(alpha: 0.7);
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // Handle + başlık
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              decoration: BoxDecoration(
                color: sheetTop,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.15 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _kPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_rounded,
                            color: _kPrimary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(L.settings,
                          style: TextStyle(
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
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
                    onChanged: _setSound,
                  ),
                  _SettingsToggle(
                    icon: Icons.vibration_rounded,
                    iconColor: const Color(0xFF81C784),
                    label: L.haptic,
                    value: _haptic,
                    onChanged: _setHaptic,
                  ),
                  _SettingsToggle(
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFFBA68C8),
                    label: L.notifications,
                    value: _notifs,
                    onChanged: (v) async {
                      if (v) {
                        // User-driven prompt — yalnız toggle ON yapınca ister.
                        final settings = await NotificationService.instance
                            .requestNotificationPermission();
                        final granted = settings.authorizationStatus ==
                                AuthorizationStatus.authorized ||
                            settings.authorizationStatus ==
                                AuthorizationStatus.provisional;
                        if (!mounted) return;
                        setState(() => _notifs = granted);
                      } else {
                        setState(() => _notifs = false);
                      }
                    },
                  ),
                  _SettingsToggle(
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF4FC3F7),
                    label: _darkMode ? L.darkMode : L.darkModeOff,
                    value: _darkMode,
                    onChanged: _setDarkMode,
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
                    icon: Icons.privacy_tip_outlined,
                    iconColor: const Color(0xFF7E57C2),
                    label: L.privacyPolicy,
                    onTap: () => Navigator.push(
                      context,
                      appRoute(const PrivacyPolicyScreen()),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor:
                        isDark ? Colors.white38 : const Color(0xFF5A6872),
                    label: L.about,
                    trailing: Text('v${VersionService.currentVersion}',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.28)
                                : const Color(0xFF53616A),
                            fontSize: 12)),
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
  int _xp = 0;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;
    final isAnon = AuthService.instance.isAnonymous;
    final cardBg = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
    final titleColor = isDark ? Colors.white : const Color(0xFF1C2830);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF52606A);
    final signInAccent = isDark ? _kPrimary : const Color(0xFF145C37);
    final guestBadgeText = isDark ? Colors.white60 : const Color(0xFF34434C);
    final guestBadgeBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF9EACB4).withValues(alpha: 0.75);
    final guestBadgeBorder = isDark
        ? Colors.white12
        : const Color(0xFF6C7B85).withValues(alpha: 0.55);
    final borderColor = isAnon
        ? _kPrimary.withValues(alpha: 0.35)
        : isDark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFF7B8992).withValues(alpha: 0.55);
    final name = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!
        : (_profileName?.trim().isNotEmpty == true
            ? _profileName!
            : AuthService.instance.effectiveDisplayName);
    final email = user?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final photoUrl = user?.photoURL;

    return GestureDetector(
      onTap: isAnon ? widget.onSignInTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 54,
              height: 54,
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
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (email.isNotEmpty)
                    Text(email,
                        style: TextStyle(color: mutedColor, fontSize: 12))
                  else if (isAnon)
                    Text(L.signInToSaveScores,
                        style: TextStyle(
                            color: signInAccent.withValues(alpha: 0.95),
                            fontSize: 11)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAnon
                          ? guestBadgeBg
                          : _kPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAnon
                            ? guestBadgeBorder
                            : _kPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isAnon ? L.guestBadge : L.levelXp(_level, _xp),
                      style: TextStyle(
                        color: isAnon ? guestBadgeText : _kPrimary,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: signInAccent.withValues(alpha: isDark ? 0.15 : 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: signInAccent.withValues(alpha: 0.55)),
                ),
                child: Text(L.signIn,
                    style: TextStyle(
                        color: signInAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFF5F6C75)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : const Color(0xFF46545D),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF7B8992).withValues(alpha: 0.55);
    final textColor = isDark ? Colors.white70 : const Color(0xFF25313A);
    final chevronColor =
        isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF5E6B74);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.mediumImpact();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(14),
        splashColor: _kPrimary.withValues(alpha: 0.08),
        highlightColor: _kPrimary.withValues(alpha: 0.03),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: TextStyle(color: textColor, fontSize: 14))),
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      color: chevronColor, size: 18),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF7B8992).withValues(alpha: 0.55);
    final textColor = isDark ? Colors.white70 : const Color(0xFF25313A);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: textColor, fontSize: 14))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF7B8992).withValues(alpha: 0.55);
    final textColor = isDark ? Colors.white70 : const Color(0xFF25313A);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: textColor, fontSize: 14))),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.mediumImpact();
              onChanged(v);
            },
            activeColor: _kPrimary,
            activeTrackColor: _kPrimary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor:
                isDark ? Colors.white12 : const Color(0xFF89969E),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A2535) : const Color(0xFFF4F8FA);
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor = isDark ? Colors.white54 : const Color(0xFF52636E);
    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFC8D4DB),
                    borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: mutedColor, size: 20),
                  const SizedBox(width: 10),
                  Text(L.statistics,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              if (stats == null)
                const Center(child: CircularProgressIndicator(color: _kPrimary))
              else
                Row(
                  children: [
                    _StatCell(label: L.totalGames, value: '${stats.played}'),
                    _StatCell(label: L.winRate, value: '${stats.percentWon}%'),
                    _StatCell(label: L.bestScore, value: '${stats.highScore}'),
                    _StatCell(
                        label: 'Streak', value: '${stats.streak.current}'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEAF1F4);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD6E1E7);
    final valueColor = isDark ? Colors.white : const Color(0xFF18242C);
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF52636E);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: labelColor, fontSize: 10),
                textAlign: TextAlign.center),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFD6E1E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.20)
              : const Color(0xFF88949C).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangBtn(
              label: 'KU',
              active: cur == AppLocale.ku,
              onTap: () {
                L.set(AppLocale.ku);
                onChanged();
              }),
          const SizedBox(width: 4),
          _LangBtn(
              label: 'TR',
              active: cur == AppLocale.tr,
              onTap: () {
                L.set(AppLocale.tr);
                onChanged();
              }),
        ],
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: _kPrimary.withValues(alpha: 0.2),
        highlightColor: _kPrimary.withValues(alpha: 0.1),
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
              color: active
                  ? Colors.white
                  : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : const Color(0xFF56616A),
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
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            borderRadius: BorderRadius.circular(22),
            splashColor: _kGold.withValues(alpha: 0.08),
            highlightColor: _kGold.withValues(alpha: 0.04),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F1809), Color(0xFF130C04)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: _kGold.withValues(alpha: 0.30 + 0.08 * t), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8860B)
                        .withValues(alpha: 0.18 + 0.06 * t),
                    blurRadius: 28,
                    spreadRadius: -4,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
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
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _kGold.withValues(
                                    alpha: 0.25 + 0.1 * _pulse.value),
                                _kGoldDim.withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _kGold.withValues(
                                    alpha: 0.4 + 0.2 * _pulse.value)),
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
                                      color: _kPrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color:
                                              _kPrimary.withValues(alpha: 0.4)),
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
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _kGold.withValues(alpha: 0.5),
                          size: 22,
                        ),
                      ],
                    ),
                  ),

                  // ── Ayraç ──────────────────────────────────────
                  Container(height: 1, color: _kGold.withValues(alpha: 0.12)),

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
                                    color: _kGold.withValues(alpha: 0.7),
                                    size: 13),
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
                                        color:
                                            Colors.white.withValues(alpha: 0.4),
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
                                color: const Color(0xFFFF3D00)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFFF6E40)
                                        .withValues(alpha: 0.5)),
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
                                  colors: [
                                    Color(0xFFFFD27A),
                                    Color(0xFFB8860B)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFB300)
                                        .withValues(alpha: 0.30 + 0.12 * t),
                                    blurRadius: 14,
                                    spreadRadius: 0,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    L.current == AppLocale.tr
                                        ? 'Katıl'
                                        : 'Tevlî bibe',
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

  static const _kGold = Color(0xFFFFD700);

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
              _MiniSlot(name: 'Roja', filled: true),
              _MiniSlot(name: 'Dilan', filled: true),
              _MiniSlot(name: 'Baran', filled: true),
              _MiniSlot(name: L.you, filled: true, isMe: true),
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
                    color: _kGold.withValues(alpha: 0.5),
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

  static const _kGold = Color(0xFFFFD700);
  static const _kPrimary = Color(0xFF4CAF50);

  const _MiniSlot(
      {required this.name, required this.filled, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? (isMe
                ? _kPrimary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: filled
              ? (isMe
                  ? _kPrimary.withValues(alpha: 0.5)
                  : _kGold.withValues(alpha: 0.3))
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
      ..color = const Color(0xFFB8860B).withValues(alpha: 0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final segH = size.height / pairs;
    for (var i = 0; i < pairs ~/ 2; i++) {
      final y1 = segH * (i * 2) + segH * 0.5;
      final y2 = segH * (i * 2 + 1) + segH * 0.5;
      final yMid = (y1 + y2) / 2;
      canvas.drawLine(Offset(0, y1), Offset(size.width / 2, y1), paint);
      canvas.drawLine(Offset(0, y2), Offset(size.width / 2, y2), paint);
      canvas.drawLine(
        Offset(size.width / 2, y1),
        Offset(size.width / 2, y2),
        paint,
      );
      canvas.drawLine(
        Offset(size.width / 2, yMid),
        Offset(size.width, yMid),
        paint,
      );
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
    if (mounted) {
      setState(() => _loadingGames = true);
    }
    final games = await FirestoreService.instance.getRecentGames(uid);
    if (mounted) {
      setState(() {
        _firestoreGames = games;
        _loadingGames = false;
      });
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }

  String _timeAgoFromTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      return _timeAgo(dt);
    } catch (_) {
      // Firestore Timestamp değil — sessizce boş döndür (yaygın)
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStore.instance;
    final hasActiveGame = store.activeController != null &&
        store.activeRecord != null &&
        !store.activeRecord!.isFinished;
    final hasGame =
        hasActiveGame || _firestoreGames.isNotEmpty || _loadingGames;

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
        border: Border.all(color: _kGold.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Başlık satırı — tıklanabilir
          GestureDetector(
            onTap:
                hasGame ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kGold.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        color: _kGold, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.myGames,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(
                          _loadingGames
                              ? '...'
                              : hasGame
                                  ? L.gamesCount(_firestoreGames.length +
                                      (hasActiveGame ? 1 : 0))
                                  : L.noGames,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hasGame)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.4), size: 22),
                    ),
                ],
              ),
            ),
          ),

          // Oyun listesi
          if (hasGame && _expanded) ...[
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),

            // Aktif (devam eden) oyun — memory'den
            if (hasActiveGame)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: store.activeController != null
                      ? () => widget.onResume(store.activeController)
                      : null,
                  splashColor: _kPrimary.withValues(alpha: 0.10),
                  highlightColor: _kPrimary.withValues(alpha: 0.05),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.05),
                      border: Border(
                          bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.04))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _kPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L.active,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                'Sen ${store.activeRecord!.playerScore} — AI ${store.activeRecord!.aiScore}  •  ${_timeAgo(store.activeRecord!.startedAt)}',
                                style: const TextStyle(
                                    color: Colors.white30, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _kPrimary.withValues(alpha: 0.4)),
                          ),
                          child: Text(L.resume,
                              style: const TextStyle(
                                  color: _kPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
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
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kGold))),
              ),

            // Geçmiş oyunlar — Firestore'dan
            ..._firestoreGames.take(3).map((game) {
              final won = game['won'] as bool? ?? false;
              final playerScore = game['playerScore'] as int? ?? 0;
              final aiScore = game['aiScore'] as int? ?? 0;
              final timeAgo = _timeAgoFromTimestamp(game['playedAt']);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.04))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: won
                            ? _kPrimary.withValues(alpha: 0.6)
                            : Colors.white24,
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
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 11),
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
