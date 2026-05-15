import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/app_locale.dart';

const _kBg = Color(0xFF0F1923);
const _kSurface = Color(0xFF1A2533);
const _kPrimary = Color(0xFF4CAF50);
const _kGold = Color(0xFFFFD700);
const _kLightBgTop = Color(0xFFF4F8FA);
const _kLightBgBottom = Color(0xFFE6EEF2);
const _kLightSurface = Color(0xFFF4F8FA);
const _kLightText = Color(0xFF18242C);
const _kLightMuted = Color(0xFF52636E);

class AuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const AuthScreen({Key? key, required this.onSuccess}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _isLogin = true; // true=giriş, false=kayıt
  bool _loading = false;
  String _error = '';

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _finish() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    widget.onSuccess();
  }

  // ── Google ────────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final user = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    if (user != null) {
      try {
        await FirestoreService.instance.createUserIfNotExists(user);
      } catch (_) {}
      _finish();
    } else {
      setState(() {
        _error = 'Google girişi iptal edildi.';
        _loading = false;
      });
    }
  }

  // ── E-posta / şifre ───────────────────────────────────────────────
  Future<void> _emailAction() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'E-posta ve şifre boş olamaz.');
      return;
    }
    if (!_isLogin && name.isEmpty) {
      setState(() => _error = 'İsim boş olamaz.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });
    HapticFeedback.lightImpact();

    if (_isLogin) {
      final result = await AuthService.instance
          .signInWithEmail(email: email, password: pass);
      if (!mounted) return;
      if (result.error != null) {
        setState(() {
          _error = result.error!;
          _loading = false;
        });
      } else {
        _finish();
      }
    } else {
      final result = await AuthService.instance
          .registerWithEmail(email: email, password: pass, displayName: name);
      if (!mounted) return;
      if (result.error != null) {
        setState(() {
          _error = result.error!;
          _loading = false;
        });
      } else {
        if (result.user != null) {
          try {
            await FirestoreService.instance.createUserIfNotExists(result.user!);
          } catch (_) {}
        }
        _finish();
      }
    }
  }

  Future<void> _anonymousContinue() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    await AuthService.instance.signInAnonymously();
    if (!mounted) return;
    // Başarılı veya başarısız (anonymous auth kapalı) — her iki durumda da giriş yap
    _finish();
  }

  void _toggle() {
    setState(() {
      _isLogin = !_isLogin;
      _error = '';
    });
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : _kLightText;
    final bodyColor = isDark ? Colors.white.withOpacity(0.4) : _kLightMuted;
    final dividerColor =
        isDark ? Colors.white12 : const Color(0xFF74838C).withOpacity(0.55);
    final fieldIconColor = isDark ? Colors.white38 : const Color(0xFF4A5963);

    return Scaffold(
      backgroundColor: isDark ? _kBg : _kLightBgBottom,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [_kBg, Color(0xFF07101B)]
                  : const [_kLightBgTop, _kLightBgBottom],
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, top + 24, 24, bottom + 24),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // ── Logo ─────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _kPrimary.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('P',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      height: 1)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text('Peyvok',
                              style: TextStyle(
                                  color: titleColor,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(
                            L.appSubtitle,
                            style: TextStyle(color: bodyColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Başlık ───────────────────────────────────────
                    Text(
                      _isLogin ? 'Hoş Geldin' : 'Hesap Oluştur',
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? 'Devam etmek için giriş yap'
                          : 'Ücretsiz hesap oluştur',
                      style: TextStyle(color: bodyColor, fontSize: 13),
                    ),

                    const SizedBox(height: 28),

                    // ── Google butonu ────────────────────────────────
                    _GoogleBtn(onTap: _loading ? null : _googleSignIn),

                    const SizedBox(height: 18),

                    // ── Ayraç ────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                            child: Container(height: 1, color: dividerColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('veya',
                              style: TextStyle(
                                  color: bodyColor.withOpacity(0.85),
                                  fontSize: 12)),
                        ),
                        Expanded(
                            child: Container(height: 1, color: dividerColor)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── İsim (sadece kayıtta) ────────────────────────
                    if (!_isLogin) ...[
                      _Field(
                        controller: _nameCtrl,
                        label: 'İsim',
                        icon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── E-posta ──────────────────────────────────────
                    _Field(
                      controller: _emailCtrl,
                      label: 'E-posta',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),

                    // ── Şifre ────────────────────────────────────────
                    _Field(
                      controller: _passCtrl,
                      label: 'Şifre',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _emailAction(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: fieldIconColor,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),

                    // ── Şifremi unuttum ──────────────────────────────
                    if (_isLogin) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _showForgotPassword,
                          child: Text('Şifremi Unuttum',
                              style: TextStyle(
                                  color: _kPrimary.withOpacity(0.8),
                                  fontSize: 12)),
                        ),
                      ),
                    ],

                    // ── Hata mesajı ──────────────────────────────────
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFFF6B6B), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_error,
                                    style: const TextStyle(
                                        color: Color(0xFFFF6B6B),
                                        fontSize: 12))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Ana buton ────────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _emailAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade800,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Geçiş ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin
                              ? 'Hesabın yok mu?'
                              : 'Zaten hesabın var mı?',
                          style: TextStyle(color: bodyColor, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _toggle,
                          child: Text(
                            _isLogin ? 'Kayıt Ol' : 'Giriş Yap',
                            style: const TextStyle(
                                color: _kPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Misafir girişi ────────────────────────────────
                    GestureDetector(
                      onTap: _loading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _anonymousContinue();
                            },
                      child: AnimatedOpacity(
                        opacity: _loading ? 0.4 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFF9CABAD).withOpacity(0.75),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.25)
                                    : const Color(0xFF60717C)
                                        .withOpacity(0.55)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  color: titleColor.withOpacity(0.78),
                                  size: 18),
                              const SizedBox(width: 10),
                              Text(
                                'Misafir olarak devam et',
                                style: TextStyle(
                                  color: titleColor.withOpacity(0.82),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? _kSurface : _kLightSurface;
    final titleColor = isDark ? Colors.white : _kLightText;
    final bodyColor = isDark ? Colors.white.withOpacity(0.55) : _kLightMuted;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Şifre Sıfırla', style: TextStyle(color: titleColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('E-posta adresini gir, şifre sıfırlama bağlantısı gönderelim.',
                style: TextStyle(color: bodyColor, fontSize: 13)),
            const SizedBox(height: 14),
            _Field(
              controller: emailCtrl,
              label: 'E-posta',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal',
                style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.4)
                        : const Color(0xFF4F5E68))),
          ),
          ElevatedButton(
            onPressed: () async {
              final err = await AuthService.instance
                  .sendPasswordReset(emailCtrl.text.trim());
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err ?? 'Sıfırlama e-postası gönderildi!'),
                backgroundColor:
                    err != null ? Colors.red.shade800 : Colors.green.shade800,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }
}

