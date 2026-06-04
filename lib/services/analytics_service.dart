import 'package:kurdle_app/services/firebase_service.dart';

/// Firebase Analytics ince sarmalayıcı.
/// Önceden analytics init ediliyordu ama HİÇ event gönderilmiyordu (ürün kör).
/// Bu servis oyun olaylarını güvenli (analytics yoksa no-op) şekilde yollar.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    final a = FirebaseService.analytics;
    if (a == null) return;
    try {
      await a.logEvent(name: name, parameters: params);
    } catch (_) {
      // Analytics best-effort — asla oyunu etkilemez.
    }
  }

  /// Bir oyun modu başladı (mode: 'wordle' | 'daily_challenge' | 'scrabble_ai' | 'multiplayer').
  Future<void> gameStart(String mode) => logEvent('game_start', {'mode': mode});

  /// Bir oyun bitti.
  Future<void> gameFinish(String mode, {required bool won, int? score}) =>
      logEvent('game_finish', {
        'mode': mode,
        'won': won.toString(),
        if (score != null) 'score': score,
      });
}
