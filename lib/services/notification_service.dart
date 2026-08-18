import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Arka planda gelen FCM mesajlarını işler (top-level fonksiyon olmalı)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase zaten başlatılmış olmalı — main.dart'ta FirebaseService.init() çağrılıyor
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Lazy: Firebase / native plugin'lere erişimi sadece ilk kullanımda dene
  // (test ortamı, offline mod, vb. için NotificationService.instance
  // erişimi tek başına Firebase init şart kılmasın).
  late final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'peyvok_daily';
  static const _channelName = 'Günlük Hatırlatıcı';
  static const _deviceIdKey = 'notification_device_id';
  static const dailyPayload = 'daily';
  static const streakPayload = 'streak';
  static const _turnReminderSlots = 4;

  // Bildirime tıklandığında ya da app kapalıyken açıldığında set edilir.
  String? pendingNotificationPayload;
  final List<void Function(String payload)> _onInviteTap = [];
  String? _foregroundRoomCode;

  void markRoomForeground(String roomCode) {
    _foregroundRoomCode = roomCode;
  }

  void clearRoomForeground(String roomCode) {
    if (_foregroundRoomCode == roomCode) {
      _foregroundRoomCode = null;
    }
  }

  int _turnReminderId(String roomCode, int slot) =>
      'turn-reminder-$roomCode-$slot'.hashCode;

  String _tokenPreview(String token, int length) {
    if (token.length <= length) return token;
    return '${token.substring(0, length)}...';
  }

  void _debugExactAlarmFallback(String reminderName, Object error) {
    if (kDebugMode) {
      debugPrint(
        '[INFO][NotificationService] exact $reminderName reminder unavailable; '
        'using inexact fallback ($error)',
      );
    }
  }

  void onInviteTap(void Function(String roomCode) cb) {
    _onInviteTap.add(cb);
    final pending = pendingNotificationPayload;
    if (pending != null) {
      pendingNotificationPayload = null;
      cb(pending);
    }
  }

  void offInviteTap(void Function(String roomCode) cb) {
    _onInviteTap.remove(cb);
  }

  void _dispatchInviteTap(String code) {
    if (_onInviteTap.isEmpty) {
      pendingNotificationPayload = code;
    } else {
      for (final cb in List.of(_onInviteTap)) {
        cb(code);
      }
    }
  }

  String? _payloadFromMessage(RemoteMessage message) {
    final action = message.data['action'] ?? message.data['type'];
    final inviteId = message.data['inviteId'];
    if (inviteId is String && inviteId.isNotEmpty) return 'invite:$inviteId';
    final code = message.data['roomCode'];
    if (code is String && code.isNotEmpty) return 'room:$code';
    if (action == dailyPayload) return dailyPayload;
    if (action == streakPayload) return streakPayload;
    return null;
  }

  String? _roomCodeFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    if (payload.startsWith('room:')) {
      final roomCode = payload.substring('room:'.length);
      return roomCode.isEmpty ? null : roomCode;
    }
    if (payload == dailyPayload ||
        payload == streakPayload ||
        payload.startsWith('invite:')) {
      return null;
    }
    // Eski sürümlerde ham roomCode payload olarak gönderiliyordu.
    return payload;
  }

  /// Kullanıcı bildirim açmak istediğinde (Settings toggle, streak ayarı vs.)
  /// çağrılır. iOS ve Android 13+ için runtime izin promptu gösterir.
  /// Permission status'u döner — UI'da toggle'ı buna göre kaydedebilir.
  Future<NotificationSettings> requestNotificationPermission() async {
    return _fcm.requestPermission(alert: true, badge: true, sound: true);
  }

  /// Mevcut izin durumunu kontrol et (prompt ETMEZ).
  Future<AuthorizationStatus> currentPermissionStatus() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<void> init() async {
    tz.initializeTimeZones();

    // Android bildirim kanalı
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Günlük kelime hatırlatmaları',
      importance: Importance.high,
    );

    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(androidChannel);
    await androidImpl?.requestNotificationsPermission();

    // Plugin başlat
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          _dispatchInviteTap(payload);
        }
      },
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // App kapalıyken bildirime basıp açıldıysa, payload'ı bekleyen koda kaydet.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingNotificationPayload = payload;
      }
    }

    // FCM permission burada İSTENMEZ — kullanıcı değer görmeden prompt etmek
    // dönüşümü düşürür. Ayarlardan toggle açıldığında veya streak kaydı sırasında
    // requestNotificationPermission() çağrılır.

    // Arka plan handler kaydet
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Ön planda gelen FCM mesajını local notification olarak göster
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final payload = _payloadFromMessage(message);
      final roomCode = _roomCodeFromPayload(payload);
      if (roomCode != null && roomCode == _foregroundRoomCode) return;
      _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = _payloadFromMessage(message);
      if (payload != null) _dispatchInviteTap(payload);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final payload = _payloadFromMessage(initialMessage);
      if (payload != null) pendingNotificationPayload = payload;
    }

    _fcm.onTokenRefresh.listen((_) {
      syncFcmTokenToFirestore();
    });

    // Günlük hatırlatıcıyı planla (planlama hata verirse uygulamayı kilitleme)
    try {
      await scheduleDailyReminder();
    } catch (e) {
      debugPrint('scheduleDailyReminder skipped: $e');
    }
    try {
      await scheduleStreakEveningReminder();
    } catch (e) {
      debugPrint('scheduleStreakEveningReminder skipped: $e');
    }
  }

  // Her gün saat 09:00'da "Günün kelimesi hazır!" bildirimi
  // Android 14'te tam zamanlı alarm izni verilmemişse yaklaşık zamanlı'ya düşer.
  Future<void> scheduleDailyReminder() async {
    await _local.cancel(0);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _local.zonedSchedule(
        0,
        'Leyar 🟩',
        'Günün kelimesi hazır! Bugün kaç denemede bulacaksın?',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: dailyPayload,
      );
    } catch (e) {
      _debugExactAlarmFallback('daily', e);
      // Tam zamanlı alarm izni yok — yaklaşık zamanlı ile devam et
      await _local.zonedSchedule(
        0,
        'Leyar 🟩',
        'Günün kelimesi hazır! Bugün kaç denemede bulacaksın?',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: dailyPayload,
      );
    }
  }

  /// Her akşam saat 19:00'da streak hatırlatma. Kullanıcı bugün oynamadıysa
  /// "Streak'in tehlikede!" bildirimi. matchDateTimeComponents.time ile
  /// idempotent günlük tekrar.
  Future<void> scheduleStreakEveningReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    try {
      await _local.zonedSchedule(
        1,
        'Leyar 🔥',
        'Streak\'ini koru — bugün bir oyun oyna!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: streakPayload,
      );
    } catch (e) {
      _debugExactAlarmFallback('streak', e);
      await _local.zonedSchedule(
        1,
        'Leyar 🔥',
        'Streak\'ini koru — bugün bir oyun oyna!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: streakPayload,
      );
    }
  }

  /// Bugün için planlı streak hatırlatmasını iptal eder (kullanıcı bugün
  /// oynadıysa hatırlatma rahatsız etmesin).
  Future<void> cancelTodayStreakReminder() async {
    await _local.cancel(1);
  }

  Future<void> cancelTurnReminders(String roomCode) async {
    for (var i = 0; i < _turnReminderSlots; i++) {
      await _local.cancel(_turnReminderId(roomCode, i));
    }
  }

  Future<void> scheduleTurnReminders({
    required String roomCode,
    required DateTime deadline,
    required int timeLimitSeconds,
  }) async {
    await cancelTurnReminders(roomCode);

    final now = DateTime.now();
    final total = Duration(seconds: timeLimitSeconds);
    final candidates = <Duration>[
      if (total > const Duration(hours: 2)) const Duration(hours: 1),
      if (total > const Duration(minutes: 30)) const Duration(minutes: 15),
      if (total > const Duration(minutes: 5)) const Duration(minutes: 5),
      if (total > const Duration(minutes: 1)) const Duration(minutes: 1),
      if (total <= const Duration(minutes: 5))
        Duration(seconds: (timeLimitSeconds / 2).floor().clamp(30, 180)),
    ];

    final reminderTimes = <DateTime>[];
    for (final beforeDeadline in candidates) {
      final at = deadline.subtract(beforeDeadline);
      if (at.isAfter(now.add(const Duration(seconds: 10))) &&
          at.isBefore(deadline)) {
        reminderTimes.add(at);
      }
    }
    reminderTimes.sort();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Hamle zamanı',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final uniqueTimes = <DateTime>[];
    for (final at in reminderTimes) {
      if (uniqueTimes.isEmpty ||
          at.difference(uniqueTimes.last).inSeconds.abs() > 30) {
        uniqueTimes.add(at);
      }
    }

    for (var i = 0; i < uniqueTimes.length && i < _turnReminderSlots; i++) {
      final at = uniqueTimes[i];
      final left = deadline.difference(at);
      final body = left.inHours >= 1
          ? 'Hamle yapman gerekiyor. Yaklaşık ${left.inHours} saat kaldı.'
          : left.inMinutes >= 1
              ? 'Hamle yapman gerekiyor. ${left.inMinutes} dakika kaldı.'
              : 'Hamle süren dolmak üzere.';
      final tzTime = tz.TZDateTime.from(at, tz.local);
      try {
        await _local.zonedSchedule(
          _turnReminderId(roomCode, i),
          'Sıra sende',
          body,
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'room:$roomCode',
        );
      } catch (e) {
        _debugExactAlarmFallback('turn', e);
        await _local.zonedSchedule(
          _turnReminderId(roomCode, i),
          'Sıra sende',
          body,
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'room:$roomCode',
        );
      }
    }
  }

  // Turnuva başlamadan 30 dakika önce bildirim gönder
  Future<void> scheduleTournamentReminder(DateTime tournamentStart) async {
    final reminderTime = tournamentStart.subtract(const Duration(minutes: 30));
    if (reminderTime.isBefore(DateTime.now())) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    try {
      await _local.zonedSchedule(
        1,
        '🏆 Turnuva Başlıyor!',
        '30 dakika sonra haftalık turnuva başlıyor. Hazır mısın?',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      _debugExactAlarmFallback('tournament', e);
      await _local.zonedSchedule(
        1,
        '🏆 Turnuva Başlıyor!',
        '30 dakika sonra haftalık turnuva başlıyor. Hazır mısın?',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<String?> getFcmToken() async {
    await _waitForApnsToken();
    return _fcm.getToken();
  }

  Future<String?> _waitForApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return null;
    }

    for (var i = 0; i < 5; i++) {
      final token = await _fcm.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[NotificationService] APNs token ready '
            '(${_tokenPreview(token, 8)})',
          );
        }
        return token;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (kDebugMode) {
      debugPrint('[NotificationService] APNs token not available yet');
    }
    return null;
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  /// Mevcut FCM token'ını signed-in kullanıcının Firestore dokümanına
  /// yazar (`users/{uid}.fcmToken`). Cloud Function bu alana göre
  /// rakip hamlesi push'u gönderir. Token değişirse periyodik tekrar
  /// çağrılmalı (`_fcm.onTokenRefresh` listener'a bağlanabilir).
  Future<void> syncFcmTokenToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _waitForApnsToken();
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;
      final deviceId = await _deviceId();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
          'fcmTokens': {deviceId: token},
          'fcmTokenPlatform': defaultTargetPlatform.name,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] FCM token synced '
          'platform=${defaultTargetPlatform.name} '
          'device=$deviceId token=${_tokenPreview(token, 12)}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] syncFcmTokenToFirestore failed: $e');
      }
    }
  }

  Future<void> showInviteNotification({
    required String fromName,
    required String roomCode,
  }) async {
    try {
      await _local.show(
        roomCode.hashCode,
        'Yeni Oyun Daveti 🎮',
        '$fromName seni oyuna davet etti',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'Davet',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: roomCode.startsWith('invite:') ? roomCode : 'invite:$roomCode',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] showInviteNotification failed: $e');
      }
    }
  }

  /// Multiplayer'da rakip hamle yapıp sıra sana geçtiğinde gösterilir.
  /// App'in foreground/background olduğu süre boyunca çalışır;
  /// uygulamanın tamamen kapalı olduğu durumda Cloud Function ile FCM
  /// push gerekir (henüz kurulmadı).
  Future<void> showOpponentMoveNotification({
    required String opponentName,
    required String roomCode,
    String? wordPlayed,
    int? score,
  }) async {
    final cleanWord = wordPlayed?.trim();
    final scoreText =
        score == null ? '' : ' (${score > 0 ? '+' : ''}$score puan)';
    final body = cleanWord != null && cleanWord.isNotEmpty
        ? '$opponentName "$cleanWord" oynadı$scoreText — sıra sende!'
        : '$opponentName hamlesini yaptı$scoreText — sıra sende!';
    try {
      await _local.show(
        'move-$roomCode'.hashCode,
        'Senin sıran 🎯',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'Hamle',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'room:$roomCode',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] showOpponentMoveNotification failed: $e');
      }
    }
  }
}
