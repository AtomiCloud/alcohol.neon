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

/// Today's habits grouped the way both Today layouts show them: the open
/// habits, the ones settled today, then the rest, each in the user's order.
class TodayPlan {
  final List<TodayItem> todo;
  final List<TodayItem> done;
  final List<TodayItem> later;

  /// The open habits soonest deadline first, the user's order breaking ties.
  /// Next up, the widgets and the Live Activity follow this.
  final List<TodayItem> soonest;

  const TodayPlan(this.todo, this.done, this.later, this.soonest);

  /// The habit to do now: the open one whose check ends soonest.
  TodayItem? get next => soonest.isEmpty ? null : soonest.first;

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

/// Compares habits in the user's order: an unsaved reorder ([order], habit
/// ids) first, then zinc's `sortOrder`, or the overview's own order from a
/// zinc that doesn't send one. Ties go to the habit id.
Comparator<HabitOverviewHabitRes> userOrder(
  List<HabitOverviewHabitRes> habits, {
  List<String>? order,
}) {
  final moved = {for (final (i, id) in (order ?? const []).indexed) id: i};
  final rank = {
    for (final (i, h) in habits.indexed)
      h: moved[h.id] ?? moved.length + (h.sortOrder ?? i),
  };
  return (a, b) {
    final byRank = rank[a]!.compareTo(rank[b]!);
    return byRank != 0 ? byRank : (a.id ?? '').compareTo(b.id ?? '');
  };
}

TodayPlan buildTodayPlan(
  List<HabitOverviewHabitRes> habits, {
  required String? Function(HabitOverviewHabitRes) todayStatus,
  required DateTime loadedAt,
  List<String>? order,
}) {
  final compare = userOrder(habits, order: order);
  int byOrder(TodayItem a, TodayItem b) => compare(a.habit, b.habit);

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
  for (final list in [todo, done, later]) {
    list.sort(byOrder);
  }
  final soonest = [...todo]
    ..sort((a, b) {
      final byDeadline = a.deadline!.compareTo(b.deadline!);
      return byDeadline != 0 ? byDeadline : byOrder(a, b);
    });
  return TodayPlan(todo, done, later, soonest);
}

/// The proof label Today shows next to a habit: `Strava` for Strava-bound
/// habits, null otherwise (`manual`, `nfc` and unknown proofs show nothing).
/// Check-in stays available whatever the proof.
String? proofLabel(HabitOverviewHabitRes h) =>
    h.proof == 'strava' ? 'Strava' : null;

/// What's at stake on a miss, as one quiet line; null when nothing is.
String? stakeLine(HabitOverviewHabitRes h) {
  if (h.stake.amount <= 0) return null;
  final amount =
      '${h.stake.currency ?? ''} ${h.stake.amount.toStringAsFixed(2)}'.trim();
  return '$amount to ${h.charity?.name ?? 'charity'} if you miss';
}
