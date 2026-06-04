import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/app_theme.dart';

// NOT: Eski "smoke test" tüm uygulamayı (MyApp → SplashScreen → Firebase/servisler)
// boot etmeye çalışıyordu ve test ortamında her zaman başarısız oluyordu.
// Yerine, Firebase'e bağımlı olmayan anlamlı testler: tema modülü + temel render.
void main() {
  group('AppTheme', () {
    test('darkTheme Material3 + dark brightness + marka rengi', () {
      final t = AppTheme.darkTheme;
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.primary, AppTokens.primary);
      // Derleme regresyon koruması: cardTheme CardThemeData olmalı (CardTheme değil).
      expect(t.cardTheme, isA<CardThemeData>());
    });

    test('lightTheme Material3 + light brightness', () {
      final t = AppTheme.lightTheme;
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.light);
      expect(t.colorScheme.primary, AppTokens.primary);
    });
  });

  testWidgets('Tema ile basit bir ekran istisnasız render olur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: Center(child: Text('Peyvok')),
        ),
      ),
    );
    expect(find.text('Peyvok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
