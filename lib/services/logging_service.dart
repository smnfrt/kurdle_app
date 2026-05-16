import 'package:flutter/foundation.dart';

/// Hafif merkezi logger.
///
/// Debug build'de `debugPrint` ile konsola yazar; production'da Crashlytics
/// hazır olunca `recordError` çağrılacak (Adım 4 entegrasyonunda).
///
/// Kullanım:
///   Log.warn('FerhengService', 'cache parse failed', err);
///   Log.error('Multiplayer', 'createRoom failed', err, stack);
class Log {
  Log._();

  static void info(String tag, String message) {
    if (kDebugMode) debugPrint('[INFO][$tag] $message');
  }

  static void warn(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      final suffix = error == null ? '' : ' ($error)';
      debugPrint('[WARN][$tag] $message$suffix');
    }
    // TODO(crashlytics): Adım 4'te non-fatal record eklenir
  }

  static void error(
    String tag,
    String message,
    Object error, [
    StackTrace? stack,
  ]) {
    if (kDebugMode) {
      debugPrint('[ERROR][$tag] $message: $error');
      if (stack != null) debugPrint(stack.toString());
    }
    // TODO(crashlytics): Adım 4'te FirebaseCrashlytics.recordError çağrısı eklenir
  }
}
