import 'package:firebase_messaging/firebase_messaging.dart';
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
    await _local.initialize(initSettings);

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

    // Günlük hatırlatıcıyı planla
    await scheduleDailyReminder();
  }

  // Her gün saat 09:00'da "Günün kelimesi hazır!" bildirimi
  Future<void> scheduleDailyReminder() async {
    await _local.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _local.zonedSchedule(
      0,
      'Peyvok 🟩',
      'Günün kelimesi hazır! Bugün kaç denemede bulacaksın?',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Turnuva başlamadan 30 dakika önce bildirim gönder
  Future<void> scheduleTournamentReminder(DateTime tournamentStart) async {
    final reminderTime = tournamentStart.subtract(const Duration(minutes: 30));
    if (reminderTime.isBefore(DateTime.now())) return;

    await _local.zonedSchedule(
      1,
      '🏆 Turnuva Başlıyor!',
      '30 dakika sonra haftalık turnuva başlıyor. Hazır mısın?',
      tz.TZDateTime.from(reminderTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<String?> getFcmToken() => _fcm.getToken();
}
