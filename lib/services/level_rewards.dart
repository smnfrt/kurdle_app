// Seviye ödülleri — işlevsel + kozmetik unlock tablosu.
//
// Tek source of truth: UI bu fonksiyonlarla "bu seviyede neyi yapabilir"
// sorusunu cevaplar. Yeni seviye ödülü eklemek için sadece burayı düzenle.
//
// Tasarım: erken seviyeler (L2-L5) küçük ama somut işlevsel boost'lar,
// orta seviyeler (L6-L8) gameplay açıcılar, üst seviyeler (L9-L10)
// prestige + kozmetik.

import 'package:flutter/material.dart';

enum AvatarFrame { none, bronze, silver, gold, prestige }

class LevelReward {
  final int level;
  final String trTitle;
  final String kuTitle;
  final IconData icon;
  final Color accent;
  const LevelReward({
    required this.level,
    required this.trTitle,
    required this.kuTitle,
    required this.icon,
    required this.accent,
  });
}

const List<LevelReward> kLevelRewards = [
  LevelReward(
    level: 2,
    trTitle: 'Her oyunda +1 Geliştirme hakkı',
    kuTitle: 'Her lîstikê +1 mafê Pêşkeftin',
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xFFFFD700),
  ),
  LevelReward(
    level: 3,
    trTitle: 'Bronz avatar çerçevesi',
    kuTitle: 'Çarçoveyê Bronz a avatar',
    icon: Icons.shield_rounded,
    accent: Color(0xFFCD7F32),
  ),
  LevelReward(
    level: 4,
    trTitle: 'Her oyunda +1 Çalma hakkı',
    kuTitle: 'Her lîstikê +1 mafê Dizîn',
    icon: Icons.flash_on_rounded,
    accent: Color(0xFFFF6F00),
  ),
  LevelReward(
    level: 5,
    trTitle: 'Gümüş çerçeve + "Usta" ünvanı',
    kuTitle: 'Çarçoveyê Zîv + "Hosta" navê',
    icon: Icons.workspace_premium_rounded,
    accent: Color(0xFFC0C0C0),
  ),
  LevelReward(
    level: 6,
    trTitle: 'Wordle Harf İpucu kilidi açılır',
    kuTitle: 'Kilîda Şîreta Tîpê ya Wordle vebû',
    icon: Icons.lightbulb_rounded,
    accent: Color(0xFFFFB300),
  ),
  LevelReward(
    level: 7,
    trTitle: 'Günlük Challenge yeniden başlatma',
    kuTitle: 'Dîsa destpêkirina Challenge ya rojane',
    icon: Icons.refresh_rounded,
    accent: Color(0xFF42A5F5),
  ),
  LevelReward(
    level: 8,
    trTitle: 'Altın avatar çerçevesi',
    kuTitle: 'Çarçoveyê Zêr a avatar',
    icon: Icons.workspace_premium_rounded,
    accent: Color(0xFFFFD700),
  ),
  LevelReward(
    level: 9,
    trTitle: 'Özel taş temaları',
    kuTitle: 'Mijara taybet a kevirên',
    icon: Icons.palette_rounded,
    accent: Color(0xFF9C27B0),
  ),
  LevelReward(
    level: 10,
    trTitle: 'Leyar Ustası — prestij rozeti',
    kuTitle: 'Hosta yê Leyar — Rozetê Prestîj',
    icon: Icons.military_tech_rounded,
    accent: Color(0xFFB9F2FF),
  ),
];

// ── Aktif kontrol helper'ları ────────────────────────────────────

/// Verilen seviyede oyuncuya kaç bonus Enhance hakkı verilir.
/// Base enhance (oyun başlangıcında verilen) + bu sayı.
int bonusEnhancesAtLevel(int level) => level >= 2 ? 1 : 0;

/// Verilen seviyede oyuncuya kaç bonus Steal hakkı verilir.
int bonusStealsAtLevel(int level) => level >= 4 ? 1 : 0;

/// Wordle harf ipucu butonu unlock'u (L6+).
bool hasWordleHintUnlock(int level) => level >= 6;

/// Daily challenge retry unlock'u (L7+).
bool hasDailyRetryUnlock(int level) => level >= 7;

/// Multiplayer'da gösterilen ünvan ("Usta" L5+).
String? mpTitleAtLevel(int level, {required bool isTr}) {
  if (level >= 10) return isTr ? 'Leyar Ustası' : 'Hosta yê Leyar';
  if (level >= 5) return isTr ? 'Usta' : 'Hosta';
  return null;
}

/// Oyuncunun avatar çerçeve seviyesi.
AvatarFrame avatarFrameAtLevel(int level) {
  if (level >= 10) return AvatarFrame.prestige;
  if (level >= 8) return AvatarFrame.gold;
  if (level >= 5) return AvatarFrame.silver;
  if (level >= 3) return AvatarFrame.bronze;
  return AvatarFrame.none;
}

/// Çerçeve rengi (avatar etrafına çizilen halka).
Color? avatarFrameColor(AvatarFrame frame) {
  switch (frame) {
    case AvatarFrame.none:     return null;
    case AvatarFrame.bronze:   return const Color(0xFFCD7F32);
    case AvatarFrame.silver:   return const Color(0xFFC0C0C0);
    case AvatarFrame.gold:     return const Color(0xFFFFD700);
    case AvatarFrame.prestige: return const Color(0xFFB9F2FF);
  }
}
