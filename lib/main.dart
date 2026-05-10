import 'package:flutter/material.dart';
import 'package:kurdle_app/app_theme.dart';
import 'package:kurdle_app/widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Peyvok',
        debugShowCheckedModeBanner: false,
        showSemanticsDebugger: false,
        theme: AppTheme.lightTheme,
        themeMode: mode,
        darkTheme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
