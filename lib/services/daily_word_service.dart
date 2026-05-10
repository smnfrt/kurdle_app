import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';

class DailyWordService {
  DailyWordService._();
  static final DailyWordService instance = DailyWordService._();

  final _db = FirebaseFirestore.instance;

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference _dayRef(String key) => _db.collection('dailyWords').doc(key);

  // Firestore'da bugün için özel kelime varsa onu döner, yoksa null
  Future<String?> fetchAdminWord() async {
    if (!FirebaseService.isAvailable) return null;
    try {
      final snap = await _dayRef(_todayKey()).get();
      if (!snap.exists) return null;
      return (snap.data() as Map<String, dynamic>?)?['word'] as String?;
    } catch (_) {
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
          .collection('dailyPlays')
          .doc(_todayKey())
          .get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  // Oyun bitince çağır: kullanıcı kaydı + global istatistik
  Future<void> recordResult({
    required bool won,
    required int tries,
    required String shareText,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (!FirebaseService.isAvailable) return;

    final key = _todayKey();
    final batch = _db.batch();

    // Kullanıcı günlük kaydı
    if (uid != null) {
      final userDayRef = _db
          .collection('users')
          .doc(uid)
          .collection('dailyPlays')
          .doc(key);
      batch.set(userDayRef, {
        'played': true,
        'won': won,
        'tries': tries,
        'shareText': shareText,
        'playedAt': FieldValue.serverTimestamp(),
      });
    }

    // Global günlük istatistik
    final dayRef = _dayRef(key);
    batch.set(dayRef, {
      'totalPlayed': FieldValue.increment(1),
      'totalWon':    FieldValue.increment(won ? 1 : 0),
      'tries.$tries': FieldValue.increment(1),
      'date': key,
    }, SetOptions(merge: true));

    try {
      await batch.commit();
    } catch (_) {}
  }

  // Lokal oturum bayrağı (Firebase olmasa da replay engeller)
  bool _playedTodayLocal = false;
  void markPlayedLocally() => _playedTodayLocal = true;
  bool get hasPlayedTodayLocal => _playedTodayLocal;

  // Challenge sonucunu kaydet
  Future<void> recordChallengeResult({
    required int stagesCompleted,
    required int totalScore,
    required bool perfectRun,
  }) async {
    markPlayedLocally();
    final uid = AuthService.instance.currentUser?.uid;
    if (!FirebaseService.isAvailable) return;

    final key = _todayKey();
    final batch = _db.batch();

    if (uid != null) {
      final userDayRef = _db
          .collection('users')
          .doc(uid)
          .collection('dailyPlays')
          .doc(key);
      batch.set(userDayRef, {
        'played': true,
        'challengeScore': totalScore,
        'stagesCompleted': stagesCompleted,
        'perfectRun': perfectRun,
        'playedAt': FieldValue.serverTimestamp(),
      });
    }

    final dayRef = _dayRef(key);
    batch.set(dayRef, {
      'challengePlays': FieldValue.increment(1),
      'perfectRuns': FieldValue.increment(perfectRun ? 1 : 0),
      'date': key,
    }, SetOptions(merge: true));

    try {
      await batch.commit();
    } catch (_) {}
  }

  // Global istatistik: bugün kaç kişi oynadı, kazanma oranı
  Future<({int totalPlayed, int totalWon, Map<int, int> distribution})?>
      fetchTodayStats() async {
    if (!FirebaseService.isAvailable) return null;
    try {
      final snap = await _dayRef(_todayKey()).get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      final totalPlayed = data['totalPlayed'] as int? ?? 0;
      final totalWon    = data['totalWon']    as int? ?? 0;
      final triesMap    = (data['tries'] as Map<String, dynamic>? ?? {});
      final dist = <int, int>{};
      for (final e in triesMap.entries) {
        final k = int.tryParse(e.key.toString());
        if (k != null) dist[k] = (e.value as int? ?? 0);
      }
      return (totalPlayed: totalPlayed, totalWon: totalWon, distribution: dist);
    } catch (_) {
      return null;
    }
  }
}
