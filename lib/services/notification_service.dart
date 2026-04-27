import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  // ── Islamic messages ───────────────────────────────────────────────────────
  static const List<String> messages = [
    "The remembrance of Allah brings peace to the heart. 🕌",
    "A moment of dhikr is never wasted. SubhanAllah.",
    "Your Tasbeeh is waiting. Take a moment for Allah. 📿",
    "Whoever says SubhanAllah 100 times, his sins are forgiven. 🌿",
    "The best dhikr is La ilaha illallah. Don't forget Allah today.",
    "A tongue moist with the remembrance of Allah is a blessed tongue. 🤲",
    "Even a moment of dhikr outweighs the whole world. Start now.",
    "Allah is Al-Wadud — the Most Loving. Remember Him today. ❤️",
    "Don't let the day pass without your Tasbeeh. 📿",
    "SubhanAllah, Alhamdulillah, Allahu Akbar — three words, infinite reward.",
  ];

  // ── Initialize ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  // ── Request permissions ────────────────────────────────────────────────────
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // ── Notification details ───────────────────────────────────────────────────
  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      'tasbeeh_channel',
      'Tasbeeh Reminders',
      channelDescription: 'Daily dhikr reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // ── Schedule a daily notification ──────────────────────────────────────────
  Future<void> scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
  }) async {
    final message = messages[id % messages.length];

    await _plugin.zonedSchedule(
      id,
      '📿 Time for Tasbeeh',
      message,
      _nextInstanceOfTime(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Cancel a notification ──────────────────────────────────────────────────
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  // ── Cancel all notifications ───────────────────────────────────────────────
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Helper: next instance of a time ───────────────────────────────────────
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}