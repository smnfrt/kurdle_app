import 'package:flutter/material.dart';

/// Rozet kademe seviyeleri — renk ve görsel kalite hiyerarşisi.
enum AchievementTier { bronze, silver, gold, platinum }

/// Rozet kategorisi — UI'da gruplama için.
enum AchievementCategory {
  progression,  // oyun sayısı, deneyim
  streak,       // günlük seri
  skill,        // yüksek skor, başarı
  exploration,  // ferheng kullanımı, öğrenme
  social,       // paylaşım, multiplayer
}

/// Bir rozetin sabit tanımı (kod içinde).
class AchievementDef {
  final String id;
  final String titleTr;
  final String titleKu;
  final String descTr;
  final String descKu;
  final IconData icon;
  final AchievementTier tier;
  final AchievementCategory category;

  /// Bu rozeti açmak için gereken hedef sayısı. UI'da progress için.
  final int target;

  const AchievementDef({
    required this.id,
    required this.titleTr,
    required this.titleKu,
    required this.descTr,
    required this.descKu,
    required this.icon,
    required this.tier,
    required this.category,
    this.target = 1,
  });

  String title(bool isTr) => isTr ? titleTr : titleKu;
  String desc(bool isTr) => isTr ? descTr : descKu;

  Color get tierColor {
    switch (tier) {
      case AchievementTier.bronze:   return const Color(0xFFCD7F32);
      case AchievementTier.silver:   return const Color(0xFFC0C0C0);
      case AchievementTier.gold:     return const Color(0xFFFFD700);
      case AchievementTier.platinum: return const Color(0xFFB9F2FF);
    }
  }
}

/// Bir rozetin kullanıcıya özel durumu (kilitli/açık + ilerleme).
class AchievementState {
  final String id;
  final int progress;
  final bool unlocked;
  final DateTime? unlockedAt;

  const AchievementState({
    required this.id,
    this.progress = 0,
    this.unlocked = false,
    this.unlockedAt,
  });

  AchievementState copyWith({int? progress, bool? unlocked, DateTime? unlockedAt}) =>
      AchievementState(
        id: id,
        progress: progress ?? this.progress,
        unlocked: unlocked ?? this.unlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'unlocked': unlocked,
        if (unlockedAt != null) 'unlockedAt': unlockedAt!.toIso8601String(),
      };

  factory AchievementState.fromJson(String id, Map<String, dynamic> json) =>
      AchievementState(
        id: id,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        unlocked: json['unlocked'] as bool? ?? false,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.tryParse(json['unlockedAt'] as String)
            : null,
      );
}
