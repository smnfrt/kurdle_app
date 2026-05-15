import 'package:shared_preferences/shared_preferences.dart';
import 'package:kurdle_app/services/notification_service.dart';

/// Günlük "her gün oynama" streak'i.
///
/// Wordle kazanma streak'inden farklı: her gün **herhangi bir oyun** oynanırsa
/// streak korunur, oynamadan bir gün atlanırsa sıfırlanır. Lokal saklanır
/// (anonim user dahil). Cihaz başına bir streak.
class DailyStreakState {
  final int current;
  final int longest;
  final DateTime? lastPlayDate;

  /// Bugün henüz oynanmadı VE dün oynandı → streak risk altında.
  /// UI'da "streak'ini koru!" uyarısı için.
  final bool atRisk;

  /// Bugün zaten oynandı.
  final bool playedToday;

  const DailyStreakState({
    required this.current,
    required this.longest,
    this.lastPlayDate,
    this.atRisk = false,
    this.playedToday = false,
  });

  static const empty = DailyStreakState(current: 0, longest: 0);
}

class DailyStreakService {
  DailyStreakService._();
  static final DailyStreakService instance = DailyStreakService._();

  static const _kCurrentKey = 'daily_streak_current';
  static const _kLongestKey = 'daily_streak_longest';
  static const _kLastDateKey = 'daily_streak_last_date'; // ISO 8601 yyyy-MM-dd

  /// Bugün oynandığını kaydet. State güncellenir ve döner.
  Future<DailyStreakState> markPlayedToday() async {
    final p = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDateStr = p.getString(_kLastDateKey);
    var current = p.getInt(_kCurrentKey) ?? 0;
    var longest = p.getInt(_kLongestKey) ?? 0;

    if (lastDateStr == today) {
      // Bugün zaten oynamış — idempotent, değişiklik yok
      return DailyStreakState(
        current: current,
        longest: longest,
        lastPlayDate: _parse(lastDateStr),
        playedToday: true,
      );
    }

    if (lastDateStr == null) {
      current = 1;
    } else {
      final diff = _daysBetween(_parse(lastDateStr)!, _parse(today)!);
      if (diff == 1) {
        current += 1;
      } else {
        // 2+ gün atlanmış — streak yeniden başlar
        current = 1;
      }
    }

    if (current > longest) longest = current;

    await p.setInt(_kCurrentKey, current);
    await p.setInt(_kLongestKey, longest);
    await p.setString(_kLastDateKey, today);

    // Bugün oynandı — akşam streak hatırlatması rahatsız etmesin (fire-and-forget)
    NotificationService.instance.cancelTodayStreakReminder().catchError((_) {});

    return DailyStreakState(
      current: current,
      longest: longest,
      lastPlayDate: _parse(today),
      playedToday: true,
    );
  }

  /// Mevcut state'i okur. Yan etkisi yok — sadece okuyucu.
  /// `atRisk` ve `playedToday` bilgisini de hesaplar.
  Future<DailyStreakState> getState() async {
    final p = await SharedPreferences.getInstance();
    final lastDateStr = p.getString(_kLastDateKey);
    var current = p.getInt(_kCurrentKey) ?? 0;
    final longest = p.getInt(_kLongestKey) ?? 0;

    if (lastDateStr == null) return DailyStreakState.empty;

    final lastDate = _parse(lastDateStr)!;
    final today = _parse(_todayKey())!;
    final diff = _daysBetween(lastDate, today);

    final playedToday = diff == 0;
    final atRisk = diff == 1; // dün oynamış, bugün henüz değil

    // 2+ gün atlanmışsa streak fiilen sıfır; ama henüz markPlayed çağrılana
    // kadar persist edilmez. UI için 0 göster, gerçek reset markPlayed'de olur.
    final effectiveCurrent = (diff >= 2) ? 0 : current;

    return DailyStreakState(
      current: effectiveCurrent,
      longest: longest,
      lastPlayDate: lastDate,
      atRisk: atRisk,
      playedToday: playedToday,
    );
  }

  /// Test veya kullanıcı isteğiyle sıfırla.
  Future<void> reset() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCurrentKey);
    await p.remove(_kLongestKey);
    await p.remove(_kLastDateKey);
  }

  // ── helpers ─────────────────────────────────────────────────────

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parse(String? s) {
    if (s == null) return null;
    final parts = s.split('-');
    if (parts.length != 3) return null;
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  int _daysBetween(DateTime a, DateTime b) {
    final ad = DateTime(a.year, a.month, a.day);
    final bd = DateTime(b.year, b.month, b.day);
    return bd.difference(ad).inDays;
  }
}
