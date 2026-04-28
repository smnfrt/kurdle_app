import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/daily_word_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/scoring_service.dart';
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
      // Scrabble skoru: kelime puanı × deneme çarpanı
      if (word.isNotEmpty) {
        final earned = ScoringService.calculateScore(word, index);
        stats.totalScore += earned;
        if (stats.totalScore > stats.highScore) {
          stats.highScore = stats.totalScore;
        }
      }
    } else {
      stats.lost += 1;
      stats.streak.current = 0;
      stats.lastGuess = -1;
      // Kayıpta skor sıfırla (streak gibi)
      stats.totalScore = 0;
    }
    stats.lastBoard = getSharable(index);
    stats.gameNumber = gameNumber;

    await saveStats(stats);
    _syncToFirestore(stats, won);
    DailyWordService.instance.recordResult(
      won: won,
      tries: index + 1,
      shareText: getSharable(index),
    );
    return stats;
  }

  void _syncToFirestore(Stats stats, bool won) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    FirestoreService.instance.saveGameResult(
      uid: uid,
      playerScore: stats.totalScore,
      aiScore: 0,
      won: won,
      durationSeconds: 0,
    );
  }

  Future<void> saveStats(Stats stats) async {
    final directory = await getApplicationDocumentsDirectory();
    await File("${directory.path}/stats.json").writeAsString(json.encode(stats.toJson()));
  }
}
