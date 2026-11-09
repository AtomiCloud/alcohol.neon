import 'package:alcohol_neon/generated/zinc/models/habit_charity_ref_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_habit_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_status_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_version_meta_res.dart';
import 'package:alcohol_neon/generated/zinc/models/stake_res.dart';
import 'package:alcohol_neon/generated/zinc/models/week_status_res.dart';
import 'package:alcohol_neon/services/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Which one-shot reminders get scheduled, given the server's today status:
/// settled habits lose today's reminder but keep later days.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  const everyDay = [true, true, true, true, true, true, true];

  HabitOverviewHabitRes habit({
    String id = 'h1',
    bool enabled = true,
    String? time = '09:00:00',
    List<bool>? days = everyDay,
    String? timezone = 'Asia/Singapore',
    bool doneToday = false,
    String? today = '15-06-2026',
    String? todayStatus = 'not_applicable',
  }) => HabitOverviewHabitRes(
    id: id,
    name: id,
    notificationTime: time,
    days: days,
    timezone: timezone,
    stake: const StakeRes(amount: 1),
    enabled: enabled,
    charity: const HabitCharityRefRes(),
    status: HabitStatusRes(
      currentStreak: 0,
      maxStreak: 0,
      isCompleteToday: doneToday,
      week: const WeekStatusRes(),
      today: today,
      todayStatus: todayStatus,
    ),
    timeLeftToEodMinutes: 0,
    version: const HabitVersionMetaRes(version: 1, isActive: true),
  );

  // Monday 15 June 2026, 08:00 in Singapore (UTC+8) — before 09:00 reminders.
  final monday8am = DateTime.utc(2026, 6, 15, 0);

  List<String> wallTimes(List<PlannedReminder> plan) => [
    for (final r in plan) r.at.toIso8601String().substring(0, 16),
  ];

  String day(int d) => '2026-06-${d.toString().padLeft(2, '0')}T09:00';

  test('open habit: the next 7 days, in the habit zone', () {
    final plan = planReminders([habit()], now: monday8am);
    expect(wallTimes(plan), [for (var d = 15; d < 22; d++) day(d)]);
    expect(plan.first.at.location.name, 'Asia/Singapore');
  });

  for (final status in ['succeeded', 'skip', 'frozen', 'vacation', 'failed']) {
    test('settled today ($status): no reminder today, future days kept', () {
      final plan = planReminders([habit(todayStatus: status)], now: monday8am);
      expect(wallTimes(plan), [for (var d = 16; d < 22; d++) day(d)]);
    });
  }

  test('isCompleteToday alone also settles today', () {
    final plan = planReminders([
      habit(doneToday: true, todayStatus: null),
    ], now: monday8am);
    expect(wallTimes(plan).first, day(16));
    expect(plan, hasLength(6));
  });

  test('not_applicable, missing or unknown status stays open', () {
    for (final status in ['not_applicable', null, 'pending']) {
      final plan = planReminders([habit(todayStatus: status)], now: monday8am);
      expect(wallTimes(plan).first, day(15), reason: '$status');
    }
  });

  test('override (acknowledged action) settles today', () {
    final plan = planReminders(
      [habit()],
      now: monday8am,
      todayStatus: (_) => 'succeeded',
    );
    expect(wallTimes(plan).first, day(16));
  });

  test('settled day follows the server date, not the zone clock', () {
    // Server already resolved "today" as Tuesday: Monday stays open.
    final plan = planReminders([
      habit(today: '16-06-2026', todayStatus: 'succeeded'),
    ], now: monday8am);
    expect(wallTimes(plan).take(2), [day(15), day(17)]);
  });

  test('time already past today → next 7 days start tomorrow', () {
    final plan = planReminders([
      habit(),
    ], now: DateTime.utc(2026, 6, 15, 1, 30));
    expect(wallTimes(plan), [for (var d = 16; d < 23; d++) day(d)]);
  });

  test('weekly habit past today still gets next week', () {
    // Monday-only, now Monday 09:30 Singapore.
    final plan = planReminders([
      habit(days: const [false, true, false, false, false, false, false]),
    ], now: DateTime.utc(2026, 6, 15, 1, 30));
    expect(wallTimes(plan), [day(22)]);
  });

  test('only scheduled days (Sunday=0 index)', () {
    // Mon, Wed, Fri.
    final plan = planReminders([
      habit(days: const [false, true, false, true, false, true, false]),
    ], now: monday8am);
    expect(wallTimes(plan), [day(15), day(17), day(19)]);
  });

  test('paused, time-less, unscheduled or zone-less habits get nothing', () {
    final plan = planReminders([
      habit(id: 'paused', enabled: false),
      habit(id: 'no-time', time: null),
      habit(id: 'bad-time', time: 'soon'),
      habit(id: 'no-days', days: null),
      habit(id: 'no-zone', timezone: null),
      habit(id: 'bad-zone', timezone: 'not/an/iana/zone'),
    ], now: monday8am);
    expect(plan, isEmpty);
  });

  test('sorted soonest first across zones and capped', () {
    final plan = planReminders(
      [
        habit(id: 'late', time: '20:00:00'),
        habit(id: 'early', time: '07:00:00', timezone: 'Asia/Tokyo'),
      ],
      // 06:00 Singapore / 07:00 Tokyo: Tokyo's 07:00 today is not after now.
      now: DateTime.utc(2026, 6, 14, 22),
      max: 3,
    );
    expect([for (final r in plan) r.habit.id], ['late', 'early', 'late']);
  });

  test('crosses month boundaries', () {
    final plan = planReminders([habit()], now: DateTime.utc(2026, 6, 30, 0));
    expect(plan.last.at.toIso8601String().substring(0, 16), '2026-07-06T09:00');
  });

  test('parseReminderTime', () {
    expect(parseReminderTime('07:05:00'), (7, 5));
    expect(parseReminderTime('07:05'), (7, 5));
    expect(parseReminderTime('7'), isNull);
    expect(parseReminderTime(null), isNull);
  });
}
