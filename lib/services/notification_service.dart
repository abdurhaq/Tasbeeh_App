import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin plugin =
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

  // ── Notification details ───────────────────────────────────────────────────
  NotificationDetails get details => const NotificationDetails(
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

  // ── Initialize ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final offset = DateTime.now().timeZoneOffset;
      final totalMinutes = offset.inMinutes;

      const Map<int, String> offsetToTimezone = {
        -720: 'Pacific/Auckland',
        -660: 'Pacific/Pago_Pago',
        -600: 'Pacific/Honolulu',
        -570: 'Pacific/Marquesas',
        -480: 'America/Los_Angeles',
        -420: 'America/Denver',
        -360: 'America/Chicago',
        -300: 'America/New_York',
        -240: 'America/Halifax',
        -210: 'America/St_Johns',
        -180: 'America/Sao_Paulo',
        -120: 'Atlantic/South_Georgia',
        -60:  'Atlantic/Azores',
        0:    'Europe/London',
        60:   'Europe/Paris',
        120:  'Europe/Helsinki',
        180:  'Europe/Moscow',
        210:  'Asia/Tehran',
        240:  'Asia/Dubai',
        270:  'Asia/Kabul',
        300:  'Asia/Karachi',
        330:  'Asia/Kolkata',
        345:  'Asia/Kathmandu',
        360:  'Asia/Dhaka',
        390:  'Asia/Rangoon',
        420:  'Asia/Bangkok',
        480:  'Asia/Shanghai',
        525:  'Australia/Eucla',
        540:  'Asia/Tokyo',
        570:  'Australia/Adelaide',
        600:  'Australia/Sydney',
        630:  'Pacific/Norfolk',
        660:  'Pacific/Noumea',
        720:  'Pacific/Auckland',
        765:  'Pacific/Chatham',
        780:  'Pacific/Apia',
        840:  'Pacific/Kiritimati',
      };

      final tzName = offsetToTimezone[totalMinutes] ?? 'UTC';
      tz.setLocalLocation(tz.getLocation(tzName));
      print('✅ Timezone set: $tzName');

    } catch (e) {
      print('❌ Timezone error: $e — using UTC');
      tz.setLocalLocation(tz.UTC);
    }

    final android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
    );
  }

  // ── Request permissions ────────────────────────────────────────────────────
  //Future<void> requestPermissions() async {
  //  final android = plugin
  //      .resolvePlatformSpecificImplementation
  //  AndroidFlutterLocalNotificationsPlugin
  //      >();
  //  await android?.requestExactAlarmsPermission();
  //  await android?.requestNotificationsPermission();
  //}

  // ── Schedule a daily notification ──────────────────────────────────────────
  Future<void> scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
  }) async {
    final message = await _getNextMessage();

    await plugin.zonedSchedule(
      id,
      '📿 Time for Tasbeeh',
      message,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Cancel a notification ──────────────────────────────────────────────────
  Future<void> cancelNotification(int id) async {
    await plugin.cancel(id);
  }

  // ── Cancel all ────────────────────────────────────────────────────────────
  Future<void> cancelAll() async {
    await plugin.cancelAll();
  }

  Future<String> _getNextMessage() async {
    final prefs = await SharedPreferences.getInstance();

    int index = prefs.getInt('notif_message_index') ?? 0;

    List<int> order;
    final raw = prefs.getStringList('notif_message_order');

    if (raw == null || raw.length != messages.length) {
      order = List.generate(messages.length, (i) => i);
      order.shuffle(Random());
      await prefs.setStringList(
        'notif_message_order',
        order.map((e) => e.toString()).toList(),
      );
      index = 0;
    } else {
      order = raw.map((e) => int.parse(e)).toList();
    }

    final message = messages[order[index]];

    index++;
    if (index >= messages.length) {
      index = 0;
      order.shuffle(Random());
      await prefs.setStringList(
        'notif_message_order',
        order.map((e) => e.toString()).toList(),
      );
    }

    await prefs.setInt('notif_message_index', index);
    return message;
  }

  // ── Helper ────────────────────────────────────────────────────────────────
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