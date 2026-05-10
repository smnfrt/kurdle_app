import 'package:flutter/services.dart';

class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  static const _channel = MethodChannel('com.kurdle.kurdle_app/haptic');

  Future<void> _play(String pattern) async {
    try {
      await _channel.invokeMethod('vibrate', {'pattern': pattern});
    } catch (_) {
      // Kanal yoksa Flutter fallback
    }
  }

  // Taşı raftan kaldırma
  void tilePickup()  => _play('tilePickup');

  // Sürüklerken hücreye girme (hafif tık)
  void cellHover()   => _play('cellHover');

  // Taşı tahtaya bırakma
  void tileDrop()    => _play('tileDrop');

  // Taşı rafa iade
  void tileReturn()  => _play('tileReturn');

  // Geçerli kelime onayı
  void wordValid()   => _play('wordValid');

  // Geçersiz kelime
  void wordInvalid() => _play('wordInvalid');

  // Hamle gönderme
  void submit()      => _play('submit');

  // Kazanma
  void win()         => _play('win');

  // Kaybetme
  void lose()        => _play('lose');

  // Çalma modu toggle
  void stealToggle() => _play('stealToggle');
}
