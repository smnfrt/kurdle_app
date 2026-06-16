import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus;
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/services/connectivity_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/haptic_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/notification_service.dart';
import 'package:kurdle_app/services/settings_service.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/services/word_validator_service.dart';
import 'package:kurdle_app/services/wordlist_loader.dart';

class AppWarmupService {
  AppWarmupService._();
  static final AppWarmupService instance = AppWarmupService._();

  Future<void>? _connectivityFuture;
  Future<void>? _runtimeFuture;
  Future<void>? _firebaseFuture;
  Future<void>? _wordGameFuture;
  Future<void>? _notificationPermissionFuture;

  Future<void> initConnectivity() {
    return _connectivityFuture ??= ConnectivityService.instance
        .init()
        .catchError((e) => debugPrint('Connectivity init failed: $e'));
  }

  Future<void> initRuntimeServices() {
    return _runtimeFuture ??= Future.wait([
      SoundService.instance.init().catchError((e) {
        debugPrint('SoundService init failed: $e');
      }),
      HapticService.instance.init().catchError((e) {
        debugPrint('HapticService init failed: $e');
      }),
    ]);
  }

  Future<void> initFirebaseServices() {
    return _firebaseFuture ??= FirebaseService.init().then((_) async {
      if (!FirebaseService.isAvailable) return;
      try {
        await NotificationService.instance.init();
        final settings = await SettingsService().load();
        if (settings.notifsEnabled) {
          await NotificationService.instance.syncFcmTokenToFirestore();
        }
      } catch (e) {
        debugPrint('NotificationService init failed: $e');
      }
    }).catchError((e) {
      debugPrint('FirebaseService init failed: $e');
    });
  }

  Future<void> preloadWordGame() {
    return _wordGameFuture ??=
        WordlistLoader.loadAssets(LanguageConfig.kurdish.wordAssets)
            .then((list) {
      WordValidatorService(list);
    }).catchError((e) {
      debugPrint('Wordlist preload failed: $e');
    });
  }

  Future<void> requestNotificationPermissionIfNeeded() {
    return _notificationPermissionFuture ??=
        initFirebaseServices().then((_) async {
      if (!FirebaseService.isAvailable) return;
      try {
        final settings = await SettingsService().load();
        if (!settings.notifsEnabled) return;
        final current =
            await NotificationService.instance.currentPermissionStatus();
        if (current != AuthorizationStatus.authorized &&
            current != AuthorizationStatus.denied) {
          await NotificationService.instance.requestNotificationPermission();
        }
        await NotificationService.instance.syncFcmTokenToFirestore();
      } catch (e) {
        debugPrint('Notification permission warm-up failed: $e');
      }
    });
  }

  void startHomeWarmups() {
    unawaited(initConnectivity());
    unawaited(initRuntimeServices());
    unawaited(initFirebaseServices());
    unawaited(preloadWordGame());
  }
}
