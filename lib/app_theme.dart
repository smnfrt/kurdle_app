import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global theme mode notifier — toggle dark/light without rebuilding the whole tree.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

/// Premium UI tokens — sahneye sinematik bir his ver.
class AppTokens {
  AppTokens._();
  // Background gradient (üstte hafif mavi, altta derin lacivert)
  static const bgTop    = Color(0xFF0B121E);
  static const bgBottom = Color(0xFF050810);
  // Surface tonları
  static const surface1 = Color(0xFF111B2A);
  static const surface2 = Color(0xFF15202F);
  static const surface3 = Color(0xFF1B2738);
  // Border tonları
  static const border1  = Color(0x14FFFFFF); // 0.08
  static const border2  = Color(0x1FFFFFFF); // 0.12
  // Brand
  static const primary       = Color(0xFF3FBE6F); // hafif daha yumuşak yeşil (eski 4CAF50'den)
  static const primaryGlow   = Color(0xFF66E093);
  static const primaryDeep   = Color(0xFF1B5E20);
  static const accentBlue    = Color(0xFF6CC0F5);
  static const accentAmber   = Color(0xFFFFD27A);
  static const accentDanger  = Color(0xFFEF5350);
  // Metin
  static const textPrimary   = Color(0xFFEDF1F8);
  static const textSecondary = Color(0xFFB7C0CD);
  static const textMuted     = Color(0xFF7C8898);

  // Tipografi: heading bold için Manrope, gövde için Inter (Google Fonts via package).
  static TextTheme buildTextTheme(TextTheme base) {
    final body = GoogleFonts.interTextTheme(base);
    final manrope = GoogleFonts.manropeTextTheme(base);
    return body.copyWith(
      displayLarge:  manrope.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.6),
      displayMedium: manrope.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.4),
      displaySmall:  manrope.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.3),
      headlineLarge: manrope.headlineLarge?.copyWith(fontWeight: FontWeight.w800, color: textPrimary),
      headlineMedium: manrope.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
      headlineSmall: manrope.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge:    manrope.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
      titleMedium:   manrope.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall:    body.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge:  body.bodyLarge?.copyWith(color: textPrimary,   fontWeight: FontWeight.w500),
      bodyMedium: body.bodyMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w500),
      bodySmall:  body.bodySmall?.copyWith(color: textMuted,      fontWeight: FontWeight.w500),
      labelLarge: body.labelLarge?.copyWith(color: textPrimary,   fontWeight: FontWeight.w700, letterSpacing: 0.2),
      labelMedium: body.labelMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w600),
      labelSmall:  body.labelSmall?.copyWith(color: textMuted,    fontWeight: FontWeight.w600, letterSpacing: 0.4),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const _bgDark      = AppTokens.bgBottom;
  static const _surfaceDark = AppTokens.surface1;
  static const _primary     = AppTokens.primary;

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bgDark,
    colorScheme: ColorScheme.dark(
      brightness: Brightness.dark,
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF1B5E20),
      onPrimaryContainer: const Color(0xFFA5D6A7),
      secondary: const Color(0xFF64B5F6),
      onSecondary: const Color(0xFF0D1B2E),
      surface: _surfaceDark,
      onSurface: Colors.white,
      error: const Color(0xFFEF5350),
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F1923),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white70),
    ),
    cardTheme: CardTheme(
      color: _surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    dividerTheme: DividerThemeData(
      color: Colors.white.withOpacity(0.08),
      thickness: 1,
      space: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1E2A3A),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF141E2B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
    ),
    textTheme: AppTokens.buildTextTheme(Typography.whiteMountainView),
  );

  // Gündüz modu: sadece arka plan açık ton — kartlar/widgetlar koyu kalır
  static const _bgLight = Color(0xFFE8EDF6); // soğuk gri-mavi, kağıt gibi

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _bgLight,
    colorScheme: ColorScheme.light(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFC8E6C9),
      onPrimaryContainer: const Color(0xFF1B5E20),
      secondary: const Color(0xFF1976D2),
      onSecondary: Colors.white,
      surface: _bgLight,
      onSurface: const Color(0xFF1A1F2E),
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _bgLight,
      foregroundColor: const Color(0xFF1A1F2E),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: const TextStyle(
        color: Color(0xFF1A1F2E),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF3A4460)),
    ),
  );
}
