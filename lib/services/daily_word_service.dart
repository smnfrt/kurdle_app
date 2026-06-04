import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/logging_service.dart';
import 'package:kurdle_app/services/progression.dart' as progression;

class DailyWordService {
  DailyWordService._();
  static final DailyWordService instance = DailyWordService._();

  final _db = FirebaseFirestore.instance;

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference _dayRef(String key) =>
      _db.collection('dailyWords').doc(key);

  DocumentReference _statsRef(String key) =>
      _db.collection('dailyStats').doc(key);

  DocumentReference<Map<String, dynamic>> _wordPlayRef(
          String uid, String key) =>
      _db.collection('users').doc(uid).collection('dailyWordPlays').doc(key);

  DocumentReference<Map<String, dynamic>> _challengePlayRef(
          String uid, String key) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('dailyChallengePlays')
          .doc(key);

  // Firestore'da bugün için özel kelime varsa onu döner, yoksa null
  Future<String?> fetchAdminWord() async {
    if (!FirebaseService.isAvailable) return null;
    try {
      final snap = await _dayRef(_todayKey()).get();
      if (!snap.exists) return null;
      return (snap.data() as Map<String, dynamic>?)?['word'] as String?;
    } catch (e) {
      Log.warn('DailyWordService', 'fetchAdminWord failed', e);
      return null;
    }
  }

