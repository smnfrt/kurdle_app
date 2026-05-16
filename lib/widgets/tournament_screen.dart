import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/notification_service.dart';
import 'package:kurdle_app/widgets/scrabble_game_screen.dart';

const _kBg      = Color(0xFF0D0A00);
const _kGold    = Color(0xFFFFD700);
const _kPrimary = Color(0xFF4CAF50);

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;
  late Timer _countdownTimer;
  Duration _remaining = Duration.zero;

  StreamSubscription<QuerySnapshot>? _tournamentSub;
  DocumentSnapshot? _tournament;
  bool _loading = true;
  bool _joining = false;

  Map<String, dynamic> get _data =>
      (_tournament?.data() as Map<String, dynamic>?) ?? {};

  List<Map<String, dynamic>> get _players =>
      List<Map<String, dynamic>>.from(_data['players'] ?? []);

  int get _maxPlayers => _data['maxPlayers'] ?? 8;

  bool get _joined {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
    return _players.any((p) => p['uid'] == uid);
  }

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });

    _loadTournament();
  }

  void _updateCountdown() {
    if (_tournament == null) return;
    final startAt = (_data['startAt'] as Timestamp?)?.toDate();
    if (startAt == null) return;
    final remaining = startAt.difference(DateTime.now());
    if (mounted) setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  Future<void> _loadTournament() async {
    if (!FirebaseService.isAvailable) {
      setState(() => _loading = false);
      return;
    }
    await FirestoreService.instance.ensureWeeklyTournament();
    _tournamentSub = FirestoreService.instance
        .activeTournamentsStream()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _tournament = snap.docs.isNotEmpty ? snap.docs.first : null;
          _loading = false;
        });
        _updateCountdown();
        _autoStartIfReady();
      }
    });
  }

  // Turnuva dolmuş veya süresi gelmiş ve hâlâ 'waiting' ise başlat
  void _autoStartIfReady() {
    if (_tournament == null) return;
    final status = _data['status'] as String? ?? '';
    if (status != 'waiting') return;

    final isFull = _players.length >= _maxPlayers;
    final startAt = (_data['startAt'] as Timestamp?)?.toDate();
    final timeUp  = startAt != null && DateTime.now().isAfter(startAt);

    if ((isFull || timeUp) && _players.length >= 2) {
      FirestoreService.instance.startTournament(_tournament!.id);
    }
  }

  Future<void> _openTournamentMatch() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || _tournament == null) return;

    final match = await FirestoreService.instance.getActiveMatch(
      tournamentId: _tournament!.id,
      uid: uid,
    );

    if (!mounted) return;

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şu an aktif maçın yok, sıradaki tur bekleniyor.')),
      );
      return;
    }

    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ScrabbleGameScreen(tournamentMatchId: match['id'] as String),
      ),
    );

    // Oyun bitince skoru gönder
    if (result != null && _tournament != null) {
      await FirestoreService.instance.submitMatchScore(
        tournamentId: _tournament!.id,
        matchId: match['id'] as String,
        uid: uid,
        score: result,
      );
    }
  }

  Future<void> _joinTournament() async {
    final uid = AuthService.instance.currentUser?.uid;
    final displayName = AuthService.instance.currentUser?.displayName?.trim().isNotEmpty == true
        ? AuthService.instance.currentUser!.displayName!
        : AuthService.instance.effectiveDisplayName;
    if (uid == null || _tournament == null) return;

    setState(() => _joining = true);
    final err = await FirestoreService.instance.joinTournament(
      tournamentId: _tournament!.id,
      uid: uid,
      displayName: displayName,
    );
    if (mounted) {
      setState(() => _joining = false);
      if (err == null) {
        HapticFeedback.mediumImpact();
        // Turnuva başlamadan 30dk önce hatırlatıcı planla
        final startAt = (_data['startAt'] as Timestamp?)?.toDate();
        if (startAt != null) {
          NotificationService.instance.scheduleTournamentReminder(startAt);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Text('🏆 '),
              Text(_TL.joinedTournament, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            backgroundColor: const Color(0xFF2A1A00),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _kGold.withValues(alpha: 0.5)),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (err.contains('full')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turnuva dolu!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    _countdownTimer.cancel();
    _tournamentSub?.cancel();
    super.dispose();
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');

  String get _countdownStr {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    return '${_fmt2(h)}:${_fmt2(m)}:${_fmt2(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(top),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kGold))
                : _tournament == null
                    ? _buildNoTournament()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildPrizeSection(),
                            const SizedBox(height: 20),
                            _buildBracket(),
                            const SizedBox(height: 20),
                            _buildJoinButton(),
                            const SizedBox(height: 16),
                            _buildRulesCard(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTournament() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Şu an aktif turnuva yok',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Yakında yeni turnuva başlayacak',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double top) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final glowOpacity = 0.2 + 0.15 * _glow.value;
        return Container(
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1A00), Color(0xFF1C1400), Color(0xFF2A1A00)],
            ),
            boxShadow: [
              BoxShadow(
                color: _kGold.withValues(alpha: glowOpacity),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white54, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🏆 ',
                            style: TextStyle(fontSize: 18)),
                        Text(
                          _TL.tournamentTitle,
                          style: const TextStyle(
                            color: _kGold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _TL.tournamentSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Geri sayım
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _countdownStr,
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _TL.tournamentStartsIn,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 8,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrizeSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D2800), Color(0xFF1C1400)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kGold.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _TL.prizePool,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PrizeTile(rank: '🥇', label: _TL.prize1st, value: '5000 XP'),
                Container(width: 1, height: 50, color: Colors.white12),
                _PrizeTile(rank: '🥈', label: _TL.prize2nd, value: '2500 XP'),
                Container(width: 1, height: 50, color: Colors.white12),
                _PrizeTile(rank: '🥉', label: _TL.prize3rd, value: '1000 XP'),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_alt_rounded, color: _kGold.withValues(alpha: 0.7), size: 14),
                const SizedBox(width: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${_players.length}',
                        style: const TextStyle(
                          color: _kGold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: ' / $_maxPlayers  ${_TL.playersJoined}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _maxPlayers > 0 ? _players.length / _maxPlayers : 0,
                      backgroundColor: Colors.white12,
                      color: _kGold,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracket() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withValues(alpha: 0.2), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, color: _kGold, size: 16),
              const SizedBox(width: 8),
              Text(
                _TL.bracket,
                style: const TextStyle(
                  color: _kGold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _TL.waitingToStart,
                  style: const TextStyle(color: _kPrimary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BracketWidget(
            players: List.generate(_maxPlayers, (i) {
              final myUid = AuthService.instance.currentUser?.uid;
              if (i < _players.length) {
                final p = _players[i];
                return (
                  name: p['displayName'] as String? ?? 'Oyuncu',
                  score: p['score'] as int? ?? 0,
                  status: 'waiting',
                  isMe: p['uid'] == myUid,
                );
              }
              return (name: '???', score: 0, status: 'empty', isMe: false);
            }),
            myUid: AuthService.instance.currentUser?.uid,
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        return GestureDetector(
          onTap: _joining
              ? null
              : () {
                  if (!_joined) {
                    _joinTournament();
                  } else if (_data['status'] == 'active') {
                    _openTournamentMatch();
                  }
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _joined
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [
                        Color.lerp(const Color(0xFF7A5000), const Color(0xFFB87000),
                            0.4 + 0.3 * _glow.value)!,
                        const Color(0xFF7A5000),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _joined ? _kPrimary.withValues(alpha: 0.6) : _kGold.withValues(alpha: 0.6 + 0.3 * _glow.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_joined ? _kPrimary : _kGold)
                      .withValues(alpha: 0.25 + 0.15 * _glow.value),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _joined ? Icons.sports_esports_rounded : Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _joined ? _TL.playTournament : _TL.joinTournament,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRulesCard() {
    final rules = [
      (icon: Icons.timer_rounded,         color: const Color(0xFF64B5F6), text: _TL.tournRule1),
      (icon: Icons.emoji_events_rounded,  color: _kGold,                  text: _TL.tournRule2),
      (icon: Icons.block_rounded,         color: const Color(0xFFFF6B6B), text: _TL.tournRule3),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_TL.tournamentRules,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: r.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(r.icon, color: r.color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.text,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Ödül kutusu ──────────────────────────────────────────────────

class _PrizeTile extends StatelessWidget {
  final String rank;
  final String label;
  final String value;

  const _PrizeTile({required this.rank, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(rank, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: _kGold, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
      ],
    );
  }
}

// ── Turnuva Bracket Görseli ──────────────────────────────────────

class _BracketWidget extends StatelessWidget {
  final List<({String name, int score, String status, bool isMe})> players;
  final String? myUid;

  const _BracketWidget({required this.players, this.myUid});

  @override
  Widget build(BuildContext context) {
    // 8 kişi → 4 eşleşme → 2 → 1 final
    final pairs = [
      (players[0], players[1]),
      (players[2], players[3]),
      (players[4], players[5]),
      (players[6], players[7]),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Çeyrek final
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Text(_TL.quarterFinal,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _MatchPair(p1: pairs[0].$1, p2: pairs[0].$2),
              const SizedBox(height: 6),
              _MatchPair(p1: pairs[1].$1, p2: pairs[1].$2),
              const SizedBox(height: 6),
              _MatchPair(p1: pairs[2].$1, p2: pairs[2].$2),
              const SizedBox(height: 6),
              _MatchPair(p1: pairs[3].$1, p2: pairs[3].$2),
            ],
          ),
        ),

        // Bağlantı çizgileri
        SizedBox(
          width: 20,
          child: CustomPaint(
            size: const Size(20, 200),
            painter: _BracketLinesPainter(pairs: 4),
          ),
        ),

        // Yarı final
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_TL.semiFinal,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _EmptySlot(),
              const SizedBox(height: 30),
              _EmptySlot(),
              const SizedBox(height: 30),
              _EmptySlot(),
              const SizedBox(height: 30),
              _EmptySlot(),
            ],
          ),
        ),

        // Bağlantı çizgileri
        SizedBox(
          width: 20,
          child: CustomPaint(
            size: const Size(20, 200),
            painter: _BracketLinesPainter(pairs: 2),
          ),
        ),

        // Final
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_TL.final_,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _EmptySlot(isWinner: false),
              const SizedBox(height: 80),
              _EmptySlot(isWinner: false),
              const SizedBox(height: 8),
              // Kupa
              const Center(
                child: Text('🏆', style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchPair extends StatelessWidget {
  final ({String name, int score, String status, bool isMe}) p1;
  final ({String name, int score, String status, bool isMe}) p2;

  const _MatchPair({required this.p1, required this.p2});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlayerSlot(player: p1),
        const SizedBox(height: 2),
        _PlayerSlot(player: p2),
      ],
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final ({String name, int score, String status, bool isMe}) player;
  const _PlayerSlot({required this.player});

  @override
  Widget build(BuildContext context) {
    final isEmpty = player.status == 'empty';
    final isMe    = player.isMe;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.white.withValues(alpha: 0.03)
            : isMe
                ? _kPrimary.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEmpty
              ? Colors.white12
              : isMe
                  ? _kPrimary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEmpty
                  ? Colors.white24
                  : isMe
                      ? _kPrimary
                      : _kGold.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              isEmpty ? '???' : player.name,
              style: TextStyle(
                color: isEmpty
                    ? Colors.white24
                    : isMe
                        ? _kPrimary
                        : Colors.white70,
                fontSize: 10,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final bool isWinner;
  const _EmptySlot({this.isWinner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWinner ? _kGold.withValues(alpha: 0.4) : Colors.white12,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWinner ? _kGold.withValues(alpha: 0.5) : Colors.white24,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '???',
            style: TextStyle(
              color: isWinner ? _kGold.withValues(alpha: 0.4) : Colors.white24,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bracket bağlantı çizgileri ───────────────────────────────────

class _BracketLinesPainter extends CustomPainter {
  final int pairs;
  const _BracketLinesPainter({required this.pairs});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B).withValues(alpha: 0.4)
      ..strokeWidth = 1.0
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
  bool shouldRepaint(_BracketLinesPainter oldDelegate) => false;
}

// ── Turnuva locale yardımcısı ────────────────────────────────────

class _TL {
  static bool get _tr => L.current == AppLocale.tr;
  static String get tournamentTitle    => _tr ? 'Haftalık Turnuva'             : 'Turnuvaya Hefteyî';
  static String get tournamentSubtitle => _tr ? '8 oyunculu tek eleme'         : '8 lîstikvan · jêbirina yekane';
  static String get tournamentStartsIn => _tr ? 'BAŞLAMASINA'                  : 'DEST PÊ DIKE';
  static String get prizePool          => _tr ? 'ÖDÜL HAVUZU'                  : 'XELAT';
  static String get prize1st           => _tr ? '1. Sıra'                      : 'Yekem';
  static String get prize2nd           => _tr ? '2. Sıra'                      : 'Duyem';
  static String get prize3rd           => _tr ? '3. Sıra'                      : 'Sêyem';
  static String get playersJoined      => _tr ? 'oyuncu katıldı'               : 'lîstikvan ketin';
  static String get bracket            => _tr ? 'Turnuva Tablosu'              : 'Tabela Turnuvayê';
  static String get waitingToStart     => _tr ? 'Başlamayı Bekliyor'           : 'Destpêkê Dixwaze';
  static String get quarterFinal       => _tr ? 'ÇEY. FİNAL'                  : 'ÇEYREK';
  static String get semiFinal          => _tr ? 'YARI FİNAL'                   : 'NÎVFÎNAL';
  static String get final_             => _tr ? 'FİNAL'                        : 'FİNAL';
  static String get joinTournament     => _tr ? 'Turnuvaya Katıl'              : 'Tevlî Turnuvayê Bibe';
  static String get playTournament     => _tr ? 'Turnuva Oyununu Oyna'         : 'Lîstika Turnuvayê Bilîze';
  static String get joinedTournament   => _tr ? 'Turnuvaya katıldın!'          : 'Tu beşdarî turnuvayê bûyî!';
  static String get tournamentRules    => _tr ? 'KURALLAR'                     : 'RÊZIK';
  static String get tournRule1         => _tr ? 'Her tur 5 dakika, en yüksek skoru yapan turu kazanır.'  : 'Her ger 5 deqîqe ye, yê herî xalên bilind hebe dê bi ser bikeve.';
  static String get tournRule2         => _tr ? 'Tüm turları kazanan şampiyon olur ve XP ödülü alır.'    : 'Yê ku hemû geran bi dest bixe şampiyon dibe û XP werdigire.';
  static String get tournRule3         => _tr ? 'Geçersiz kelime yerleştirmek tur puanını sıfırlar.'     : 'Danîna peyva nederbasdar xalên gerê sifir dike.';
}
