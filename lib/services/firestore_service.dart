import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ISO hafta numarası: "2026-W17" formatında döner — haftalık sıfırlama için kullanılır
String _currentWeekOf() {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  final weekNum = ((dayOfYear + DateTime(now.year, 1, 1).weekday - 1) / 7).floor() + 1;
  return '${now.year}-W${weekNum.toString().padLeft(2, '0')}';
}

// ── Veri modelleri ────────────────────────────────────────────────

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final int xp;
  final int level;
  final GameStats stats;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.xp,
    required this.level,
    required this.stats,
    required this.createdAt,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: d['displayName'] ?? 'Oyuncu',
      email: d['email'] ?? '',
      xp: d['xp'] ?? 0,
      level: d['level'] ?? 1,
      stats: GameStats.fromMap(d['stats'] ?? {}),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'email': email,
    'xp': xp,
    'level': level,
    'stats': stats.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class GameStats {
  final int played;
  final int won;
  final int highScore;
  final int totalScore;
  final int streak;

  const GameStats({
    this.played = 0,
    this.won = 0,
    this.highScore = 0,
    this.totalScore = 0,
    this.streak = 0,
  });

  factory GameStats.fromMap(Map<String, dynamic> m) => GameStats(
    played:     m['played']     ?? 0,
    won:        m['won']        ?? 0,
    highScore:  m['highScore']  ?? 0,
    totalScore: m['totalScore'] ?? 0,
    streak:     m['streak']     ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'played':     played,
    'won':        won,
    'highScore':  highScore,
    'totalScore': totalScore,
    'streak':     streak,
  };
}

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int score;
  final int rank;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.score,
    required this.rank,
  });

  factory LeaderboardEntry.fromDoc(DocumentSnapshot doc, int rank) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      uid: doc.id,
      displayName: d['displayName'] ?? 'Oyuncu',
      score: d['score'] ?? 0,
      rank: rank,
    );
  }
}

