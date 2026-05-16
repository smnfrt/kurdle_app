import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';

// Tek başlatma noktası. main.dart buradan çağırır.
class FirebaseService {
  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;

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
