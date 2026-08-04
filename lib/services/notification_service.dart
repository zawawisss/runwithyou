import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
    );

    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a one-time notification. Returns notification id or -1 if skipped.
  static Future<int> scheduleTaskNotification({
    required String title,
    required String body,
    required int hour,
    required int minute,
    int advanceMinutes = 15,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime.local(
      now.year, now.month, now.day,
      hour, minute - advanceMinutes,
    );

    if (scheduledDate.isBefore(now)) return -1;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Pengingat Tugas',
          channelDescription: 'Notifikasi pengingat tugas dan jadwal',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    return id;
  }

  /// Schedule a daily recurring notification.
  static Future<int> scheduleDailyNotification({
    required String title,
    required String body,
    required int hour,
    required int minute,
    int advanceMinutes = 15,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime.local(
      now.year, now.month, now.day,
      hour, minute - advanceMinutes,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Pengingat Tugas',
          channelDescription: 'Notifikasi pengingat tugas dan jadwal',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    return id;
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
