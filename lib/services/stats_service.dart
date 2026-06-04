import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/daily_word_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:path_provider/path_provider.dart';

class StatsService {
  Future<String> _readAsset(String fileName) async {
    WidgetsFlutterBinding.ensureInitialized();
    return await rootBundle.loadString(fileName);
  }

  Future<Stats> loadStats() async {
    final directory = await getApplicationDocumentsDirectory();
    final exists = await File("${directory.path}/stats.json").exists();
    final jsonString = exists
        ? await File("${directory.path}/stats.json").readAsString()
        : await _readAsset('assets/stats.json');

    final map = json.decode(jsonString);
    return Stats.fromJson(map);
  }

  /// Son hamle sonucunda kazanılan ödüller (UI level-up overlay için).
  /// `updateStats` çağrısı tamamlandığında set olur.
  final ValueNotifier<({int oldLevel, int newLevel, int xpGained, int peyvGained})?>
      lastReward = ValueNotifier(null);

  Future<Stats> updateStats(
      Stats stats, bool won, int index, String Function(int n) getSharable, int gameNumber,
      {String word = ''}) async {
    if (won) {
      stats.guessDistribution[index] += 1;
      stats.lastGuess = index + 1;
      stats.won += 1;
      stats.streak.current += 1;
      if (stats.streak.current > stats.streak.max) {
        stats.streak.max = stats.streak.current;
      }
    } else {
      stats.lost += 1;
      stats.streak.current = 0;
      stats.lastGuess = -1;
    }
    // Eski "puan" sistemi kaldırıldı; XP/Peyv tek source of truth.
    // totalScore alanı geriye dönük uyumluluk için saklanıyor ama
    // artık güncellenmez.
    stats.lastBoard = getSharable(index);
    stats.gameNumber = gameNumber;

    await saveStats(stats);
    _syncToFirestore(stats, won);
    // Wordle XP/Peyv ödülünü al ve UI'ya yayın
    DailyWordService.instance
        .recordResult(
      won: won,
      tries: index + 1,
      shareText: getSharable(index),
    )
        .then((reward) {
      if (reward.xpGained > 0 || reward.peyvGained > 0) {
        lastReward.value = reward;
      }
    });
    return stats;
  }

  void _syncToFirestore(Stats stats, bool won) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    // XP/Peyv ödülü DailyWordService.recordResult içinde verilir.
    // Wordle "skor" konsepti kaldırıldı; sadece played/won güncelle.
    FirestoreService.instance.recordPlayStats(
      uid: uid,
      playerScore: 0,
      won: won,
    );
  }

  Future<void> saveStats(Stats stats) async {
    final directory = await getApplicationDocumentsDirectory();
    await File("${directory.path}/stats.json").writeAsString(json.encode(stats.toJson()));
  }
}
