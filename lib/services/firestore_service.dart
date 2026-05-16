import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/logging_service.dart';

// ISO 8601 hafta numarası: "2026-W17" formatında döner
// Hafta Pazartesi başlar; Perşembe hangi yılda düşüyorsa o yılın haftasıdır.
String _currentWeekOf() {
  final now = DateTime.now();
  // Haftanın Perşembesi (weekday: Mon=1 … Sun=7)
  final thursday = now.subtract(Duration(days: now.weekday - 1)).add(const Duration(days: 3));
  // 4 Ocak her zaman hafta-1 içindedir
  final week1Start = DateTime(thursday.year, 1, 4);
  final weekNum = 1 + thursday.difference(week1Start).inDays ~/ 7;
  return '${thursday.year}-W${weekNum.toString().padLeft(2, '0')}';
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
    final existing = firebaseUser.displayName?.trim() ?? '';
    final uidSuffix = firebaseUser.uid.substring(firebaseUser.uid.length - 4);
    final isExistingAuto =
        existing == 'Misafir $uidSuffix' || existing == 'Mêvan $uidSuffix';
    // Otomatik üretilen ad varsa locale değişikliklerine göre yenile.
    final name = (existing.isNotEmpty && !isExistingAuto)
        ? existing
        : L.guestName(uidSuffix);
    String? finalName;
    if (!snap.exists) {
      await ref.set({
        'displayName': name,
        'displayNameLower': name.toLowerCase(),
        'email': firebaseUser.email ?? '',
        'xp': 0,
        'level': 1,
        'stats': GameStats().toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      finalName = name;
    } else {
      final data = snap.data() as Map;
      final currentName = (data['displayName'] as String?)?.trim() ?? '';
      final uidSuffix = firebaseUser.uid.substring(firebaseUser.uid.length - 4);
      final isAutoGenerated =
          currentName == 'Misafir $uidSuffix' || currentName == 'Mêvan $uidSuffix';
      final update = <String, dynamic>{};
      if (currentName.isEmpty || currentName == 'Oyuncu' || isAutoGenerated) {
        update['displayName'] = name;
        update['displayNameLower'] = name.toLowerCase();
        finalName = name;
      } else {
        finalName = currentName;
        if (!data.containsKey('displayNameLower')) {
          update['displayNameLower'] = currentName.toLowerCase();
        }
      }
      if (update.isNotEmpty) await ref.update(update);
    }
    // Firebase Auth profilini de senkronize tut — currentUser.displayName her yerde aynı görünsün.
    if (finalName != null && (firebaseUser.displayName ?? '') != finalName) {
      try {
        await firebaseUser.updateDisplayName(finalName);
      } catch (e) {
        Log.warn('FirestoreService', 'updateDisplayName auth profile sync failed', e);
      }
    }
  }

  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    } catch (e) {
      Log.warn('FirestoreService', 'getProfile failed', e);
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
      _users.doc(uid).update({
        'displayName': name,
        'displayNameLower': name.toLowerCase(),
      });

  Future<List<UserProfile>> searchUsersByName(String query, {String? excludeUid}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final snap = await _users
          .where('displayNameLower', isGreaterThanOrEqualTo: q)
          .where('displayNameLower', isLessThan: q + '\uf8ff')
          .limit(12)
          .get();
      return snap.docs
          .map((d) => UserProfile.fromDoc(d))
          .where((p) => p.uid != excludeUid)
          .toList();
    } catch (e) {
      Log.warn('FirestoreService', 'searchUsersByName failed', e);
      return [];
    }
  }

  // XP eşiğine göre level hesaplar: 1→2=200xp, her level +100xp daha fazla
  static int levelForXp(int xp) {
    var level = 1;
    var threshold = 200;
    var remaining = xp;
    while (remaining >= threshold) {
      remaining -= threshold;
      level++;
      threshold += 100;
    }
    return level;
  }

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

    // 2) Kullanıcı istatistikleri
    final xpGained = won ? 100 + playerScore ~/ 10 : 20 + playerScore ~/ 20;

    batch.update(_users.doc(uid), {
      'xp': FieldValue.increment(xpGained),
      'stats.played':     FieldValue.increment(1),
      'stats.won':        FieldValue.increment(won ? 1 : 0),
      'stats.totalScore': FieldValue.increment(playerScore),
    });

    await batch.commit();

    // 3) Level güncelle — mevcut XP'yi okuyup yeniden hesapla
    await _updateLevel(uid, xpGained);

    // 4) Yüksek skor ve liderlik tablosu — ayrı transaction gerektirir
    await _updateHighScoreAndLeaderboard(uid, playerScore);
  }

  Future<void> _updateLevel(String uid, int xpGained) async {
    await _db.runTransaction((tx) async {
      final ref  = _users.doc(uid);
      final snap = await tx.get(ref);
      final data = (snap.data() as Map?)?.cast<String, dynamic>() ?? {};
      final newXp    = (data['xp'] as int? ?? 0);
      final newLevel = levelForXp(newXp);
      if (newLevel != (data['level'] as int? ?? 1)) {
        tx.update(ref, {'level': newLevel});
      }
    });
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
    } catch (e) {
      Log.warn('FirestoreService', 'getRecentGames failed', e);
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
    } catch (e) {
      Log.warn('FirestoreService', '_getLeaderboard failed', e);
      return [];
    }
  }

  // ── Turnuva ───────────────────────────────────────────────────────

  // 'waiting' ve 'active' turnuvaları döner (kullanıcı hem lobide hem oyun sırasında izleyebilir)
  Stream<QuerySnapshot> activeTournamentsStream() {
    return _tournaments
        .where('status', whereIn: ['waiting', 'active'])
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

  // Turnuva dolduğunda veya startAt geçtiğinde çağrılır.
  // Tur-1 maçlarını oluşturur ve status → 'active' yapar.
  Future<void> startTournament(String tournamentId) async {
    await _db.runTransaction((tx) async {
      final ref  = _tournaments.doc(tournamentId);
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;

      if (data['status'] != 'waiting') return; // zaten başlamış

      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      if (players.length < 2) throw Exception('not_enough_players');

      // Kalan slotları bot ile doldur (8'e tamamlar)
      var idx = players.length;
      while (players.length < (data['maxPlayers'] ?? 8)) {
        players.add({'uid': 'bot_$idx', 'displayName': 'Bot ${idx + 1}', 'score': 0, 'isBot': true});
        idx++;
      }

      // Tur-1: ardışık çiftler (0-1, 2-3, 4-5, 6-7)
      final matches = <Map<String, dynamic>>[];
      for (var i = 0; i < players.length; i += 2) {
        matches.add({
          'id': 'r1m${i ~/ 2}',
          'round': 1,
          'p1': players[i]['uid'],
          'p2': players[i + 1]['uid'],
          'p1Score': null,
          'p2Score': null,
          'winner': null,
          'status': 'active',
        });
      }

      tx.update(ref, {
        'status': 'active',
        'players': players,
        'matches': matches,
        'currentRound': 1,
        'startedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Oyuncu maç skorunu gönderir. Her iki oyuncu da gönderince maç biter.
  // Tüm tur maçları bitince sonraki tur oluşturulur; final bitince turnuva kapanır.
  Future<void> submitMatchScore({
    required String tournamentId,
    required String matchId,
    required String uid,
    required int score,
  }) async {
    await _db.runTransaction((tx) async {
      final ref  = _tournaments.doc(tournamentId);
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;

      final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);
      final mIdx    = matches.indexWhere((m) => m['id'] == matchId);
      if (mIdx < 0) throw Exception('match_not_found');

      final match = Map<String, dynamic>.from(matches[mIdx]);
      if (match['status'] == 'finished') return;

      // Skoru kaydet
      if (match['p1'] == uid) {
        match['p1Score'] = score;
      } else if (match['p2'] == uid) {
        match['p2Score'] = score;
      }

      // Her iki skor da geldiyse kazananı belirle
      final p1Score = match['p1Score'] as int?;
      final p2Score = match['p2Score'] as int?;

      if (p1Score != null && p2Score != null) {
        match['winner'] = p1Score >= p2Score ? match['p1'] : match['p2'];
        match['status'] = 'finished';
      }

      matches[mIdx] = match;

      // Tüm tur maçları bitti mi?
      final currentRound = data['currentRound'] as int? ?? 1;
      final roundMatches = matches.where((m) => m['round'] == currentRound).toList();
      final allDone = roundMatches.every((m) => m['status'] == 'finished');

      if (!allDone) {
        tx.update(ref, {'matches': matches});
        return;
      }

      // Sonraki tur veya turnuva finali
      final winners = roundMatches.map((m) => m['winner'] as String).toList();
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

      if (winners.length == 1) {
        // Final bitti — turnuvayı kapat ve XP ver
        tx.update(ref, {
          'matches': matches,
          'status': 'finished',
          'winnerId': winners.first,
          'finishedAt': FieldValue.serverTimestamp(),
        });
        // XP ödülleri sonraki adımda (transaction dışında) verilir
        return;
      }

      // Sonraki tur eşleşmelerini oluştur
      final nextRound = currentRound + 1;
      for (var i = 0; i < winners.length; i += 2) {
        matches.add({
          'id': 'r${nextRound}m${i ~/ 2}',
          'round': nextRound,
          'p1': winners[i],
          'p2': i + 1 < winners.length ? winners[i + 1] : winners[i], // bye
          'p1Score': null,
          'p2Score': null,
          'winner': null,
          'status': 'active',
        });
      }

      tx.update(ref, {
        'matches': matches,
        'currentRound': nextRound,
      });
    });

    // Turnuva bittiyse XP ödüllerini dağıt
    await _awardTournamentPrizes(tournamentId);
  }

  // Kullanıcının mevcut aktif maçını döner (null ise maçı yok)
  Future<Map<String, dynamic>?> getActiveMatch({
    required String tournamentId,
    required String uid,
  }) async {
    try {
      final snap = await _tournaments.doc(tournamentId).get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      final currentRound = data['currentRound'] as int? ?? 1;
      final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);
      return matches.where((m) =>
        m['round'] == currentRound &&
        m['status'] == 'active' &&
        (m['p1'] == uid || m['p2'] == uid),
      ).firstOrNull;
    } catch (e) {
      Log.warn('FirestoreService', 'getActiveTournamentMatch failed', e);
      return null;
    }
  }

  Future<void> _awardTournamentPrizes(String tournamentId) async {
    try {
      final snap = await _tournaments.doc(tournamentId).get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] != 'finished') return;
      if (data['prizesAwarded'] == true) return;

      final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);

      // Kazanan: final maçının winnerId
      final finalist = matches.where((m) => m['round'] == 3 || (m['round'] == _maxRound(matches))).toList();
      if (finalist.isEmpty) return;
      final finalMatch = finalist.last;
      final winner  = finalMatch['winner'] as String?;
      final runnerUp = winner == finalMatch['p1'] ? finalMatch['p2'] as String? : finalMatch['p1'] as String?;

      // 3. sıra: semi-final kaybedenlerinden yüksek skorlu olanı
      final semiMatches = matches.where((m) => m['round'] == _maxRound(matches) - 1).toList();
      final semiLosers = semiMatches
          .map((m) => (uid: m['winner'] == m['p1'] ? m['p2'] as String : m['p1'] as String,
                        score: m['winner'] == m['p1'] ? (m['p2Score'] as int? ?? 0) : (m['p1Score'] as int? ?? 0)))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      final third = semiLosers.isNotEmpty ? semiLosers.first.uid : null;

      final prizes = {
        if (winner != null && !winner.startsWith('bot_'))   winner:   5000,
        if (runnerUp != null && !runnerUp.startsWith('bot_')) runnerUp: 2500,
        if (third != null && !third.startsWith('bot_'))    third:    1000,
      };

      final batch = _db.batch();
      for (final entry in prizes.entries) {
        batch.update(_users.doc(entry.key), {'xp': FieldValue.increment(entry.value)});
      }
      batch.update(_tournaments.doc(tournamentId), {'prizesAwarded': true, 'prizes': prizes});
      await batch.commit();

      // Level güncellemesi XP değişince tetiklenmeli
      for (final uid in prizes.keys) {
        await _updateLevel(uid, prizes[uid]!);
      }
    } catch (e) {
      Log.error('FirestoreService', '_awardTournamentPrizes failed', e);
    }
  }

  int _maxRound(List<Map<String, dynamic>> matches) {
    return matches.fold<int>(1, (max, m) => (m['round'] as int? ?? 1) > max ? m['round'] as int : max);
  }
}
