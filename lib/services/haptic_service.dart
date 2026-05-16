import 'package:flutter/services.dart';
import 'package:kurdle_app/services/logging_service.dart';
import 'package:kurdle_app/services/settings_service.dart';

class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  static const _channel = MethodChannel('com.kurdle.kurdle_app/haptic');
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> init() async {
    final settings = await SettingsService().load();
    _enabled = settings.hapticEnabled;
  }

  void setEnabled(bool value) => _enabled = value;

  Future<void> _play(String pattern) async {
    if (!_enabled) return;
    try {
      await _channel.invokeMethod('vibrate', {'pattern': pattern});
    } catch (e) {
      Log.warn('HapticService', 'native channel failed, using system fallback', e);
      await HapticFeedback.selectionClick();
    }
  }

  // Taşı raftan kaldırma
  void tilePickup() => _play('tilePickup');

  // Sürüklerken hücreye girme (hafif tık)
  void cellHover() => _play('cellHover');

  // Taşı tahtaya bırakma
  void tileDrop() => _play('tileDrop');

  // Taşı rafa iade
  void tileReturn() => _play('tileReturn');

  // Geçerli kelime onayı
  void wordValid() => _play('wordValid');

  // Geçersiz kelime
  void wordInvalid() => _play('wordInvalid');

  // Hamle gönderme
  void submit() => _play('submit');

  // Kazanma
  void win() => _play('win');

  // Kaybetme
  void lose() => _play('lose');

  // Çalma modu toggle
  void stealToggle() => _play('stealToggle');
}
