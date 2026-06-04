// Tek source of truth: seviye eşikleri, XP→level dönüşümü, ilerleme oranı.
// firestore_service ve profile_screen buradan okur, böylece sayfa
// gösterimi ile DB'deki seviye uyumlu kalır.

const List<int> kLevelThresholds = [
  0,      // L1
  200,    // L2
  500,    // L3
  1000,   // L4
  2000,   // L5
  3500,   // L6
  5500,   // L7
  8000,   // L8
  11000,  // L9
  15000,  // L10
];

int levelForXp(int xp) {
  if (xp < 0) return 1;
  for (var i = kLevelThresholds.length - 1; i >= 0; i--) {
    if (xp >= kLevelThresholds[i]) return i + 1;
  }
  return 1;
}

double xpProgress(int xp, int level) {
  if (level < 1) return 0.0;
  if (level >= kLevelThresholds.length) return 1.0;
  final lo = kLevelThresholds[level - 1];
  final hi = kLevelThresholds[level];
  if (hi <= lo) return 1.0;
  return ((xp - lo) / (hi - lo)).clamp(0.0, 1.0);
}

int xpToNextLevel(int xp, int level) {
  if (level >= kLevelThresholds.length) return 0;
  final hi = kLevelThresholds[level];
  return (hi - xp).clamp(0, 999999);
}
