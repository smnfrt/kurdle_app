import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();

  // Mevcut oturum akışı — null ise giriş yapılmamış
  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // ── Anonim giriş ─────────────────────────────────────────────────
  // Uygulamayı ilk açan kullanıcılar otomatik anonim hesap alır.
  // Sonradan Google ile bağlanınca veriler kaybolmaz.
  Future<User?> signInAnonymously() async {
    try {
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
        final linked = await currentUser!.linkWithCredential(credential);
        return linked.user;
      }

      final cred = await _auth.signInWithCredential(credential);
      return cred.user;
    } on FirebaseAuthException catch (e) {
      _log('signInWithGoogle', e.code);
      return null;
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
        final emailCred = EmailAuthProvider.credential(
            email: email, password: password);
        cred = await currentUser!.linkWithCredential(emailCred);
      } else {
        cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
      }

      await cred.user?.updateDisplayName(displayName);
      return (user: cred.user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
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
      return (user: cred.user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    }
  }

  // ── Çıkış ────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
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
      case 'email-already-in-use':  return 'Bu e-posta zaten kullanımda.';
      case 'weak-password':         return 'Şifre en az 6 karakter olmalı.';
      case 'invalid-email':         return 'Geçersiz e-posta adresi.';
      case 'user-not-found':        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':        return 'Hatalı şifre.';
      case 'too-many-requests':     return 'Çok fazla deneme. Lütfen bekleyin.';
      case 'credential-already-in-use': return 'Bu hesap zaten başka bir kullanıcıya bağlı.';
      default: return 'Bir hata oluştu ($code).';
    }
  }

  void _log(String method, String code) {
    // ignore: avoid_print
    print('[AuthService] $method error: $code');
  }
}
