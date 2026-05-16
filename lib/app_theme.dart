import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global theme mode notifier — toggle dark/light without rebuilding the whole tree.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

/// Premium UI tokens — sahneye sinematik bir his ver.
class AppTokens {
  AppTokens._();
  // Background gradient (üstte hafif mavi, altta derin lacivert)
  static const bgTop = Color(0xFF0B121E);
  static const bgBottom = Color(0xFF050810);
  // Surface tonları
  static const surface1 = Color(0xFF111B2A);
  static const surface2 = Color(0xFF15202F);
  static const surface3 = Color(0xFF1B2738);
  // Border tonları
  static const border1 = Color(0x14FFFFFF); // 0.08
  static const border2 = Color(0x1FFFFFFF); // 0.12
  // Brand
  static const primary =
      Color(0xFF3FBE6F); // hafif daha yumuşak yeşil (eski 4CAF50'den)
  static const primaryGlow = Color(0xFF66E093);
  static const primaryDeep = Color(0xFF1B5E20);
  static const accentBlue = Color(0xFF6CC0F5);
  static const accentAmber = Color(0xFFFFD27A);
  static const accentDanger = Color(0xFFEF5350);
  // Metin
  static const textPrimary = Color(0xFFEDF1F8);
  static const textSecondary = Color(0xFFB7C0CD);
  static const textMuted = Color(0xFF7C8898);

  // Tipografi: heading bold için Manrope, gövde için Inter (Google Fonts via package).
  static TextTheme buildTextTheme(
    TextTheme base, {
    Color primaryText = textPrimary,
    Color secondaryText = textSecondary,
    Color mutedText = textMuted,
    bool stronger = false,
  }) {
    final body = GoogleFonts.interTextTheme(base);
    final manrope = GoogleFonts.manropeTextTheme(base);
    final titleWeight = stronger ? FontWeight.w800 : FontWeight.w700;
    final mediumTitleWeight = stronger ? FontWeight.w700 : FontWeight.w600;
    final bodyWeight = stronger ? FontWeight.w600 : FontWeight.w500;
    final labelWeight = stronger ? FontWeight.w800 : FontWeight.w700;
    return body.copyWith(
      displayLarge: manrope.displayLarge?.copyWith(
          fontWeight: FontWeight.w800, color: primaryText, letterSpacing: -0.6),
      displayMedium: manrope.displayMedium?.copyWith(
          fontWeight: FontWeight.w800, color: primaryText, letterSpacing: -0.4),
      displaySmall: manrope.displaySmall?.copyWith(
          fontWeight: FontWeight.w800, color: primaryText, letterSpacing: -0.3),
      headlineLarge: manrope.headlineLarge
          ?.copyWith(fontWeight: FontWeight.w800, color: primaryText),
      headlineMedium: manrope.headlineMedium
          ?.copyWith(fontWeight: titleWeight, color: primaryText),
      headlineSmall: manrope.headlineSmall
          ?.copyWith(fontWeight: titleWeight, color: primaryText),
      titleLarge: manrope.titleLarge?.copyWith(
          fontWeight: titleWeight, color: primaryText, letterSpacing: -0.2),
      titleMedium: manrope.titleMedium
          ?.copyWith(fontWeight: mediumTitleWeight, color: primaryText),
      titleSmall: body.titleSmall
          ?.copyWith(fontWeight: mediumTitleWeight, color: primaryText),
      bodyLarge:
          body.bodyLarge?.copyWith(color: primaryText, fontWeight: bodyWeight),
      bodyMedium: body.bodyMedium
          ?.copyWith(color: secondaryText, fontWeight: bodyWeight),
      bodySmall:
          body.bodySmall?.copyWith(color: mutedText, fontWeight: bodyWeight),
      labelLarge: body.labelLarge?.copyWith(
          color: primaryText, fontWeight: labelWeight, letterSpacing: 0.2),
      labelMedium: body.labelMedium
          ?.copyWith(color: secondaryText, fontWeight: mediumTitleWeight),
      labelSmall: body.labelSmall?.copyWith(
          color: mutedText, fontWeight: mediumTitleWeight, letterSpacing: 0.4),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const _bgDark = AppTokens.bgBottom;
  static const _surfaceDark = AppTokens.surface1;
  static const _primary = AppTokens.primary;

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
      color: Colors.white.withValues(alpha: 0.08),
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
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
    ),
    textTheme: AppTokens.buildTextTheme(Typography.whiteMountainView),
  );

  // Gündüz modu: yazı ölçüleri aynı kalır, yalnızca renk paleti aydınlanır.
  static const _bgLight = Color(0xFFE6EEF2);

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
      surface: const Color(0xFFF4F8FA),
      onSurface: const Color(0xFF1A1F2E),
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF4F8FA),
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
    textTheme: AppTokens.buildTextTheme(
      Typography.whiteMountainView,
      primaryText: const Color(0xFF172033),
      secondaryText: const Color(0xFF354456),
      mutedText: const Color(0xFF5D6A7A),
      stronger: true,
    ),
  );
}
