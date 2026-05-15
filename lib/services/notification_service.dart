import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'peyvok_daily';
  static const _channelName = 'Günlük Hatırlatıcı';

  // Bildirime tıklandığında ya da app kapalıyken açıldığında set edilir.
  String? pendingInviteRoomCode;
  final List<void Function(String roomCode)> _onInviteTap = [];

  void onInviteTap(void Function(String roomCode) cb) {
    _onInviteTap.add(cb);
    final pending = pendingInviteRoomCode;
    if (pending != null) {
      pendingInviteRoomCode = null;
      cb(pending);
    }
  }

  void offInviteTap(void Function(String roomCode) cb) {
    _onInviteTap.remove(cb);
  }

  void _dispatchInviteTap(String code) {
    if (_onInviteTap.isEmpty) {
      pendingInviteRoomCode = code;
    } else {
      for (final cb in List.of(_onInviteTap)) {
        cb(code);
      }
    }
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

    // Plugin başlat
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final code = resp.payload;
        if (code != null && code.isNotEmpty) _dispatchInviteTap(code);
      },
    );

    // App kapalıyken bildirime basıp açıldıysa, payload'ı bekleyen koda kaydet.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final code = launch?.notificationResponse?.payload;
      if (code != null && code.isNotEmpty) pendingInviteRoomCode = code;
    }

    // FCM izni iste
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Arka plan handler kaydet
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Ön planda gelen FCM mesajını local notification olarak göster
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
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
        ),
      );
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
    await _local.cancelAll();

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
    );

    try {
      await _local.zonedSchedule(
        0,
        'Peyvok 🟩',
        'Günün kelimesi hazır! Bugün kaç denemede bulacaksın?',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Tam zamanlı alarm izni yok — yaklaşık zamanlı ile devam et
      await _local.zonedSchedule(
        0,
        'Peyvok 🟩',
        'Günün kelimesi hazır! Bugün kaç denemede bulacaksın?',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
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
    );
    try {
      await _local.zonedSchedule(
        1,
        'Peyvok 🔥',
        'Streak\'ini koru — bugün bir oyun oyna!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      await _local.zonedSchedule(
        1,
        'Peyvok 🔥',
        'Streak\'ini koru — bugün bir oyun oyna!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Bugün için planlı streak hatırlatmasını iptal eder (kullanıcı bugün
  /// oynadıysa hatırlatma rahatsız etmesin).
  Future<void> cancelTodayStreakReminder() async {
    await _local.cancel(1);
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _local.zonedSchedule(
        1,
        '🏆 Turnuva Başlıyor!',
        '30 dakika sonra haftalık turnuva başlıyor. Hazır mısın?',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<String?> getFcmToken() => _fcm.getToken();

  Future<void> showInviteNotification({
    required String fromName,
    required String roomCode,
  }) async {
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
      ),
      payload: roomCode,
    );
  }
}
