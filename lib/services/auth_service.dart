import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _lastAuthProviderKey = 'last_auth_provider';
  static const _providerGoogle = 'google';
  static const _providerEmail = 'email';

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final _google = GoogleSignIn();

  String? _guestUid;

  // Mevcut oturum akışı — null ise giriş yapılmamış
  Stream<User?> get userStream => _auth.authStateChanges();
  // FirebaseAuth.instance Firebase init edilmemişse fırlatır. Test ortamı
  // ve offline cold-start için null'a düş — caller code zaten null'ı yönetir.
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // Firebase kullanıcısı yoksa kalıcı misafir UID kullan
  String? get effectiveUid => currentUser?.uid ?? _guestUid;
  String get effectiveDisplayName {
    final n = currentUser?.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final firebaseUid = currentUser?.uid;
    if (firebaseUid != null && firebaseUid.length >= 4) {
      return L.guestName(firebaseUid.substring(firebaseUid.length - 4));
    }
    if (_guestUid != null) {
      return L.guestName(_guestUid!.substring(_guestUid!.length - 4));
    }
    return L.guestBadge;
  }

  Future<void> initGuestUid() async {
    if (_guestUid != null) return;
    final prefs = await SharedPreferences.getInstance();
    _guestUid = prefs.getString('guest_uid');
    if (_guestUid == null) {
      _guestUid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('guest_uid', _guestUid!);
    }
  }

  // ── Anonim giriş ─────────────────────────────────────────────────
  // Uygulamayı ilk açan kullanıcılar otomatik anonim hesap alır.
  // Sonradan Google ile bağlanınca veriler kaybolmaz.
  Future<User?> signInAnonymously() async {
    try {
      final existing = currentUser;
      if (existing != null) return existing;
      final cred = await _auth.signInAnonymously();
      return cred.user;
    } on FirebaseAuthException catch (e) {
      _log('signInAnonymously', e.code);
      return null;
    }
  }

  // ── Google ile giriş ─────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return null; // kullanıcı iptal etti

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Anonim hesap varsa ona bağla, yoksa yeni hesap oluştur
      if (isAnonymous && currentUser != null) {
        try {
          final linked = await currentUser!.linkWithCredential(credential);
          // Linking displayName/photoURL'i otomatik MERGE etmez —
          // anonymous'tan miras kalan "Misafir XYZA" adı kalır. Google
          // profilinden explicit yansıt.
          await _applyGoogleProfileToUser(linked.user, googleUser);
          await _rememberAuthProvider(_providerGoogle);
          return linked.user;
        } on FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use' &&
              e.code != 'email-already-in-use') {
            rethrow;
          }
          // Hesap zaten var — anonim oturumu kapat, direkt giriş yap
          await _auth.signOut();
        }
      }

      final cred = await _auth.signInWithCredential(credential);
      // Yeni giriş (fresh sign-in) Firebase Auth zaten Google profilini
      // map'ler ama emin olmak için aynı yardımcıyı çağır (idempotent).
      await _applyGoogleProfileToUser(cred.user, googleUser);
      await _rememberAuthProvider(_providerGoogle);
      return cred.user;
    } catch (e) {
      _log('signInWithGoogle', e.toString());
      return null;
    }
  }

  /// Firebase Auth normalde native persistence ile kullanıcıyı korur. Bazı
  /// Android release/AAB kurulumlarında bu state boş dönerse, Google oturumunu
  /// sessizce tekrar Firebase credential'a çevirerek hesabı geri yükle.
  Future<User?> restorePersistedSession() async {
    final existing = currentUser;
    if (existing != null) return existing;

    final provider = await _lastAuthProvider();
    if (provider != _providerGoogle) return null;

    try {
      final googleUser = await _google.signInSilently();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await _applyGoogleProfileToUser(cred.user, googleUser);
      await _rememberAuthProvider(_providerGoogle);
      return cred.user;
    } catch (e) {
      _log('restorePersistedSession', e.toString());
      return null;
    }
  }

  Future<bool> hasRememberedAccount() async {
    final provider = await _lastAuthProvider();
    return provider == _providerGoogle || provider == _providerEmail;
  }

  /// Google profilini Firebase Auth user'ına yansıt — link sonrası
  /// anonymous'tan kalan "Misafir XYZA" adını Google'ın gerçek
  /// adıyla değiştirir. Idempotent: zaten doğruysa no-op.
  Future<void> _applyGoogleProfileToUser(
    User? user,
    GoogleSignInAccount googleUser,
  ) async {
    if (user == null) return;
    final googleName = googleUser.displayName?.trim();
    final googlePhoto = googleUser.photoUrl?.trim();
    final isAuto = (user.displayName ?? '').startsWith('Misafir ') ||
        (user.displayName ?? '').startsWith('Mêvan ') ||
        (user.displayName ?? '').trim().isEmpty;
    try {
      if (googleName != null &&
          googleName.isNotEmpty &&
          (isAuto || user.displayName != googleName)) {
        await user.updateDisplayName(googleName);
      }
      if (googlePhoto != null &&
          googlePhoto.isNotEmpty &&
          (user.photoURL == null || user.photoURL!.isEmpty)) {
        await user.updatePhotoURL(googlePhoto);
      }
      await user.reload();
    } catch (e) {
      _log('applyGoogleProfile', e.toString());
    }
  }

  // ── E-posta / şifre kaydı ─────────────────────────────────────────
  Future<({User? user, String? error})> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      late UserCredential cred;

      if (isAnonymous && currentUser != null) {
        final emailCred =
            EmailAuthProvider.credential(email: email, password: password);
        cred = await currentUser!.linkWithCredential(emailCred);
      } else {
        cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
      }

      await cred.user?.updateDisplayName(displayName);
      await _rememberAuthProvider(_providerEmail);
      return (user: cred.user, error: null);
    } on FirebaseAuthException catch (e) {
      _log('registerWithEmail', '${e.code}: ${e.message}');
      return (user: null, error: _friendlyError(e.code));
    } catch (e) {
      _log('registerWithEmail', e.toString());
      return (user: null, error: 'Kayıt sırasında hata: $e');
    }
  }

  // ── E-posta / şifre ile giriş ────────────────────────────────────
  Future<({User? user, String? error})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _rememberAuthProvider(_providerEmail);
      return (user: cred.user, error: null);
    } on FirebaseAuthException catch (e) {
      _log('signInWithEmail', '${e.code}: ${e.message}');
      return (user: null, error: _friendlyError(e.code));
    } catch (e) {
      _log('signInWithEmail', e.toString());
      return (user: null, error: 'Giriş sırasında hata: $e');
    }
  }

  // ── Çıkış ────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
    await _clearRememberedAuthProvider();
  }

  // ── E-posta doğrulama gönder ─────────────────────────────────────
  Future<String?> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) return 'Önce giriş yapmalısınız.';
    if (user.emailVerified) return null;
    try {
      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      _log('sendEmailVerification', '${e.code}: ${e.message}');
      return _friendlyError(e.code);
    } catch (e) {
      _log('sendEmailVerification', e.toString());
      return 'Doğrulama maili gönderilemedi.';
    }
  }

  Future<bool> reloadAndCheckVerified() async {
    final user = currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      return currentUser?.emailVerified ?? false;
    } catch (e) {
      _log('reloadAndCheckVerified', e.toString());
      return user.emailVerified;
    }
  }

  // ── Şifre sıfırlama ──────────────────────────────────────────────
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanımda.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre.';
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen bekleyin.';
      case 'credential-already-in-use':
        return 'Bu hesap zaten başka bir kullanıcıya bağlı.';
      case 'operation-not-allowed':
        return 'E-posta ile giriş şu an kapalı. Lütfen Google ile giriş yapın.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      default:
        return 'Bir hata oluştu ($code).';
    }
  }

  void _log(String method, String code) {
    if (kDebugMode) debugPrint('[AuthService] $method error: $code');
  }

  Future<String?> _lastAuthProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastAuthProviderKey);
  }

  Future<void> _rememberAuthProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAuthProviderKey, provider);
  }

  Future<void> _clearRememberedAuthProvider() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastAuthProviderKey);
  }
}
