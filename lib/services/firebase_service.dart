import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';

// Tek başlatma noktası. main.dart buradan çağırır.
class FirebaseService {
  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  /// Analytics observer'ı home/route widget'larında kullanmak için.
  /// init() çağrıldıktan sonra erişilebilir.
  static FirebaseAnalytics? analytics;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;

      // Crashlytics: debug'da kapalı, release'de açık. Kullanıcı
      // ayarlardan opt-out yapabilirse buradan toggle edilir.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      // Flutter framework error'larını otomatik raporla
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Async/platform error'larını da yakala (Future, isolate)
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Analytics instance'ı hazırla — auto screen tracking için
      analytics = FirebaseAnalytics.instance;

      // Misafir UID Firebase'den sonra başlat
      await AuthService.instance.initGuestUid();

      // Kullanıcı yoksa anonim giriş yap
      final user = await AuthService.instance.signInAnonymously();
      if (user != null) {
        await FirestoreService.instance.createUserIfNotExists(user);
      }
    } catch (e) {
      // google-services.json eksik veya network yok — offline modda devam et
      if (kDebugMode) debugPrint('[FirebaseService] init failed, running offline: $e');
      // Firebase olmasa bile misafir UID hazırlansın
      try {
        await AuthService.instance.initGuestUid();
      } catch (e2) {
        if (kDebugMode) debugPrint('[FirebaseService] guest UID init also failed: $e2');
      }
    }
  }
}