  // Kullanıcı bugün oynadı mı? (çok cihaz desteği)
  Future<bool> hasPlayedToday() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return false;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('dailyWordPlays')
          .doc(_todayKey())
          .get();
      return snap.exists;
    } catch (e) {
      Log.warn('DailyWordService', 'hasPlayedToday check failed', e);
      return false;
    }
  }

  Future<bool> hasPlayedChallengeToday() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return false;
    try {
      final snap = await _challengePlayRef(uid, _todayKey()).get();
      return snap.exists;
    } catch (e) {
      Log.warn('DailyWordService', 'hasPlayedChallengeToday check failed', e);
      return false;
    }
  }

  // Oyun bitince çağır: kullanıcı kaydı + global istatistik + XP/Peyv ödülü
  Future<({int xpGained, int peyvGained, int oldLevel, int newLevel})>
      recordResult({
    required bool won,
    required int tries,
    required String shareText,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (!FirebaseService.isAvailable) {
      return (xpGained: 0, peyvGained: 0, oldLevel: 1, newLevel: 1);
    }

    if (uid == null) {
      await _recordAnonymousWordStats(won: won, tries: tries);
      return (xpGained: 0, peyvGained: 0, oldLevel: 1, newLevel: 1);
    }

    final key = _todayKey();
    final remaining = (7 - tries).clamp(0, 6);
    final xp = won ? 50 + remaining * 20 : 10;
    final peyv = won ? 5 + remaining * 2 : 0;
    try {
      return await _db.runTransaction((tx) async {
        final playRef = _wordPlayRef(uid, key);
        final playSnap = await tx.get(playRef);
        final userRef = _db.collection('users').doc(uid);
        final userSnap = await tx.get(userRef);
        final user = (userSnap.data() as Map?)?.cast<String, dynamic>() ?? {};
        final oldXp = user['xp'] as int? ?? 0;
        final oldLevel = user['level'] as int? ?? 1;

        if (playSnap.exists) {
          return (
            xpGained: 0,
            peyvGained: 0,
            oldLevel: oldLevel,
            newLevel: oldLevel,
          );
        }

        final newXp = oldXp + xp;
        final calculatedLevel = progression.levelForXp(newXp);
        final newLevel =
            calculatedLevel > oldLevel ? calculatedLevel : oldLevel;

        tx.set(playRef, {
          'played': true,
          'won': won,
          'tries': tries,
          'shareText': shareText,
          'playedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
            _statsRef(key),
            {
              'totalPlayed': FieldValue.increment(1),
              'totalWon': FieldValue.increment(won ? 1 : 0),
              'tries.$tries': FieldValue.increment(1),
              'date': key,
            },
            SetOptions(merge: true));
        tx.update(userRef, {
          'xp': FieldValue.increment(xp),
          if (peyv > 0) 'peyv': FieldValue.increment(peyv),
          if (newLevel != oldLevel) 'level': newLevel,
        });

        return (
          xpGained: xp,
          peyvGained: peyv,
          oldLevel: oldLevel,
          newLevel: newLevel,
        );
      });
    } catch (e) {
      Log.warn('DailyWordService', 'recordResult transaction failed', e);
      return (xpGained: 0, peyvGained: 0, oldLevel: 1, newLevel: 1);
    }
  }

  // Lokal oturum bayrağı (Firebase olmasa da replay engeller)
  bool _playedTodayLocal = false;
  void markPlayedLocally() => _playedTodayLocal = true;
  bool get hasPlayedTodayLocal => _playedTodayLocal;

  // Challenge sonucunu kaydet + XP/Peyv ödülü
  Future<({int xpGained, int peyvGained, int oldLevel, int newLevel})>
      recordChallengeResult({
    required int stagesCompleted,
    required int totalScore,
    required bool perfectRun,
  }) async {
    markPlayedLocally();
    final uid = AuthService.instance.currentUser?.uid;
    if (!FirebaseService.isAvailable) {
      return (xpGained: 0, peyvGained: 0, oldLevel: 1, newLevel: 1);
    }

    if (uid == null) {
      await _recordAnonymousChallengeStats(perfectRun: perfectRun);
      return (xpGained: 0, peyvGained: 0, oldLevel: 1, newLevel: 1);
    }

    final key = _todayKey();
    final xp = stagesCompleted * 30 + (perfectRun ? 100 : 0);
    final peyv = stagesCompleted * 5 + (perfectRun ? 15 : 0);
    try {
      return await _db.runTransaction((tx) async {
        final playRef = _challengePlayRef(uid, key);
        final playSnap = await tx.get(playRef);
        final userRef = _db.collection('users').doc(uid);
        final userSnap = await tx.get(userRef);
        final user = (userSnap.data() as Map?)?.cast<String, dynamic>() ?? {};
        final oldXp = user['xp'] as int? ?? 0;
        final oldLevel = user['level'] as int? ?? 1;

        if (playSnap.exists) {
          return (
            xpGained: 0,
            peyvGained: 0,
            oldLevel: oldLevel,
            newLevel: oldLevel,
          );
        }

        final newXp = oldXp + xp;
        final calculatedLevel = progression.levelForXp(newXp);
        final newLevel =
            calculatedLevel > oldLevel ? calculatedLevel : oldLevel;

        tx.set(playRef, {
          'played': true,
          'challengeScore': totalScore,
          'stagesCompleted': stagesCompleted,
          'perfectRun': perfectRun,
          'playedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
            _statsRef(key),
            {
              'challengePlays': FieldValue.increment(1),
              'perfectRuns': FieldValue.increment(perfectRun ? 1 : 0),
              'date': key,
            },
            SetOptions(merge: true));
        tx.update(userRef, {
          'xp': FieldValue.increment(xp),
          if (peyv > 0) 'peyv': FieldValue.increment(peyv),
          if (newLevel != oldLevel) 'level': newLevel,
        });

        return (
          xpGained: xp,
          peyvGained: peyv,
          oldLevel: oldLevel,
          newLevel: newLevel,
        );
      });
    } catch (e) {
      Log.warn(
          'DailyWordService', 'recordChallengeResult transaction failed', e);
      return (xpGained: 0, peyvGained: 0, oldLevel: 1, newLevel: 1);
    }
  }

  Future<void> _recordAnonymousWordStats({
    required bool won,
    required int tries,
  }) async {
    try {
      await _statsRef(_todayKey()).set({
        'totalPlayed': FieldValue.increment(1),
        'totalWon': FieldValue.increment(won ? 1 : 0),
        'tries.$tries': FieldValue.increment(1),
        'date': _todayKey(),
      }, SetOptions(merge: true));
    } catch (e) {
      Log.warn('DailyWordService', 'anonymous word stats failed', e);
    }
  }

  Future<void> _recordAnonymousChallengeStats(
      {required bool perfectRun}) async {
    try {
      await _statsRef(_todayKey()).set({
        'challengePlays': FieldValue.increment(1),
        'perfectRuns': FieldValue.increment(perfectRun ? 1 : 0),
        'date': _todayKey(),
      }, SetOptions(merge: true));
    } catch (e) {
      Log.warn('DailyWordService', 'anonymous challenge stats failed', e);
    }
  }

  // Global istatistik: bugün kaç kişi oynadı, kazanma oranı
  Future<({int totalPlayed, int totalWon, Map<int, int> distribution})?>
      fetchTodayStats() async {
    if (!FirebaseService.isAvailable) return null;
    try {
      final snap = await _statsRef(_todayKey()).get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      final totalPlayed = data['totalPlayed'] as int? ?? 0;
      final totalWon = data['totalWon'] as int? ?? 0;
      final triesMap = (data['tries'] as Map<String, dynamic>? ?? {});
      final dist = <int, int>{};
      for (final e in triesMap.entries) {
        final k = int.tryParse(e.key.toString());
        if (k != null) dist[k] = (e.value as int? ?? 0);
      }
      return (totalPlayed: totalPlayed, totalWon: totalWon, distribution: dist);
    } catch (e) {
      Log.warn('DailyWordService', 'fetchTodayStats failed', e);
      return null;
    }
  }

  Future<({int challengePlays, int perfectRuns})?> fetchChallengeStats() async {
    if (!FirebaseService.isAvailable) return null;
    try {
      final snap = await _statsRef(_todayKey()).get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      return (
        challengePlays: data['challengePlays'] as int? ?? 0,
        perfectRuns: data['perfectRuns'] as int? ?? 0,
      );
    } catch (e) {
      Log.warn('DailyWordService', 'fetchChallengeStats failed', e);
      return null;
    }
  }
}
