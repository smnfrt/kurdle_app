import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kurdle_app/models/achievement.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/logging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Achievement (rozet) yönetimi.
///
/// Tanımlar kod içinde sabit (`AchievementService.definitions`). Kullanıcı
/// state'i (progress + unlocked) lokal `shared_preferences` + Firestore'da
/// (signed-in user için) saklanır. Lokal kaynak otoritedir; Firestore senkron.
///
/// Stream `unlockEvents` ile UI yeni unlock'larda toast/celebration gösterebilir.
class AchievementService {
  AchievementService._();
  static final AchievementService instance = AchievementService._();

  // ── Tanımlar ────────────────────────────────────────────────────

  static const definitions = <AchievementDef>[
    // Progression
    AchievementDef(
      id: 'first_game',
      titleTr: 'İlk Adım',
      titleKu: 'Gava Yekem',
      descTr: 'İlk oyununu oyna',
      descKu: 'Yekem lîstika xwe bilîze',
      icon: Icons.play_circle_filled_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.progression,
    ),
    AchievementDef(
      id: 'games_10',
      titleTr: 'Acemi Oyuncu',
      titleKu: 'Lîstikvanê Nû',
      descTr: '10 oyun oyna',
      descKu: '10 lîstik bilîze',
      icon: Icons.videogame_asset_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.progression,
      target: 10,
    ),
    AchievementDef(
      id: 'games_50',
      titleTr: 'Tecrübeli',
      titleKu: 'Bi Tecrube',
      descTr: '50 oyun oyna',
      descKu: '50 lîstik bilîze',
      icon: Icons.military_tech_rounded,
      tier: AchievementTier.silver,
      category: AchievementCategory.progression,
      target: 50,
    ),
    AchievementDef(
      id: 'games_200',
      titleTr: 'Usta',
      titleKu: 'Hosta',
      descTr: '200 oyun oyna',
      descKu: '200 lîstik bilîze',
      icon: Icons.workspace_premium_rounded,
      tier: AchievementTier.gold,
      category: AchievementCategory.progression,
      target: 200,
    ),

    // Streak
    AchievementDef(
      id: 'streak_3',
      titleTr: '3 Günlük Seri',
      titleKu: 'Rêza 3 Rojan',
      descTr: '3 gün üst üste oyna',
      descKu: '3 rojan li pey hev bilîze',
      icon: Icons.local_fire_department_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.streak,
      target: 3,
    ),
    AchievementDef(
      id: 'streak_7',
      titleTr: 'Bir Hafta!',
      titleKu: 'Hefteyek!',
      descTr: '7 gün üst üste oyna',
      descKu: '7 rojan li pey hev bilîze',
      icon: Icons.local_fire_department_rounded,
      tier: AchievementTier.silver,
      category: AchievementCategory.streak,
      target: 7,
    ),
    AchievementDef(
      id: 'streak_30',
      titleTr: 'Sadık Oyuncu',
      titleKu: 'Lîstikvanê Dilsoz',
      descTr: '30 gün üst üste oyna',
      descKu: '30 rojan li pey hev bilîze',
      icon: Icons.local_fire_department_rounded,
      tier: AchievementTier.gold,
      category: AchievementCategory.streak,
      target: 30,
    ),
    AchievementDef(
      id: 'streak_100',
      titleTr: 'Efsane',
      titleKu: 'Efsane',
      descTr: '100 gün üst üste oyna',
      descKu: '100 rojan li pey hev bilîze',
      icon: Icons.local_fire_department_rounded,
      tier: AchievementTier.platinum,
      category: AchievementCategory.streak,
      target: 100,
    ),

    // Skill
    AchievementDef(
      id: 'first_win',
      titleTr: 'İlk Zafer',
      titleKu: 'Bidestxistina Yekem',
      descTr: 'İlk oyununu kazan',
      descKu: 'Lîstika xwe ya yekem bibe',
      icon: Icons.emoji_events_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.skill,
    ),
    AchievementDef(
      id: 'word_30pts',
      titleTr: 'Güzel Hamle',
      titleKu: 'Liva Xweş',
      descTr: '30+ puanlık bir kelime oyna',
      descKu: 'Peyveke 30+ xalî bilîze',
      icon: Icons.star_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.skill,
      target: 30,
    ),
    AchievementDef(
      id: 'word_50pts',
      titleTr: 'Büyük Vuruş',
      titleKu: 'Lêdana Mezin',
      descTr: '50+ puanlık bir kelime oyna',
      descKu: 'Peyveke 50+ xalî bilîze',
      icon: Icons.star_rounded,
      tier: AchievementTier.silver,
      category: AchievementCategory.skill,
      target: 50,
    ),
    AchievementDef(
      id: 'word_100pts',
      titleTr: 'Kelime Cambazı',
      titleKu: 'Peyvasaz',
      descTr: '100+ puanlık bir kelime oyna',
      descKu: 'Peyveke 100+ xalî bilîze',
      icon: Icons.star_rounded,
      tier: AchievementTier.gold,
      category: AchievementCategory.skill,
      target: 100,
    ),
    AchievementDef(
      id: 'wins_25',
      titleTr: 'Şampiyon',
      titleKu: 'Şampiyon',
      descTr: '25 oyun kazan',
      descKu: '25 lîstikan bibe',
      icon: Icons.emoji_events_rounded,
      tier: AchievementTier.silver,
      category: AchievementCategory.skill,
      target: 25,
    ),

    // Exploration
    AchievementDef(
      id: 'ferheng_first_view',
      titleTr: 'Sözlük Açıldı',
      titleKu: 'Ferheng Vebû',
      descTr: 'Bir kelimenin anlamına bak',
      descKu: 'Li wateya peyvekê binêre',
      icon: Icons.menu_book_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.exploration,
    ),
    AchievementDef(
      id: 'ferheng_views_50',
      titleTr: 'Meraklı Okur',
      titleKu: 'Xwendekarê Meraqdar',
      descTr: '50 kelimenin anlamını öğren',
      descKu: 'Wateya 50 peyvan hîn bibe',
      icon: Icons.auto_stories_rounded,
      tier: AchievementTier.silver,
      category: AchievementCategory.exploration,
      target: 50,
    ),
    AchievementDef(
      id: 'flashcard_first',
      titleTr: 'Çalışma Başladı',
      titleKu: 'Xwendin Destpêkir',
      descTr: 'Bir flashcard turunu tamamla',
      descKu: 'Gera flashcardê biqedîne',
      icon: Icons.style_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.exploration,
    ),

    // Social
    AchievementDef(
      id: 'first_friend_game',
      titleTr: 'Sosyal',
      titleKu: 'Civakî',
      descTr: 'Arkadaşınla bir oyun oyna',
      descKu: 'Bi hevalê xwe re lîstikekê bilîze',
      icon: Icons.people_rounded,
      tier: AchievementTier.bronze,
      category: AchievementCategory.social,
    ),
  ];

