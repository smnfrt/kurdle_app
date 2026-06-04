import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/logging_service.dart';
import 'package:kurdle_app/services/progression.dart' as progression;

// ISO 8601 hafta numarası: "2026-W17" formatında döner
// Hafta Pazartesi başlar; Perşembe hangi yılda düşüyorsa o yılın haftasıdır.
String _currentWeekOf() {
  final now = DateTime.now();
  // Haftanın Perşembesi (weekday: Mon=1 … Sun=7)
  final thursday = now
      .subtract(Duration(days: now.weekday - 1))
      .add(const Duration(days: 3));
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
  final int peyv;
  final GameStats stats;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.xp,
    required this.level,
    this.peyv = 0,
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
      peyv: d['peyv'] ?? 0,
      stats: GameStats.fromMap(d['stats'] ?? {}),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'xp': xp,
        'level': level,
        'peyv': peyv,
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
        played: m['played'] ?? 0,
        won: m['won'] ?? 0,
        highScore: m['highScore'] ?? 0,
        totalScore: m['totalScore'] ?? 0,
        streak: m['streak'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'played': played,
        'won': won,
        'highScore': highScore,
        'totalScore': totalScore,
        'streak': streak,
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

class ProgressionAward {
  final int oldLevel;
  final int newLevel;
  final bool awarded;

  const ProgressionAward({
    required this.oldLevel,
    required this.newLevel,
    this.awarded = true,
  });
}

// ── FirestoreService ──────────────────────────────────────────────

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');
  CollectionReference get _games => _db.collection('games');
  CollectionReference get _tournaments => _db.collection('tournaments');

  DocumentReference _weeklyLB(String uid) => _db
      .collection('leaderboard')
      .doc('weekly')
      .collection('entries')
      .doc(uid);
  DocumentReference _allTimeLB(String uid) => _db
      .collection('leaderboard')
      .doc('allTime')
      .collection('entries')
      .doc(uid);

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
        'peyv': 0,
        'stats': GameStats().toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      finalName = name;
    } else {
      final data = snap.data() as Map;
      final currentName = (data['displayName'] as String?)?.trim() ?? '';
      final uidSuffix = firebaseUser.uid.substring(firebaseUser.uid.length - 4);
      final isAutoGenerated = currentName == 'Misafir $uidSuffix' ||
          currentName == 'Mêvan $uidSuffix';
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
      if (!data.containsKey('peyv')) {
        update['peyv'] = 0;
      }
      if (update.isNotEmpty) await ref.update(update);
    }
    // Firebase Auth profilini de senkronize tut — currentUser.displayName her yerde aynı görünsün.
    if ((firebaseUser.displayName ?? '') != finalName) {
      try {
        await firebaseUser.updateDisplayName(finalName);
      } catch (e) {
        Log.warn('FirestoreService',
            'updateDisplayName auth profile sync failed', e);
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

  Future<List<UserProfile>> searchUsersByName(String query,
      {String? excludeUid}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final snap = await _users
          .where('displayNameLower', isGreaterThanOrEqualTo: q)
          .where('displayNameLower', isLessThan: '$q\uf8ff')
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

  // progression.dart'tan delege — tek source of truth
  static int levelForXp(int xp) => progression.levelForXp(xp);

  // ── Oyun bittikten sonra skor kaydet ─────────────────────────────

  Future<({int oldLevel, int newLevel, int xpGained, int peyvGained})>
      saveGameResult({
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

    // 2) İstatistikleri yaz (XP/Peyv awardProgression'a delegelenir)
    batch.update(_users.doc(uid), {
      'stats.played': FieldValue.increment(1),
      'stats.won': FieldValue.increment(won ? 1 : 0),
      'stats.totalScore': FieldValue.increment(playerScore),
    });

    await batch.commit();

    // 3) XP + Peyv ödülü (tek atomic transaction + level recalc)
    final xpGained = won ? 100 + playerScore ~/ 10 : 20 + playerScore ~/ 20;
    final peyvGained = won ? 10 + playerScore ~/ 30 : 2 + playerScore ~/ 60;
    final result = await awardProgression(
      uid: uid,
      xp: xpGained,
      peyv: peyvGained,
      reason: 'scrabble_${won ? 'win' : 'loss'}',
    );

    // 4) Yüksek skor ve liderlik tablosu — ayrı transaction gerektirir
    await _updateHighScoreAndLeaderboard(uid, playerScore);

    return (
      oldLevel: result.oldLevel,
      newLevel: result.newLevel,
      xpGained: xpGained,
      peyvGained: peyvGained,
    );
  }

  // ── Birleşik ilerleme ödülü (XP + Peyv + level recalc) ──────────
  //
  // Tüm progression kaynaklarının tek giriş noktası: scrabble win, wordle
  // solve, streak günü, multiplayer kazanma, achievement unlock.
  // Atomik transaction içinde xp/peyv increment edilir, gerekirse level
  // güncellenir. Önceki level + yeni level döner — UI level-up overlay'i
  // tetikleyebilir.
  Future<ProgressionAward> awardProgression({
    required String uid,
    required int xp,
    int peyv = 0,
    String? reason,
  }) async {
    if (xp <= 0 && peyv <= 0) {
      return const ProgressionAward(oldLevel: 1, newLevel: 1, awarded: false);
    }
    try {
      return await _db.runTransaction((tx) async {
        final ref = _users.doc(uid);
        final snap = await tx.get(ref);
        final data = (snap.data() as Map?)?.cast<String, dynamic>() ?? {};
        final oldXp = (data['xp'] as int? ?? 0);
        final oldLevel = (data['level'] as int? ?? 1);
        final newXp = oldXp + xp;
        final calculatedLevel = progression.levelForXp(newXp);
        final newLevel =
            calculatedLevel > oldLevel ? calculatedLevel : oldLevel;

        final updates = <String, dynamic>{
          if (xp > 0) 'xp': FieldValue.increment(xp),
          if (peyv > 0) 'peyv': FieldValue.increment(peyv),
          if (newLevel != oldLevel) 'level': newLevel,
        };
        if (updates.isNotEmpty) tx.update(ref, updates);
        return ProgressionAward(oldLevel: oldLevel, newLevel: newLevel);
      });
    } catch (e) {
      Log.warn(
          'FirestoreService', 'awardProgression failed (reason=$reason)', e);
      return const ProgressionAward(oldLevel: 1, newLevel: 1, awarded: false);
    }
  }

  Future<ProgressionAward> awardMultiplayerProgressionOnce({
    required String roomCode,
    required String uid,
    required int xp,
    required int peyv,
    String? reason,
  }) async {
    if (xp <= 0 && peyv <= 0) {
      return const ProgressionAward(oldLevel: 1, newLevel: 1, awarded: false);
    }
    try {
      return await _db.runTransaction((tx) async {
        final roomRef = _db.collection('rooms').doc(roomCode);
        final roomSnap = await tx.get(roomRef);
        final room = (roomSnap.data() as Map?)?.cast<String, dynamic>() ?? {};
        if (room['status'] != 'finished') {
          return const ProgressionAward(
              oldLevel: 1, newLevel: 1, awarded: false);
        }

        final rewarded =
            Map<String, dynamic>.from(room['rewardedUids'] as Map? ?? {});
        if (rewarded[uid] == true) {
          final userSnap = await tx.get(_users.doc(uid));
          final user = (userSnap.data() as Map?)?.cast<String, dynamic>() ?? {};
          final level = (user['level'] as int? ?? 1);
          return ProgressionAward(
              oldLevel: level, newLevel: level, awarded: false);
        }

        final userRef = _users.doc(uid);
        final userSnap = await tx.get(userRef);
        final data = (userSnap.data() as Map?)?.cast<String, dynamic>() ?? {};
        final oldXp = (data['xp'] as int? ?? 0);
        final oldLevel = (data['level'] as int? ?? 1);
        final newXp = oldXp + xp;
        final calculatedLevel = progression.levelForXp(newXp);
        final newLevel =
            calculatedLevel > oldLevel ? calculatedLevel : oldLevel;

        tx.update(roomRef, {
          'rewardedUids.$uid': true,
        });
        tx.update(userRef, {
          'xp': FieldValue.increment(xp),
          'peyv': FieldValue.increment(peyv),
          if (newLevel != oldLevel) 'level': newLevel,
        });

        return ProgressionAward(oldLevel: oldLevel, newLevel: newLevel);
      });
    } catch (e) {
      Log.warn('FirestoreService',
          'awardMultiplayerProgressionOnce failed (reason=$reason)', e);
      return const ProgressionAward(oldLevel: 1, newLevel: 1, awarded: false);
    }
  }

  // ── Sadece istatistik kaydet (XP/Peyv vermez) ───────────────────
  //
  // Wordle gibi oyunlar için: XP/Peyv recordResult içinde verilir,
  // burası users.stats.played/won/totalScore + highScore + leaderboard
  // günceller.
  Future<void> recordPlayStats({
    required String uid,
    required int playerScore,
    required bool won,
  }) async {
    try {
      await _users.doc(uid).update({
        'stats.played': FieldValue.increment(1),
        'stats.won': FieldValue.increment(won ? 1 : 0),
        if (playerScore > 0)
          'stats.totalScore': FieldValue.increment(playerScore),
      });
    } catch (e) {
      Log.warn('FirestoreService', 'recordPlayStats failed', e);
    }
    // Skor 0 ise leaderboard/highScore'a yazma — Wordle gibi skorsuz
    // oyunlar dummy 0 girişi oluşturmasın.
    if (playerScore > 0) {
      await _updateHighScoreAndLeaderboard(uid, playerScore);
    }
  }

  // ── Peyv harca (mağaza item satın alma) ─────────────────────────
  //
  // Atomik: yeterli peyv yoksa false döner, varsa decrement edilir.
  Future<bool> spendPeyv({
    required String uid,
    required int amount,
    String? reason,
  }) async {
    if (amount <= 0) return false;
    try {
      return await _db.runTransaction((tx) async {
        final ref = _users.doc(uid);
        final snap = await tx.get(ref);
        final data = (snap.data() as Map?)?.cast<String, dynamic>() ?? {};
        final current = (data['peyv'] as int? ?? 0);
        if (current < amount) return false;
        tx.update(ref, {'peyv': FieldValue.increment(-amount)});
        return true;
      });
    } catch (e) {
      Log.warn('FirestoreService', 'spendPeyv failed (reason=$reason)', e);
      return false;
    }
  }

  Future<void> _updateHighScoreAndLeaderboard(String uid, int score) async {
    await _db.runTransaction((tx) async {
      final userRef = _users.doc(uid);
      final snap = await tx.get(userRef);
      final current = (snap.data() as Map?)?.cast<String, dynamic>() ?? {};
      final currentHigh = current['stats']?['highScore'] ?? 0;

      if (score > currentHigh) {
        tx.update(userRef, {'stats.highScore': score});
      }

      // Haftalık ve tüm zamanlar liderlik tablosu
      final weeklyRef = _weeklyLB(uid);
      final allTimeRef = _allTimeLB(uid);
      final displayName = current['displayName'] ?? 'Oyuncu';

      final weeklySnap = await tx.get(weeklyRef);
      final weeklyData =
          (weeklySnap.data() as Map?)?.cast<String, dynamic>() ?? {};
      final weeklyScore = weeklyData['score'] ?? 0;
      final weeklyWeekOf = weeklyData['weekOf'] ?? '';
      final currentWeek = _currentWeekOf();

      // Yeni hafta başladıysa sıfırla, yoksa sadece rekor kırınca güncelle
      if (!weeklySnap.exists ||
          weeklyWeekOf != currentWeek ||
          score > weeklyScore) {
        tx.set(
            weeklyRef,
            {
              'displayName': displayName,
              'score': weeklyWeekOf != currentWeek
                  ? score
                  : (score > weeklyScore ? score : weeklyScore),
              'uid': uid,
              'weekOf': currentWeek,
            },
            SetOptions(merge: false));
      }

      final allTimeSnap = await tx.get(allTimeRef);
      final allTimeScore =
          ((allTimeSnap.data() as Map?)?.cast<String, dynamic>() ??
                  {})['score'] ??
              0;

      if (!allTimeSnap.exists || score > allTimeScore) {
        tx.set(
            allTimeRef,
            {'displayName': displayName, 'score': score, 'uid': uid},
            SetOptions(merge: true));
      }
    });
  }

  // ── Son oyunlar ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecentGames(String uid,
      {int limit = 10}) async {
    try {
      final snap = await _games
          .where('playerUid', isEqualTo: uid)
          .orderBy('playedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
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

  Future<List<LeaderboardEntry>> _getLeaderboard(
      String period, int limit) async {
    try {
      final col =
          _db.collection('leaderboard').doc(period).collection('entries');
      Query<Map<String, dynamic>> query = period == 'weekly'
          ? col
              .where('weekOf', isEqualTo: _currentWeekOf())
              .orderBy('score', descending: true)
              .limit(limit)
          : col.orderBy('score', descending: true).limit(limit);

      final snap = await query.get();

      return snap.docs
          .asMap()
          .entries
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
    final snap =
        await _tournaments.where('status', isEqualTo: 'waiting').limit(1).get();
    if (snap.docs.isNotEmpty) return;

    // Bir sonraki Pazartesi 20:00
    final now = DateTime.now();
    final daysUntilMonday =
        (8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7;
    final nextMonday =
        DateTime(now.year, now.month, now.day + daysUntilMonday, 20, 0);

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
        final ref = _tournaments.doc(tournamentId);
        final snap = await tx.get(ref);
        final data = snap.data() as Map<String, dynamic>;
        final players = List<Map>.from(data['players'] ?? []);
        final max = data['maxPlayers'] ?? 8;

        if (players.length >= max) throw Exception('full');
        if (players.any((p) => p['uid'] == uid)) {
          throw Exception('already_joined');
        }

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
      final ref = _tournaments.doc(tournamentId);
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;

      if (data['status'] != 'waiting') return; // zaten başlamış

      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      if (players.length < 2) throw Exception('not_enough_players');

      // Kalan slotları bot ile doldur (8'e tamamlar)
      var idx = players.length;
      while (players.length < (data['maxPlayers'] ?? 8)) {
        players.add({
          'uid': 'bot_$idx',
          'displayName': 'Bot ${idx + 1}',
          'score': 0,
          'isBot': true
        });
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
      final ref = _tournaments.doc(tournamentId);
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;

      final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);
      final mIdx = matches.indexWhere((m) => m['id'] == matchId);
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
      final roundMatches =
          matches.where((m) => m['round'] == currentRound).toList();
      final allDone = roundMatches.every((m) => m['status'] == 'finished');

      if (!allDone) {
        tx.update(ref, {'matches': matches});
        return;
      }

      // Sonraki tur veya turnuva finali
      final winners = roundMatches.map((m) => m['winner'] as String).toList();

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
      return matches
          .where(
            (m) =>
                m['round'] == currentRound &&
                m['status'] == 'active' &&
                (m['p1'] == uid || m['p2'] == uid),
          )
          .firstOrNull;
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
      final finalist = matches
          .where((m) => m['round'] == 3 || (m['round'] == _maxRound(matches)))
          .toList();
      if (finalist.isEmpty) return;
      final finalMatch = finalist.last;
      final winner = finalMatch['winner'] as String?;
      final runnerUp = winner == finalMatch['p1']
          ? finalMatch['p2'] as String?
          : finalMatch['p1'] as String?;

      // 3. sıra: semi-final kaybedenlerinden yüksek skorlu olanı
      final semiMatches =
          matches.where((m) => m['round'] == _maxRound(matches) - 1).toList();
      final semiLosers = semiMatches
          .map((m) => (
                uid: m['winner'] == m['p1']
                    ? m['p2'] as String
                    : m['p1'] as String,
                score: m['winner'] == m['p1']
                    ? (m['p2Score'] as int? ?? 0)
                    : (m['p1Score'] as int? ?? 0)
              ))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      final third = semiLosers.isNotEmpty ? semiLosers.first.uid : null;

      // Turnuva ödülleri: XP + Peyv (XP'nin %10'u)
      final prizes = <String, ({int xp, int peyv})>{
        if (winner != null && !winner.startsWith('bot_'))
          winner: (xp: 5000, peyv: 500),
        if (runnerUp != null && !runnerUp.startsWith('bot_'))
          runnerUp: (xp: 2500, peyv: 250),
        if (third != null && !third.startsWith('bot_'))
          third: (xp: 1000, peyv: 100),
      };

      // İdempotent flag'i set et
      await _tournaments.doc(tournamentId).update({
        'prizesAwarded': true,
        'prizes': {
          for (final e in prizes.entries) e.key: e.value.xp,
        },
      });

      // Her oyuncuya ayrı atomic transaction (xp + peyv + level recalc)
      for (final entry in prizes.entries) {
        await awardProgression(
          uid: entry.key,
          xp: entry.value.xp,
          peyv: entry.value.peyv,
          reason: 'tournament_$tournamentId',
        );
      }
    } catch (e) {
      Log.error('FirestoreService', '_awardTournamentPrizes failed', e);
    }
  }

  int _maxRound(List<Map<String, dynamic>> matches) {
    return matches.fold<int>(1,
        (max, m) => (m['round'] as int? ?? 1) > max ? m['round'] as int : max);
  }
}
