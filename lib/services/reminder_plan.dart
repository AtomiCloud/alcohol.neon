/// Pure reminder planning for [NotificationService], extracted for unit tests.
library;

import 'package:timezone/timezone.dart' as tz;

import '../core/date_format.dart';
import '../generated/zinc/models/habit_overview_habit_res.dart';

/// zinc day statuses (HabitOverviewMapper.MapDay) that close a day: once one of
/// these is recorded for today there is nothing left to remind about.
/// "not_applicable" (nothing recorded yet) and anything unknown stay open.
const settledDayStatuses = {
  'succeeded',
  'skip',
  'frozen',
  'vacation',
  'failed',
};

/// How far ahead one-shot reminders are scheduled. Every sync (dashboard load,
/// resume, complete/skip, timezone change) re-plans the window, so it only has
/// to bridge the gap until the app is next opened.
const reminderHorizon = Duration(days: 7);

/// iOS keeps at most 64 pending local notifications and silently drops the
/// rest, so the plan is capped (soonest first).
const maxPendingReminders = 64;

/// One reminder to schedule, at a wall-clock time in the habit's timezone.
class PlannedReminder {
  final HabitOverviewHabitRes habit;
  final tz.TZDateTime at;
  const PlannedReminder(this.habit, this.at);
}

/// The one-shot reminders firing within [horizon] of [now], for the overview's
/// [habits]. Each habit is planned in its own `timezone` (zinc sends the
/// user's Configuration.Timezone there); habits without a valid one, paused
/// habits and unscheduled days get nothing. A habit already settled on the
/// server's "today" (`status.today` + `todayStatus`, or `isCompleteToday`)
/// gets no reminder that day but keeps its later days. [todayStatus]
/// overrides the overview's status, e.g. for an acknowledged complete/skip
/// whose refetch hasn't landed yet.
List<PlannedReminder> planReminders(
  List<HabitOverviewHabitRes> habits, {
  required DateTime now,
  String? Function(HabitOverviewHabitRes habit)? todayStatus,
  Duration horizon = reminderHorizon,
  int max = maxPendingReminders,
}) {
  final until = now.add(horizon);
  final plan = <PlannedReminder>[];
  for (final h in habits) {
    if (!h.enabled) continue;
    final time = parseReminderTime(h.notificationTime);
    final days = h.days;
    final zone = h.timezone;
    if (time == null || days == null || zone == null) continue;
    final tz.Location location;
    try {
      location = tz.getLocation(zone);
    } on tz.LocationNotFoundException {
      // Do not silently schedule in the device's zone for invalid habit data.
      continue;
    }
    final local = tz.TZDateTime.from(now, location);
    final status = todayStatus?.call(h) ?? h.status.todayStatus;
    final settled =
        h.status.isCompleteToday || settledDayStatuses.contains(status);
    // The server's habit-local date, falling back to the zone's own date.
    final settledDay = settled
        ? tryParseStandardDate(h.status.today) ??
              DateTime(local.year, local.month, local.day)
        : null;
    for (var offset = 0; offset <= horizon.inDays; offset++) {
      // Calendar days, not 24-hour durations: retain wall time across DST.
      final at = tz.TZDateTime(
        location,
        local.year,
        local.month,
        local.day + offset,
        time.$1,
        time.$2,
      );
      final dayIndex = at.weekday % 7; // DateTime: Mon=1..Sun=7 → Sun=0
      if (dayIndex >= days.length || !days[dayIndex]) continue;
      if (!at.isAfter(now) || at.isAfter(until)) continue;
      if (settledDay != null &&
          at.year == settledDay.year &&
          at.month == settledDay.month &&
          at.day == settledDay.day) {
        continue;
      }
      plan.add(PlannedReminder(h, at));
    }
  }
  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan.length > max ? plan.sublist(0, max) : plan;
}

/// Parses zinc's "HH:mm:ss" into (hour, minute).
(int, int)? parseReminderTime(String? hhmmss) {
  if (hhmmss == null) return null;
  final parts = hhmmss.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return (h, m);
}