  // ── State ───────────────────────────────────────────────────────

  static const _kStateKey = 'achievement_state';

  final _unlockController = StreamController<AchievementDef>.broadcast();

  /// UI bu stream'e abone olarak yeni unlock olduğunda toast gösterebilir.
  Stream<AchievementDef> get unlockEvents => _unlockController.stream;

  Map<String, AchievementState>? _cache;

  /// Tüm rozet durumlarını yükler (lokal). Cache'lenir.
  Future<Map<String, AchievementState>> getAllStates() async {
    if (_cache != null) return _cache!;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kStateKey);
    final map = <String, AchievementState>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            map[entry.key] = AchievementState.fromJson(
                entry.key, entry.value as Map<String, dynamic>);
          }
        }
      } catch (e) {
        Log.warn('AchievementService', 'state JSON parse failed — resetting', e);
      }
    }
    // Eksik tanımlar için default state
    for (final def in definitions) {
      map.putIfAbsent(def.id, () => AchievementState(id: def.id));
    }
    _cache = map;
    return map;
  }

  Future<void> _persist() async {
    if (_cache == null) return;
    final p = await SharedPreferences.getInstance();
    final encoded = json.encode(
      _cache!.map((k, v) => MapEntry(k, v.toJson())),
    );
    await p.setString(_kStateKey, encoded);
    // Best-effort Firestore sync
    _syncToFirestore();
  }

  Future<void> _syncToFirestore() async {
    if (!FirebaseService.isAvailable) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('achievements');
      for (final entry in _cache!.entries) {
        if (entry.value.unlocked || entry.value.progress > 0) {
          batch.set(col.doc(entry.key), entry.value.toJson(),
              SetOptions(merge: true));
        }
      }
      await batch.commit();
    } catch (e) {
      Log.warn('AchievementService', 'Firestore sync failed (offline?)', e);
    }
  }

  // ── Progress kaydı ──────────────────────────────────────────────

  /// `progress` artırır. Yeni değer target'e ulaşırsa unlock tetiklenir.
  /// Daha düşük değerle çağrılırsa yok sayılır (monoton).
  Future<void> recordProgress(String id, int newProgress) async {
    final def = definitions.firstWhere((d) => d.id == id,
        orElse: () => throw ArgumentError('Unknown achievement: $id'));
    final states = await getAllStates();
    final cur = states[id]!;
    if (cur.unlocked) return;
    if (newProgress <= cur.progress) return;
    final shouldUnlock = newProgress >= def.target;
    final next = cur.copyWith(
      progress: newProgress,
      unlocked: shouldUnlock,
      unlockedAt: shouldUnlock ? DateTime.now() : null,
    );
    states[id] = next;
    await _persist();
    if (shouldUnlock) {
      _unlockController.add(def);
    }
  }

  /// Sadece "var/yok" tipi rozetler için.
  Future<void> unlock(String id) async {
    final def = definitions.firstWhere((d) => d.id == id,
        orElse: () => throw ArgumentError('Unknown achievement: $id'));
    final states = await getAllStates();
    final cur = states[id]!;
    if (cur.unlocked) return;
    states[id] = cur.copyWith(
      progress: def.target,
      unlocked: true,
      unlockedAt: DateTime.now(),
    );
    await _persist();
    _unlockController.add(def);
  }

  /// Mevcut progress'i en az `value`'e çıkar (idempotent çoklu olay için).
  Future<void> recordAtLeast(String id, int value) async {
    final states = await getAllStates();
    final cur = states[id]!;
    if (cur.progress >= value) return;
    return recordProgress(id, value);
  }

  // ── Kompozit event'ler ──────────────────────────────────────────

  /// Bir oyun başlatıldı (tüm modlar). Toplam oyun sayısı artırılır.
  Future<void> onGameStarted() async {
    final states = await getAllStates();
    final played =
        _maxProgress(states, const ['games_10', 'games_50', 'games_200']) + 1;
    await recordProgress('first_game', 1);
    await recordProgress('games_10', played);
    await recordProgress('games_50', played);
    await recordProgress('games_200', played);
  }

  /// Bir oyun kazanıldı. Galibiyet rozetleri.
  Future<void> onGameWon() async {
    final states = await getAllStates();
    final wins = (states['wins_25']?.progress ?? 0) + 1;
    await recordProgress('first_win', 1);
    await recordProgress('wins_25', wins);
  }

  /// Streak güncellendi (DailyStreakService'den sonra çağrılır).
  Future<void> onStreakChanged(int current) async {
    await recordAtLeast('streak_3', current);
    await recordAtLeast('streak_7', current);
    await recordAtLeast('streak_30', current);
    await recordAtLeast('streak_100', current);
  }

  /// Yüksek puanlı kelime oynandı.
  Future<void> onWordPlayed(int score) async {
    await recordAtLeast('word_30pts', score);
    await recordAtLeast('word_50pts', score);
    await recordAtLeast('word_100pts', score);
  }

  /// Ferheng entry görüntülendi.
  Future<void> onFerhengEntryViewed() async {
    final states = await getAllStates();
    final views = (states['ferheng_views_50']?.progress ?? 0) + 1;
    await recordProgress('ferheng_first_view', 1);
    await recordProgress('ferheng_views_50', views);
  }

  Future<void> onFlashcardCompleted() async => unlock('flashcard_first');
  Future<void> onFriendGamePlayed() async => unlock('first_friend_game');

  int _maxProgress(Map<String, AchievementState> states, List<String> ids) {
    var max = 0;
    for (final id in ids) {
      final progress = states[id]?.progress ?? 0;
      if (progress > max) max = progress;
    }
    return max;
  }

  void dispose() {
    _unlockController.close();
  }
}
