import 'package:flutter/material.dart';
import 'package:kurdle_app/app_theme.dart';
import 'package:kurdle_app/services/settings_service.dart';
import 'package:kurdle_app/services/version_service.dart';
import 'package:kurdle_app/widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService().load();
  themeNotifier.value = settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  await VersionService.instance.loadVersion();
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
