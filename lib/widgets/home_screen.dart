import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/game_store.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/services/kurdish_meanings.dart';
import 'package:kurdle_app/services/daily_word_service.dart';
import 'package:kurdle_app/services/stats_service.dart';
import 'package:kurdle_app/widgets/auth_screen.dart';
import 'package:kurdle_app/widgets/how_to_play_screen.dart';
import 'package:kurdle_app/widgets/onboarding_screen.dart';
import 'package:kurdle_app/services/onboarding_service.dart';
import 'package:kurdle_app/widgets/profile_screen.dart';
import 'package:kurdle_app/widgets/scrabble_game_screen.dart';
import 'package:kurdle_app/widgets/tournament_screen.dart';
import 'package:kurdle_app/widgets/wordle_game_screen.dart';

const _kBg       = Color(0xFF0F1923);
const _kSurface  = Color(0xFF1A2533);
const _kPrimary  = Color(0xFF4CAF50);
const _kGold     = Color(0xFFFFD700);
const _kGoldDim  = Color(0xFFB8860B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
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
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Header
          _HomeHeader(
            statusBarHeight: top,
            onLocaleChanged: () => setState(() {}),
            onSettingsTap: () => _showSettingsSheet(context),
            onStatsTap: () => _showStatsSheet(context),
            onOptionsTap: (btnCtx) => _showOptionsMenu(btnCtx),
          ),

          // Menu cards
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, bottom + 24),
              child: Column(
                children: [
                  _GununKelimesiCard(),
                  const SizedBox(height: 14),
                  _SiralamalarCard(),
                  const SizedBox(height: 14),
                  _YeniOyunCard(
                    onAi: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScrabbleGameScreen()),
                    ).then((_) => setState(() {})),
                    onFriend: () => _showComingSoon(context),
                    onRandom: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: 14),
                  _OyunlarimCard(
                    onResume: (ctrl) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScrabbleGameScreen(existingController: ctrl),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const SizedBox(height: 14),
                  _TurnuvaModuCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TournamentScreen()),
                    ),
                  ),
                ],
              ),
            ),
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
      if (val == 'how_to_play') {
        _showHowTo(context);
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
    );
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
                            'Henüz skor yok',
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _revealed = false;
  int _globalPlayed = 0;
  int _globalWon    = 0;

  static ({String word, String meaning}) _todaysWord() {
    final entries = KurdishMeanings.allEntries;
    final index = DateTime.now().difference(DateTime(2025, 1, 1)).inDays % entries.length;
    return entries[index];
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _loadGlobalStats();
  }

  Future<void> _loadGlobalStats() async {
    final stats = await DailyWordService.instance.fetchTodayStats();
    if (stats != null && mounted) {
      setState(() { _globalPlayed = stats.totalPlayed; _globalWon = stats.totalWon; });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _reveal() {
    HapticFeedback.mediumImpact();
    if (_revealed) {
      setState(() => _revealed = false);
      _anim.reverse();
    } else {
      setState(() => _revealed = true);
      _anim.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _todaysWord();
    final letters = today.word.split('');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1040), Color(0xFF2D1B69), Color(0xFF11235A)],
        ),
        border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Başlık + harf karoları + buton — hepsi tek satırda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFB39DDB), size: 14),
                const SizedBox(width: 6),
                Text(L.wordOfDay,
                    style: const TextStyle(color: Color(0xFFB39DDB), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                ...letters.map((ch) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 26, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.5), width: 1.2),
                  ),
                  child: Center(
                    child: Text(ch,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                )),
                const Spacer(),
                // Oyna butonu
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WordleGameScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Oyna',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                // Anlam / Keşfet butonu
                if (!_revealed)
                  GestureDetector(
                    onTap: _reveal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF512DA8)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(L.revealMeaning,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),

          if (_revealed)
            SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: GestureDetector(
                  onTap: _reveal,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.translate_rounded, color: Color(0xFFB39DDB), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L.meaningLabel,
                                  style: TextStyle(color: const Color(0xFFB39DDB).withOpacity(0.7), fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(today.meaning,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white.withOpacity(0.25), size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        if (_globalPlayed > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Icon(Icons.people_alt_rounded, color: const Color(0xFFB39DDB).withOpacity(0.5), size: 12),
                const SizedBox(width: 5),
                Text(
                  'Bugün $_globalPlayed kişi oynadı · %${_globalPlayed > 0 ? (_globalWon / _globalPlayed * 100).round() : 0} kazandı',
                  style: TextStyle(color: const Color(0xFFB39DDB).withOpacity(0.5), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const months = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    return months[m - 1];
  }
}

class _YeniOyunCard extends StatefulWidget {
  final VoidCallback onAi;
  final VoidCallback onFriend;
  final VoidCallback onRandom;

  const _YeniOyunCard({
    required this.onAi,
    required this.onFriend,
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
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
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
              badge: L.soon,
              onTap: widget.onFriend,
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.04)),
            _SubOption(
              icon: Icons.search_rounded,
              iconColor: const Color(0xFFFFB74D),
              title: L.findPlayer,
              badge: L.soon,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
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
    );
  }
}

// ── Home Header ──────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final double statusBarHeight;
  final VoidCallback onLocaleChanged;
  final VoidCallback onSettingsTap;
  final VoidCallback onStatsTap;
  final void Function(BuildContext) onOptionsTap;

  const _HomeHeader({
    required this.statusBarHeight,
    required this.onLocaleChanged,
    required this.onSettingsTap,
    required this.onStatsTap,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2535), Color(0xFF0F1923)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sol grup: Ayarlar + İstatistikler
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                icon: Icons.settings_rounded,
                tooltip: L.settings,
                onTap: onSettingsTap,
              ),
              const SizedBox(width: 6),
              _IconBtn(
                icon: Icons.bar_chart_rounded,
                tooltip: L.statistics,
                onTap: onStatsTap,
              ),
            ],
          ),

          // Orta: Logo + başlık
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('P',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Peyvok',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  L.appSubtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 10, letterSpacing: 0.3),
                ),
              ],
            ),
          ),

          // Sağ grup: Dil seçici + Seçenekler
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LangSwitcher(onChanged: onLocaleChanged),
              const SizedBox(width: 6),
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
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

  void _showAuthScreen(BuildContext ctx) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          onSuccess: () {
            Navigator.pop(ctx);
            setState(() {});
          },
        ),
      ),
    );
  }

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
                  if (!AuthService.instance.isAnonymous) ...[
                    _SettingsTile(
                      icon: Icons.edit_rounded,
                      iconColor: const Color(0xFF64B5F6),
                      label: L.editProfile,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                    ),
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
                  ] else
                    _SettingsTile(
                      icon: Icons.login_rounded,
                      iconColor: _kPrimary,
                      label: 'Giriş Yap / Kayıt Ol',
                      onTap: () {
                        Navigator.pop(context);
                        _showAuthScreen(context);
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
                    label: L.darkMode,
                    value: _darkMode,
                    onChanged: (v) => setState(() => _darkMode = v),
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
                    onTap: () {},
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
      setState(() { _level = profile.level; _xp = profile.xp; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user       = AuthService.instance.currentUser;
    final isAnon     = AuthService.instance.isAnonymous;
    final name       = user?.displayName ?? (isAnon ? 'Anonim Oyuncu' : 'Oyuncu');
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
                    Text('Giriş yaparak skorlarını kaydet',
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
                      isAnon ? 'Giriş Yapılmadı' : 'Seviye $_level · $_xp XP',
                      style: TextStyle(
                        color: isAnon ? Colors.white38 : _kPrimary,
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
                child: const Text('Giriş Yap',
                    style: TextStyle(color: _kPrimary,
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
    return GestureDetector(
      onTap: onTap,
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
            onChanged: onChanged,
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
          _LangBtn(label: 'TR', active: cur == AppLocale.tr,
              onTap: () { L.set(AppLocale.tr); onChanged(); }),
          const SizedBox(width: 4),
          _LangBtn(label: 'KU', active: cur == AppLocale.ku,
              onTap: () { L.set(AppLocale.ku); onChanged(); }),
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
    return GestureDetector(
      onTap: onTap,
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
    return GestureDetector(
      onTap: onTap,
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
        final glow = 0.18 + 0.12 * _pulse.value;
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A1A00), Color(0xFF3D2800), Color(0xFF1C1000)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kGold.withOpacity(0.55), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _kGold.withOpacity(glow),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
                          const SizedBox(height: 10),
                          // Katıl butonu
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(const Color(0xFF8B6000),
                                      const Color(0xFFB8860B), _pulse.value)!,
                                  const Color(0xFF5A3D00),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _kGold.withOpacity(0.6 + 0.3 * _pulse.value)),
                              boxShadow: [
                                BoxShadow(
                                  color: _kGold.withOpacity(0.2 + 0.15 * _pulse.value),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              L.current == AppLocale.tr
                                  ? 'Katıl  →'
                                  : 'Tevlî bibe  →',
                              style: const TextStyle(
                                color: _kGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
              _MiniSlot(name: 'Sen',   filled: true, isMe: true),
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
              GestureDetector(
                onTap: store.activeController != null
                    ? () => widget.onResume(store.activeController)
                    : null,
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
