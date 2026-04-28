import 'package:firebase_core/firebase_core.dart';
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

      // Kullanıcı yoksa anonim giriş yap
      final user = await AuthService.instance.signInAnonymously();
      if (user != null) {
        await FirestoreService.instance.createUserIfNotExists(user);
      }
    } catch (e) {
      // google-services.json eksik veya network yok — offline modda devam et
      // ignore: avoid_print
      print('[FirebaseService] init failed, running offline: $e');
    }
  }
}
