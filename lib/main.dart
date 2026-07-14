import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kurdle_app/app_theme.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/services/app_warmup_service.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/settings_service.dart';
import 'package:kurdle_app/services/version_service.dart';
import 'package:kurdle_app/widgets/offline_banner.dart';
import 'package:kurdle_app/widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await _loadInitialSettings();
  themeNotifier.value = settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  L.set(settings.appLocale);
  unawaited(_loadVersionSafely());
  unawaited(AppWarmupService.instance.initConnectivity());
  runApp(const MyApp());
}

Future<Settings> _loadInitialSettings() async {
  try {
    return await SettingsService()
        .load()
        .timeout(const Duration(milliseconds: 700));
  } catch (e) {
    debugPrint('Initial settings load skipped: $e');
    return Settings(true, false, false, KeyboardLayout.qwerty,
        soundEnabled: true,
        hapticEnabled: true,
        notifsEnabled: true,
        ferhengDefinitionLanguage: AppLocale.tr,
        appLocale: AppLocale.ku,
        aiDifficulty: AiDifficulty.normal);
  }
}

Future<void> _loadVersionSafely() async {
  try {
    await VersionService.instance
        .loadVersion()
        .timeout(const Duration(milliseconds: 700));
  } catch (e) {
    debugPrint('Version load skipped: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: L.notifier,
      builder: (_, __, ___) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, mode, __) => MaterialApp(
          title: 'Peyvok',
          debugShowCheckedModeBanner: false,
          showSemanticsDebugger: false,
          theme: AppTheme.lightTheme,
          themeMode: mode,
          darkTheme: AppTheme.darkTheme,
          home: const SplashScreen(),
          builder: (context, child) =>
              OfflineBannerWrapper(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