// ── Google butonu ─────────────────────────────────────────────────

class _GoogleBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _GoogleBtn({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google "G" logosu
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: CustomPaint(painter: _GoogleGPainter()),
              ),
              const SizedBox(width: 12),
              const Text(
                'Google ile Giriş Yap',
                style: TextStyle(
                  color: Color(0xFF3C4043),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    void arc(double start, double sweep, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        start,
        sweep,
        false,
        paint,
      );
    }

    // Dört Google rengi yayı
    arc(-0.52, 1.57, const Color(0xFF4285F4)); // mavi (sağ + üst)
    arc(1.05, 1.57, const Color(0xFF34A853)); // yeşil (alt)
    arc(2.62, 0.79, const Color(0xFFFBBC05)); // sarı (sol alt)
    arc(3.41, 0.79, const Color(0xFFEA4335)); // kırmızı (sol üst)

    // Yatay çizgi (G'nin orta kolu)
    final hPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.72, cy),
      hPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter _) => false;
}

// ── Metin alanı ───────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _kLightText;
    final labelColor =
        isDark ? Colors.white.withOpacity(0.45) : const Color(0xFF53636D);
    final iconColor = isDark ? Colors.white38 : const Color(0xFF4A5963);
    final fillColor = isDark ? const Color(0xFF1A2535) : _kLightSurface;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFF6E7D86).withOpacity(0.55);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontSize: 13),
        prefixIcon: Icon(icon, color: iconColor, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
