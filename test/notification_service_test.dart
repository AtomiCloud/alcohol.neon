import 'package:alcohol_neon/generated/zinc/models/habit_charity_ref_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_habit_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_status_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_version_meta_res.dart';
import 'package:alcohol_neon/generated/zinc/models/stake_res.dart';
import 'package:alcohol_neon/generated/zinc/models/week_status_res.dart';
import 'package:alcohol_neon/services/notification_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

HabitOverviewHabitRes habit({
  String? timezone = 'America/New_York',
  String? time = '09:00:00',
  int day = 0,
  bool enabled = true,
}) => HabitOverviewHabitRes(
  name: 'Read',
  timezone: timezone,
  notificationTime: time,
  days: List.generate(7, (index) => index == day),
  enabled: enabled,
  stake: const StakeRes(amount: 1),
  charity: const HabitCharityRefRes(),
  status: const HabitStatusRes(
    currentStreak: 0,
    maxStreak: 0,
    isCompleteToday: false,
    week: WeekStatusRes(),
  ),
  timeLeftToEodMinutes: 0,
  version: const HabitVersionMetaRes(version: 1, isActive: true),
);

/// The plugin rejects one-shot reminders before `clock.now()`, so pin its
/// clock to the same instant the service is given.
Future<void> syncAt(DateTime now, List<HabitOverviewHabitRes> habits) =>
    withClock(
      Clock.fixed(now),
      () => NotificationService(now: () => now).syncHabits(habits),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezoneChannel = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  List<Map<dynamic, dynamic>> schedules() => calls
      .where((call) => call.method == 'zonedSchedule')
      .map((call) => call.arguments as Map<dynamic, dynamic>)
      .toList();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(timezoneChannel, (call) async {
      expect(call.method, 'getLocalTimezone');
      return 'Asia/Tokyo';
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(timezoneChannel, null);
    debugDefaultTargetPlatformOverride = null;
    tz.setLocalLocation(tz.UTC);
  });

  test(
    'each habit uses its own zone and calendar date, not the device',
    () async {
      // Sunday in Tokyo, still Saturday in New York.
      await syncAt(DateTime.utc(2026, 1, 4, 1), [
        habit(day: 6),
        habit(timezone: 'Asia/Singapore'),
      ]);

      expect(tz.local.name, 'Asia/Tokyo');
      final emitted = schedules();
      expect(emitted, hasLength(2));
      expect(emitted[0]['timeZoneName'], 'America/New_York');
      expect(emitted[0]['scheduledDateTime'], '2026-01-10T09:00:00');
      expect(emitted[1]['timeZoneName'], 'Asia/Singapore');
      expect(emitted[1]['scheduledDateTime'], '2026-01-11T09:00:00');
      // One-shots (re-planned every sync), so a settled day can be skipped.
      for (final schedule in emitted) {
        expect(schedule['matchDateTimeComponents'], isNull);
      }
    },
  );

  for (final boundary in [
    (
      name: 'spring forward',
      now: DateTime.utc(2026, 3, 7, 15),
      wallTime: '2026-03-08T09:00:00',
      instant: DateTime.utc(2026, 3, 8, 13),
    ),
    (
      name: 'fall back',
      now: DateTime.utc(2026, 10, 31, 14),
      wallTime: '2026-11-01T09:00:00',
      instant: DateTime.utc(2026, 11, 1, 14),
    ),
  ]) {
    test('keeps habit wall time across ${boundary.name}', () async {
      await syncAt(boundary.now, [habit()]);

      final emitted = schedules().single;
      expect(emitted['timeZoneName'], 'America/New_York');
      expect(emitted['scheduledDateTime'], boundary.wallTime);
      expect(
        DateTime.parse(emitted['scheduledDateTimeISO8601'] as String).toUtc(),
        boundary.instant,
      );
    });
  }

  test(
    'an occurrence exactly now rolls to next week in the habit zone',
    () async {
      await syncAt(DateTime.utc(2026, 3, 1, 14), [habit()]);

      expect(schedules().single['scheduledDateTime'], '2026-03-08T09:00:00');
      expect(
        DateTime.parse(
          schedules().single['scheduledDateTimeISO8601'] as String,
        ).toUtc(),
        DateTime.utc(2026, 3, 8, 13),
      );
    },
  );

  test(
    'skips unusable or disabled reminders without blocking valid ones',
    () async {
      await syncAt(DateTime.utc(2026, 3, 7, 15), [
        habit(enabled: false),
        habit(time: null),
        habit(time: 'invalid'),
        habit(timezone: null),
        habit(timezone: 'not/an/iana/zone'),
        habit(),
      ]);

      expect(schedules(), hasLength(1));
      expect(schedules().single['id'], 0);
      expect(schedules().single['timeZoneName'], 'America/New_York');
    },
  );

  test(
    'debug notification still requests permission and presents foreground',
    () async {
      final service = NotificationService();
      await service.showNow(title: 'Debug', body: 'Hello');

      final init =
          calls.singleWhere((call) => call.method == 'initialize').arguments
              as Map;
      expect(init['requestAlertPermission'], isFalse);
      expect(init['requestBadgePermission'], isFalse);
      expect(init['requestSoundPermission'], isFalse);
      final permission =
          calls
                  .singleWhere((call) => call.method == 'requestPermissions')
                  .arguments
              as Map;
      expect(permission['alert'], isTrue);
      expect(permission['badge'], isTrue);
      expect(permission['sound'], isTrue);
      final shown =
          calls.singleWhere((call) => call.method == 'show').arguments as Map;
      expect(shown['id'], 999999);
      expect(shown['title'], 'Debug');
      expect(shown['body'], 'Hello');
      final details = shown['platformSpecifics'] as Map;
      for (final key in [
        'presentAlert',
        'presentBadge',
        'presentSound',
        'presentBanner',
      ]) {
        expect(details[key], isTrue);
      }
    },
  );
}