// ── FirestoreService ──────────────────────────────────────────────

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference get _users        => _db.collection('users');
  CollectionReference get _games        => _db.collection('games');
  CollectionReference get _tournaments  => _db.collection('tournaments');

  DocumentReference _weeklyLB(String uid)  => _db.collection('leaderboard').doc('weekly').collection('entries').doc(uid);
  DocumentReference _allTimeLB(String uid) => _db.collection('leaderboard').doc('allTime').collection('entries').doc(uid);

  // ── Kullanıcı ─────────────────────────────────────────────────────

  // Yeni kullanıcı dokümanı oluşturur (ilk girişte çağrılır)
  Future<void> createUserIfNotExists(User firebaseUser) async {
    final ref = _users.doc(firebaseUser.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'displayName': firebaseUser.displayName ?? 'Oyuncu',
        'email': firebaseUser.email ?? '',
        'xp': 0,
        'level': 1,
        'stats': GameStats().toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  Stream<UserProfile?> profileStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  Future<void> updateDisplayName(String uid, String name) =>
      _users.doc(uid).update({'displayName': name});

  // ── Oyun bittikten sonra skor kaydet ─────────────────────────────

  Future<void> saveGameResult({
    required String uid,
    required int playerScore,
    required int aiScore,
    required bool won,
    required int durationSeconds,
  }) async {
    final batch = _db.batch();

    // 1) Oyun kaydı
    final gameRef = _games.doc();
    batch.set(gameRef, {
      'playerUid': uid,
      'playerScore': playerScore,
      'aiScore': aiScore,
      'won': won,
      'durationSeconds': durationSeconds,
      'playedAt': FieldValue.serverTimestamp(),
    });

    // 2) Kullanıcı istatistikleri — transaction daha güvenli ama batch yeterli burada
    final xpGained = won ? 100 + playerScore ~/ 10 : 20 + playerScore ~/ 20;

    batch.update(_users.doc(uid), {
      'xp': FieldValue.increment(xpGained),
      'stats.played':     FieldValue.increment(1),
      'stats.won':        FieldValue.increment(won ? 1 : 0),
      'stats.totalScore': FieldValue.increment(playerScore),
    });

    await batch.commit();

    // 3) Yüksek skor ve liderlik tablosu — ayrı transaction gerektirir
    await _updateHighScoreAndLeaderboard(uid, playerScore);
  }

  Future<void> _updateHighScoreAndLeaderboard(String uid, int score) async {
    await _db.runTransaction((tx) async {
      final userRef = _users.doc(uid);
      final snap    = await tx.get(userRef);
      final current = (snap.data() as Map?)?.cast<String, dynamic>() ?? {};
      final currentHigh = current['stats']?['highScore'] ?? 0;

      if (score > currentHigh) {
        tx.update(userRef, {'stats.highScore': score});
      }

      // Haftalık ve tüm zamanlar liderlik tablosu
      final weeklyRef  = _weeklyLB(uid);
      final allTimeRef = _allTimeLB(uid);
      final displayName = current['displayName'] ?? 'Oyuncu';

      final weeklySnap = await tx.get(weeklyRef);
      final weeklyData = (weeklySnap.data() as Map?)?.cast<String, dynamic>() ?? {};
      final weeklyScore = weeklyData['score'] ?? 0;
      final weeklyWeekOf = weeklyData['weekOf'] ?? '';
      final currentWeek = _currentWeekOf();

      // Yeni hafta başladıysa sıfırla, yoksa sadece rekor kırınca güncelle
      if (!weeklySnap.exists || weeklyWeekOf != currentWeek || score > weeklyScore) {
        tx.set(weeklyRef, {
          'displayName': displayName,
          'score': weeklyWeekOf != currentWeek ? score : (score > weeklyScore ? score : weeklyScore),
          'uid': uid,
          'weekOf': currentWeek,
        }, SetOptions(merge: false));
      }

      final allTimeSnap = await tx.get(allTimeRef);
      final allTimeScore = ((allTimeSnap.data() as Map?)?.cast<String, dynamic>() ?? {})['score'] ?? 0;

      if (!allTimeSnap.exists || score > allTimeScore) {
        tx.set(allTimeRef, {'displayName': displayName, 'score': score, 'uid': uid}, SetOptions(merge: true));
      }
    });
  }

  // ── Son oyunlar ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecentGames(String uid, {int limit = 10}) async {
    try {
      final snap = await _games
          .where('playerUid', isEqualTo: uid)
          .orderBy('playedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Liderlik tablosu ──────────────────────────────────────────────

  Future<List<LeaderboardEntry>> getWeeklyLeaderboard({int limit = 10}) =>
      _getLeaderboard('weekly', limit);

  Future<List<LeaderboardEntry>> getAllTimeLeaderboard({int limit = 10}) =>
      _getLeaderboard('allTime', limit);

  Future<List<LeaderboardEntry>> _getLeaderboard(String period, int limit) async {
    try {
      final col = _db.collection('leaderboard').doc(period).collection('entries');
      Query<Map<String, dynamic>> query = period == 'weekly'
          ? col.where('weekOf', isEqualTo: _currentWeekOf()).orderBy('score', descending: true).limit(limit)
          : col.orderBy('score', descending: true).limit(limit);

      final snap = await query.get();

      return snap.docs.asMap().entries
          .map((e) => LeaderboardEntry.fromDoc(e.value, e.key + 1))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Turnuva ───────────────────────────────────────────────────────

  Stream<QuerySnapshot> activeTournamentsStream() {
    return _tournaments
        .where('status', isEqualTo: 'waiting')
        .orderBy('startAt')
        .limit(5)
        .snapshots();
  }

  // Aktif turnuva yoksa haftalık yeni turnuva oluşturur
  Future<void> ensureWeeklyTournament() async {
    final snap = await _tournaments
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return;

    // Bir sonraki Pazartesi 20:00
    final now = DateTime.now();
    final daysUntilMonday = (8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7;
    final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday, 20, 0);

    await _tournaments.add({
      'status': 'waiting',
      'startAt': Timestamp.fromDate(nextMonday),
      'maxPlayers': 8,
      'players': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> joinTournament({
    required String tournamentId,
    required String uid,
    required String displayName,
  }) async {
    try {
      await _db.runTransaction((tx) async {
        final ref  = _tournaments.doc(tournamentId);
        final snap = await tx.get(ref);
        final data = snap.data() as Map<String, dynamic>;
        final players = List<Map>.from(data['players'] ?? []);
        final max     = data['maxPlayers'] ?? 8;

        if (players.length >= max) throw Exception('full');
        if (players.any((p) => p['uid'] == uid)) throw Exception('already_joined');

        players.add({'uid': uid, 'displayName': displayName, 'score': 0});
        tx.update(ref, {'players': players});
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
