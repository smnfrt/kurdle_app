import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/services/firebase_service.dart';

/// Hafif merkezi logger.
///
/// Debug build'de `debugPrint` ile konsola yazar; production build'inde
/// Firebase Crashlytics aktifse `recordError` / `log` çağrılarına forward eder.
///
/// Crashlytics çağrıları FirebaseService.isAvailable gate'i ile korunur —
/// Firebase henüz init olmadıysa (örn. cold start, offline mod) sessizce
/// debug'a düşer, app crash etmez.
///
/// Kullanım:
///   Log.warn('FerhengService', 'cache parse failed', err);
///   Log.error('Multiplayer', 'createRoom failed', err, stack);
class Log {
  Log._();

  static void info(String tag, String message) {
    if (kDebugMode) debugPrint('[INFO][$tag] $message');
    _crashlyticsLog('[$tag] $message');
  }

  static void warn(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      final suffix = error == null ? '' : ' ($error)';
      debugPrint('[WARN][$tag] $message$suffix');
    }
    if (error != null) {
      _recordError(error, null, reason: '[$tag] $message', fatal: false);
    } else {
      _crashlyticsLog('[WARN][$tag] $message');
    }
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
    _recordError(error, stack, reason: '[$tag] $message', fatal: false);
  }

  // ── Internal ────────────────────────────────────────────────────

  static void _crashlyticsLog(String message) {
    if (!FirebaseService.isAvailable) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
      // Crashlytics henüz init olmadı — sessizce yoksay
    }
  }

  static void _recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    required bool fatal,
  }) {
    if (!FirebaseService.isAvailable) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {
      // Crashlytics henüz init olmadı — sessizce yoksay
    }
  }
}
