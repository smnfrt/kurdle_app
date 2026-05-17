import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = AchievementService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    svc.resetCacheForTests();
  });

  group('getAllStates', () {
    test('returns default state for all definitions when prefs empty', () async {
      final states = await svc.getAllStates();
      // Every defined achievement should have a state entry
      for (final def in AchievementService.definitions) {
        expect(states[def.id], isNotNull,
            reason: 'missing state for ${def.id}');
        expect(states[def.id]!.unlocked, false);
        expect(states[def.id]!.progress, 0);
      }
    });

    test('caches result across calls', () async {
      final s1 = await svc.getAllStates();
      final s2 = await svc.getAllStates();
      expect(identical(s1, s2), true);
    });
  });

  group('recordProgress', () {
    test('monotonic — lower value ignored', () async {
      await svc.recordProgress('games_10', 5);
      await svc.recordProgress('games_10', 3); // should be ignored
      final states = await svc.getAllStates();
      expect(states['games_10']!.progress, 5);
      expect(states['games_10']!.unlocked, false);
    });

    test('unlocks when progress reaches target', () async {
      // games_10 target = 10
      await svc.recordProgress('games_10', 10);
      final states = await svc.getAllStates();
      expect(states['games_10']!.progress, 10);
      expect(states['games_10']!.unlocked, true);
      expect(states['games_10']!.unlockedAt, isNotNull);
    });

    test('no-op once unlocked', () async {
      await svc.recordProgress('first_game', 1); // target = 1
      final stateBefore = (await svc.getAllStates())['first_game']!;
      expect(stateBefore.unlocked, true);
      final unlockedAtBefore = stateBefore.unlockedAt;
      await Future.delayed(const Duration(milliseconds: 5));
      await svc.recordProgress('first_game', 2);
      final stateAfter = (await svc.getAllStates())['first_game']!;
      expect(stateAfter.unlockedAt, unlockedAtBefore);
    });

    test('throws on unknown achievement id', () async {
      expect(() => svc.recordProgress('not_a_real_id', 1),
          throwsArgumentError);
    });
  });

  group('unlock (direct)', () {
    test('marks unlocked with target progress', () async {
      await svc.unlock('first_win');
      final states = await svc.getAllStates();
      expect(states['first_win']!.unlocked, true);
      expect(states['first_win']!.progress, 1);
    });

    test('idempotent — second call no-op', () async {
      await svc.unlock('first_win');
      final at1 = (await svc.getAllStates())['first_win']!.unlockedAt;
      await Future.delayed(const Duration(milliseconds: 5));
      await svc.unlock('first_win');
      final at2 = (await svc.getAllStates())['first_win']!.unlockedAt;
      expect(at1, at2);
    });
  });

  group('recordAtLeast', () {
    test('monotonic — does not lower existing progress', () async {
      await svc.recordProgress('word_30pts', 30);
      await svc.recordAtLeast('word_30pts', 20); // lower — ignore
      expect((await svc.getAllStates())['word_30pts']!.progress, 30);
    });

    test('raises progress when value is higher', () async {
      await svc.recordProgress('word_30pts', 10);
      await svc.recordAtLeast('word_30pts', 25);
      expect((await svc.getAllStates())['word_30pts']!.progress, 25);
    });
  });

  group('composite events', () {
    test('onGameStarted increments games_* counters', () async {
      await svc.onGameStarted();
      final states = await svc.getAllStates();
      expect(states['first_game']!.unlocked, true);
      expect(states['games_10']!.progress, 1);
      await svc.onGameStarted();
      expect((await svc.getAllStates())['games_10']!.progress, 2);
    });

    test('onGameWon increments wins_*', () async {
      await svc.onGameWon();
      final states = await svc.getAllStates();
      expect(states['first_win']!.unlocked, true);
      expect(states['wins_25']!.progress, 1);
    });

    test('onWordPlayed updates by-score thresholds', () async {
      await svc.onWordPlayed(45);
      final states = await svc.getAllStates();
      expect(states['word_30pts']!.unlocked, true); // 45 >= 30
      expect(states['word_50pts']!.unlocked, false);
      expect(states['word_50pts']!.progress, 45);
    });

    test('onStreakChanged tracks streak thresholds', () async {
      await svc.onStreakChanged(8);
      final states = await svc.getAllStates();
      expect(states['streak_3']!.unlocked, true);
      expect(states['streak_7']!.unlocked, true);
      expect(states['streak_30']!.unlocked, false);
      expect(states['streak_30']!.progress, 8);
    });
  });

  group('unlock events stream', () {
    test('emits AchievementDef on unlock', () async {
      final events = <String>[];
      final sub = svc.unlockEvents.listen((def) => events.add(def.id));

      await svc.unlock('first_game');
      await svc.unlock('first_win');
      // Wait for stream microtasks
      await Future.delayed(Duration.zero);
      await sub.cancel();

      expect(events.length, 2);
      expect(events, containsAll(['first_game', 'first_win']));
    });

    test('does not emit on no-op unlock (already unlocked)', () async {
      await svc.unlock('first_game'); // initial
      final events = <String>[];
      final sub = svc.unlockEvents.listen((def) => events.add(def.id));
      await svc.unlock('first_game'); // already unlocked
      await Future.delayed(Duration.zero);
      await sub.cancel();
      expect(events, isEmpty);
    });
  });
}
