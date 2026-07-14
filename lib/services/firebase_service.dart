import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/firebase_options.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';

// Tek başlatma noktası. main.dart buradan çağırır.
class FirebaseService {
  static const _coreInitTimeout = Duration(milliseconds: 2500);
  static const _pluginCallTimeout = Duration(milliseconds: 900);
  static const _authBootstrapTimeout = Duration(milliseconds: 1400);
  static const _profileBootstrapTimeout = Duration(milliseconds: 1200);

  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  /// Analytics observer'ı home/route widget'larında kullanmak için.
  /// init() çağrıldıktan sonra erişilebilir.
  static FirebaseAnalytics? analytics;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(_coreInitTimeout);
      _initialized = true;

      // Crashlytics: debug'da kapalı, release'de açık. Kullanıcı
      // ayarlardan opt-out yapabilirse buradan toggle edilir.
      try {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode)
            .timeout(_pluginCallTimeout);

        // Flutter framework error'larını otomatik raporla
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;

        // Async/platform error'larını da yakala (Future, isolate)
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[FirebaseService] Crashlytics setup skipped: $e');
        }
      }

      // Analytics instance'ı hazırla — auto screen tracking için
      analytics = FirebaseAnalytics.instance;

      // Misafir UID Firebase'den sonra başlat
      await AuthService.instance.initGuestUid().timeout(_pluginCallTimeout);

      // Oturum Firebase tarafından kalıcı tutulur. Android release/AAB'de native
      // auth state boş dönerse önce Google oturumunu sessizce geri yüklemeyi dene.
      // Daha önce bağlı hesap varsa anonim oturum açıp gerçek hesabın üstünü ezme.
      try {
        var user = AuthService.instance.currentUser ??
            await AuthService.instance
                .restorePersistedSession()
                .timeout(_authBootstrapTimeout, onTimeout: () => null);
        if (user == null &&
            !await AuthService.instance.hasRememberedAccount().timeout(
                  _pluginCallTimeout,
                  onTimeout: () => true,
                )) {
          user = await AuthService.instance
              .signInAnonymously()
              .timeout(_authBootstrapTimeout, onTimeout: () => null);
        }
        if (user != null) {
          await FirestoreService.instance
              .createUserIfNotExists(user)
              .timeout(_profileBootstrapTimeout);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[FirebaseService] user profile bootstrap failed: $e');
        }
      }
    } catch (e) {
      // google-services.json eksik veya network yok — offline modda devam et
      _initialized = false;
      if (kDebugMode) {
        debugPrint('[FirebaseService] init failed, running offline: $e');
      }
      // Firebase olmasa bile misafir UID hazırlansın
      try {
        await AuthService.instance.initGuestUid().timeout(_pluginCallTimeout);
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[FirebaseService] guest UID init also failed: $e2');
        }
      }
    }
  }
}
