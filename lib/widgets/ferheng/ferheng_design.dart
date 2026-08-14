import 'package:flutter/material.dart';
import 'package:kurdle_app/app_theme.dart' show themeNotifier;

/// Ferheng UI'ında tutarlılık için ortak tokenlar.
///
/// Tüm renkler ve TextStyle'lar themeNotifier'a göre light/dark varyantı
/// döner. Field access (FerhengDesign.bg) çağıranlarda const gerek olmadığı
/// için getter pattern'i call site'ları bozmadan çalışır.
class FerhengDesign {
  // ── Dark palette (default — Leyar karanlık tema ile uyumlu) ──────
  static const Color _darkBg = Color(0xFF071018);
  static const Color _darkSurface = Color(0xFF121E2D);
  static const Color _darkSurfaceAlt = Color(0xFF17263A);
  static const Color _darkTextPrimary = Colors.white;
  static const Color _darkTextMuted = Color(0xFFB7C0CD);
  static const Color _darkTextFaint = Color(0xFF7C8898);
  static const Color _darkDivider = Color(0x1FFFFFFF);

  // ── Light palette (app light theme'iyle uyumlu) ───────────────────
  static const Color _lightBg = Color(0xFFF5F1E8);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceAlt = Color(0xFFEAF1F4);
  static const Color _lightTextPrimary = Color(0xFF18242C);
  static const Color _lightTextMuted = Color(0xFF52636E);
  static const Color _lightTextFaint = Color(0xFF8A969F);
  static const Color _lightDivider = Color(0x1F000000);

  // Tema-bağımsız ortak
  static const Color primary = Color(0xFF3FBE6F);
  static const Color primaryGlow = Color(0xFF66E093);
  static const Color accentGold = Color(0xFFFFD27A);
  static const Color accentBlue = Color(0xFF6CC0F5);

  // ── Theme-aware getters ──────────────────────────────────────────
  static bool get _isDark => themeNotifier.value == ThemeMode.dark;

  static bool get isDark => _isDark;

  static Color get bg => _isDark ? _darkBg : _lightBg;
  static Color get surface => _isDark ? _darkSurface : _lightSurface;
  static Color get surfaceAlt => _isDark ? _darkSurfaceAlt : _lightSurfaceAlt;
  static Color get textPrimary =>
      _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textMuted => _isDark ? _darkTextMuted : _lightTextMuted;
  static Color get textFaint => _isDark ? _darkTextFaint : _lightTextFaint;
  static Color get divider => _isDark ? _darkDivider : _lightDivider;
  static Color get border => _isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.08);
  static List<Color> get pageGradient => _isDark
      ? const [Color(0xFF111D2C), Color(0xFF071018)]
      : const [Color(0xFFFFFFFF), Color(0xFFF5F1E8)];

  // ── TextStyles (getter — runtime'da textColor'a göre) ────────────
  static TextStyle get titleLg => TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w800,
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
  'A',
  'B',
  'C',
  'Ç',
  'D',
  'E',
  'Ê',
  'F',
  'G',
  'H',
  'I',
  'Î',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'Ş',
  'T',
  'U',
  'Û',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];
