import 'package:flutter/material.dart';

/// Ferheng UI'ında tutarlılık için ortak tokenlar.
class FerhengDesign {
  static const Color bg          = Color(0xFF0D1520);
  static const Color surface     = Color(0xFF1B2738);
  static const Color surfaceAlt  = Color(0xFF22324A);
  static const Color primary     = Color(0xFF66E093);
  static const Color textPrimary = Colors.white;
  static const Color textMuted   = Colors.white70;
  static const Color textFaint   = Colors.white38;
  static const Color divider     = Color(0x1FFFFFFF);

  static const TextStyle titleLg = TextStyle(
    color: textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static const TextStyle titleMd = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyMd = TextStyle(
    color: textPrimary,
    fontSize: 15,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
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
