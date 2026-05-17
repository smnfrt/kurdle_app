import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/daily_streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCurrentKey = 'daily_streak_current';
const _kLongestKey = 'daily_streak_longest';
const _kLastDateKey = 'daily_streak_last_date';

String _isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = DailyStreakService.instance;
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  final twoDaysAgo = today.subtract(const Duration(days: 2));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await svc.reset();
  });

  group('getState', () {
    test('returns empty when no prefs', () async {
      final s = await svc.getState();
      expect(s.current, 0);
      expect(s.longest, 0);
      expect(s.lastPlayDate, isNull);
      expect(s.playedToday, false);
      expect(s.atRisk, false);
    });

    test('preserves streak when last play was today', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 5,
        _kLongestKey: 7,
        _kLastDateKey: _isoOf(today),
      });
      final s = await svc.getState();
      expect(s.current, 5);
      expect(s.longest, 7);
      expect(s.playedToday, true);
      expect(s.atRisk, false);
    });

    test('marks atRisk when last play was yesterday', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 3,
        _kLongestKey: 9,
        _kLastDateKey: _isoOf(yesterday),
      });
      final s = await svc.getState();
      expect(s.current, 3);
      expect(s.atRisk, true);
      expect(s.playedToday, false);
    });

    test('shows current=0 when 2+ days missed (effective reset)', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 10,
        _kLongestKey: 10,
        _kLastDateKey: _isoOf(twoDaysAgo),
      });
      final s = await svc.getState();
      expect(s.current, 0);
      expect(s.longest, 10); // longest preserved
      expect(s.atRisk, false);
      expect(s.playedToday, false);
    });
  });

  group('markPlayedToday', () {
    test('first play → current=1, longest=1', () async {
      final s = await svc.markPlayedToday();
      expect(s.current, 1);
      expect(s.longest, 1);
      expect(s.playedToday, true);
    });

    test('played yesterday + today → current=prev+1', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 4,
        _kLongestKey: 4,
        _kLastDateKey: _isoOf(yesterday),
      });
      final s = await svc.markPlayedToday();
      expect(s.current, 5);
      expect(s.longest, 5);
      expect(s.playedToday, true);
    });

    test('played 2 days ago + today → current=1 (reset)', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 8,
        _kLongestKey: 8,
        _kLastDateKey: _isoOf(twoDaysAgo),
      });
      final s = await svc.markPlayedToday();
      expect(s.current, 1);
      expect(s.longest, 8); // longest preserved
    });

    test('already played today → idempotent (no change)', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 6,
        _kLongestKey: 12,
        _kLastDateKey: _isoOf(today),
      });
      final s = await svc.markPlayedToday();
      expect(s.current, 6);
      expect(s.longest, 12);
      expect(s.playedToday, true);
    });

    test('updates longest when current exceeds previous best', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 9,
        _kLongestKey: 9,
        _kLastDateKey: _isoOf(yesterday),
      });
      final s = await svc.markPlayedToday();
      expect(s.current, 10);
      expect(s.longest, 10);
    });
  });

  group('reset', () {
    test('clears all keys', () async {
      SharedPreferences.setMockInitialValues({
        _kCurrentKey: 5,
        _kLongestKey: 5,
        _kLastDateKey: _isoOf(today),
      });
      await svc.reset();
      final s = await svc.getState();
      expect(s.current, 0);
      expect(s.longest, 0);
      expect(s.lastPlayDate, isNull);
    });
  });
}
