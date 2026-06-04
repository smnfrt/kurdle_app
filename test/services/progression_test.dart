import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/level_rewards.dart';
import 'package:kurdle_app/services/progression.dart';

void main() {
  group('progression thresholds', () {
    test('maps XP to stable level boundaries', () {
      expect(levelForXp(-5), 1);
      expect(levelForXp(0), 1);
      expect(levelForXp(199), 1);
      expect(levelForXp(200), 2);
      expect(levelForXp(500), 3);
      expect(levelForXp(15000), 10);
      expect(levelForXp(999999), 10);
    });

    test('progress and next-level values clamp at max level', () {
      expect(xpProgress(100, 1), closeTo(0.5, 0.001));
      expect(xpToNextLevel(100, 1), 100);
      expect(xpProgress(15000, 10), 1.0);
      expect(xpToNextLevel(15000, 10), 0);
    });
  });

  group('level rewards', () {
    test('functional unlocks activate at intended levels', () {
      expect(bonusEnhancesAtLevel(1), 0);
      expect(bonusEnhancesAtLevel(2), 1);
      expect(bonusStealsAtLevel(3), 0);
      expect(bonusStealsAtLevel(4), 1);
      expect(hasWordleHintUnlock(5), false);
      expect(hasWordleHintUnlock(6), true);
      expect(hasDailyRetryUnlock(6), false);
      expect(hasDailyRetryUnlock(7), true);
    });

    test('avatar frame follows prestige ladder', () {
      expect(avatarFrameAtLevel(1), AvatarFrame.none);
      expect(avatarFrameAtLevel(3), AvatarFrame.bronze);
      expect(avatarFrameAtLevel(5), AvatarFrame.silver);
      expect(avatarFrameAtLevel(8), AvatarFrame.gold);
      expect(avatarFrameAtLevel(10), AvatarFrame.prestige);
    });
  });
}
