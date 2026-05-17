import 'package:flutter/material.dart';
import 'package:kurdle_app/app_theme.dart' show themeNotifier;

/// Ferheng UI'ında tutarlılık için ortak tokenlar.
///
/// Tüm renkler ve TextStyle'lar themeNotifier'a göre light/dark varyantı
/// döner. Field access (FerhengDesign.bg) çağıranlarda const gerek olmadığı
/// için getter pattern'i call site'ları bozmadan çalışır.
class FerhengDesign {
  // ── Dark palette (default — Peyvok karanlık tema ile uyumlu) ──────
  static const Color _darkBg          = Color(0xFF0D1520);
  static const Color _darkSurface     = Color(0xFF1B2738);
  static const Color _darkSurfaceAlt  = Color(0xFF22324A);
  static const Color _darkTextPrimary = Colors.white;
  static const Color _darkTextMuted   = Colors.white70;
  static const Color _darkTextFaint   = Colors.white38;
  static const Color _darkDivider     = Color(0x1FFFFFFF);

  // ── Light palette (app light theme'iyle uyumlu) ───────────────────
  static const Color _lightBg          = Color(0xFFE6EEF2);
  static const Color _lightSurface     = Color(0xFFF4F8FA);
  static const Color _lightSurfaceAlt  = Color(0xFFE2EAF0);
  static const Color _lightTextPrimary = Color(0xFF18242C);
  static const Color _lightTextMuted   = Color(0xFF52636E);
  static const Color _lightTextFaint   = Color(0xFF8A969F);
  static const Color _lightDivider     = Color(0x1F000000);

  // Tema-bağımsız ortak
  static const Color primary = Color(0xFF66E093);

  // ── Theme-aware getters ──────────────────────────────────────────
  static bool get _isDark => themeNotifier.value == ThemeMode.dark;

  static Color get bg          => _isDark ? _darkBg          : _lightBg;
  static Color get surface     => _isDark ? _darkSurface     : _lightSurface;
  static Color get surfaceAlt  => _isDark ? _darkSurfaceAlt  : _lightSurfaceAlt;
  static Color get textPrimary => _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textMuted   => _isDark ? _darkTextMuted   : _lightTextMuted;
  static Color get textFaint   => _isDark ? _darkTextFaint   : _lightTextFaint;
  static Color get divider     => _isDark ? _darkDivider     : _lightDivider;

  // ── TextStyles (getter — runtime'da textColor'a göre) ────────────
  static TextStyle get titleLg => TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      );

  static TextStyle get titleMd => TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get bodyMd => TextStyle(
        color: textPrimary,
        fontSize: 15,
        height: 1.4,
      );

  static TextStyle get caption => TextStyle(
        color: textMuted,
        fontSize: 13,
      );

  static const BorderRadius radSm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radMd = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radLg = BorderRadius.all(Radius.circular(20));
}

/// Kurmancî alfabe sırası — letter grid'lerde ve seçicilerde kullanılır.
const List<String> kKurmanjiAlphabet = [
  'A', 'B', 'C', 'Ç', 'D', 'E', 'Ê', 'F', 'G', 'H',
  'I', 'Î', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q',
  'R', 'S', 'Ş', 'T', 'U', 'Û', 'V', 'W', 'X', 'Y', 'Z',
];
