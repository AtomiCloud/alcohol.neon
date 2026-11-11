import '../../core/date_format.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';

/// Where a habit stands today, from the server's habit-local date and status.
enum TodayState {
  todo,
  done,
  skipped,
  frozen,
  vacation,
  settled,
  rest,
  paused,
  unknown,
}

class TodayItem {
  final HabitOverviewHabitRes habit;
  final TodayState state;

  /// When today's check ends; null when the habit isn't open today.
  final DateTime? deadline;

  const TodayItem(this.habit, this.state, this.deadline);
}

/// Today's habits grouped the way both Today layouts show them: open habits
/// soonest deadline first, then the ones settled today, then the rest.
class TodayPlan {
  final List<TodayItem> todo;
  final List<TodayItem> done;
  final List<TodayItem> later;

  const TodayPlan(this.todo, this.done, this.later);

  /// The habit to do now: the open one whose check ends soonest.
  TodayItem? get next => todo.isEmpty ? null : todo.first;

  /// Habits that count toward today's ring: open plus settled today.
  int get scheduled => todo.length + done.length;
}

/// Mirrors the old dashboard's precedence: paused, then a missing status, then
/// the settled statuses, then rest days; anything left is open today.
TodayState todayStateOf(HabitOverviewHabitRes habit, String? todayStatus) {
  if (!habit.enabled) return TodayState.paused;
  final today = tryParseStandardDate(habit.status.today);
  if (today == null || todayStatus == null) return TodayState.unknown;
  switch (todayStatus) {
    case 'succeeded':
      return TodayState.done;
    case 'skip':
      return TodayState.skipped;
    case 'frozen':
      return TodayState.frozen;
    case 'vacation':
      return TodayState.vacation;
    case 'failed':
      return TodayState.settled;
  }
  // Server habit-local weekday (Sunday = 0), not the phone's.
  final index = today.weekday % 7;
  final days = habit.days ?? const <bool>[];
  final scheduled = index < days.length && days[index];
  return scheduled ? TodayState.todo : TodayState.rest;
}

TodayPlan buildTodayPlan(
  List<HabitOverviewHabitRes> habits, {
  required String? Function(HabitOverviewHabitRes) todayStatus,
  required DateTime loadedAt,
}) {
  final todo = <TodayItem>[], done = <TodayItem>[], later = <TodayItem>[];
  for (final h in habits) {
    final state = todayStateOf(h, todayStatus(h));
    switch (state) {
      case TodayState.todo:
        // The stored check's end (zinc ≥ 1.37); older servers only send the
        // minutes left, counted from when the overview was loaded.
        final deadline =
            h.todayDeadlineUtc?.toLocal() ??
            loadedAt.add(Duration(minutes: h.timeLeftToEodMinutes));
        todo.add(TodayItem(h, state, deadline));
      case TodayState.done ||
          TodayState.skipped ||
          TodayState.frozen ||
          TodayState.vacation ||
          TodayState.settled:
        done.add(TodayItem(h, state, null));
      case TodayState.rest || TodayState.paused || TodayState.unknown:
        later.add(TodayItem(h, state, null));
    }
  }
  todo.sort((a, b) {
    final byDeadline = a.deadline!.compareTo(b.deadline!);
    return byDeadline != 0
        ? byDeadline
        : (a.habit.name ?? '').compareTo(b.habit.name ?? '');
  });
  return TodayPlan(todo, done, later);
}

/// What's at stake on a miss, as one quiet line; null when nothing is.
String? stakeLine(HabitOverviewHabitRes h) {
  if (h.stake.amount <= 0) return null;
  final amount =
      '${h.stake.currency ?? ''} ${h.stake.amount.toStringAsFixed(2)}'.trim();
  return '$amount to ${h.charity.name ?? 'charity'} if you miss';
}
