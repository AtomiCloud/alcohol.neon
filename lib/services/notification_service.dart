import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../generated/zinc/models/habit_overview_habit_res.dart';

/// Schedules local habit reminders at each habit's `notificationTime`, on its
/// scheduled days. A core mobile feature the web app can't offer. Reminders are
/// rebuilt from the overview whenever it loads (cancel-all then reschedule), so
/// they always reflect the current habits.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to UTC if the platform can't report a timezone.
    }
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Asks for notification permission (prompts once on iOS). Safe to call repeatedly.
  Future<bool> requestPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Cancel and reschedule weekly reminders for the user's enabled habits.
  Future<void> syncHabits(List<HabitOverviewHabitRes> habits) async {
    await init();
    await _plugin.cancelAll();

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'habit_reminders',
        'Habit reminders',
        channelDescription: 'Daily reminders to do your habits',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    var id = 0;
    for (final h in habits) {
      if (!h.enabled) continue;
      final time = _parseTime(h.notificationTime);
      final days = h.days;
      if (time == null || days == null) continue;
      for (var d = 0; d < days.length && d < 7; d++) {
        if (!days[d]) continue;
        await _plugin.zonedSchedule(
          id++,
          h.name ?? 'Habit',
          'Time for your habit — keep the streak alive.',
          _nextInstanceOf(d, time.$1, time.$2),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Parses zinc's "HH:mm:ss" into (hour, minute).
  (int, int)? _parseTime(String? hhmmss) {
    if (hhmmss == null) return null;
    final parts = hhmmss.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  /// Next occurrence of day [d] (0=Sunday..6=Saturday, zinc/argon convention) at
  /// [hour]:[minute] in the local timezone.
  tz.TZDateTime _nextInstanceOf(int d, int hour, int minute) {
    // DateTime weekday: Mon=1..Sun=7. zinc's Sunday=0 → 7.
    final targetWeekday = d == 0 ? 7 : d;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != targetWeekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
