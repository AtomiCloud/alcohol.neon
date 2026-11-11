import 'package:alcohol_neon/features/dashboard/today_plan.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_habit_res.dart';
import 'package:flutter_test/flutter_test.dart';

// 09-11-2026 is a Monday: index 1 in zinc's Sunday-first days[].
HabitOverviewHabitRes habit(
  String id, {
  String? status = 'not_applicable',
  int minutesLeft = 120,
  bool enabled = true,
  bool scheduledToday = true,
  String? deadlineUtc,
}) => HabitOverviewHabitRes.fromJson({
  'id': id,
  'name': id,
  'enabled': enabled,
  'days': List.generate(7, (i) => i == 1 ? scheduledToday : !scheduledToday),
  'stake': {'amount': 1, 'currency': 'USD'},
  'charity': {'name': 'Red Cross'},
  'version': {'id': 'v-$id', 'version': 1, 'isActive': true},
  'timeLeftToEodMinutes': minutesLeft,
  'todayDeadlineUtc': deadlineUtc,
  'status': {
    'currentStreak': 0,
    'maxStreak': 0,
    'isCompleteToday': false,
    'today': '09-11-2026',
    'todayStatus': status,
    'week': <String, Object?>{},
  },
});

void main() {
  final loadedAt = DateTime(2026, 11, 9, 18);
  String? serverStatus(HabitOverviewHabitRes h) => h.status.todayStatus;

  test('open habits order by deadline, then name; not by list order', () {
    final plan = buildTodayPlan(
      [
        habit('a-late', minutesLeft: 300),
        habit('z-soon', minutesLeft: 30),
        habit('m-tie', minutesLeft: 300),
      ],
      todayStatus: serverStatus,
      loadedAt: loadedAt,
    );
    expect(plan.todo.map((i) => i.habit.id), ['z-soon', 'a-late', 'm-tie']);
    expect(plan.next!.habit.id, 'z-soon');
    expect(plan.next!.deadline, DateTime(2026, 11, 9, 18, 30));
  });

  test('the server deadline wins over minutes left when present', () {
    // 'early' has more minutes left but its stored check ends first.
    final plan = buildTodayPlan(
      [
        habit('late', minutesLeft: 30),
        habit('early', minutesLeft: 600, deadlineUtc: '2026-11-09T10:15:00Z'),
      ],
      todayStatus: serverStatus,
      loadedAt: DateTime.utc(2026, 11, 9, 10),
    );
    expect(plan.next!.habit.id, 'early');
    expect(plan.next!.deadline!.toUtc(), DateTime.utc(2026, 11, 9, 10, 15));
  });

  test('settled, rest, paused and missing statuses leave the todo list', () {
    final plan = buildTodayPlan(
      [
        habit('done', status: 'succeeded'),
        habit('missed', status: 'failed'),
        habit('rest', scheduledToday: false),
        // Paused wins even over a settled status.
        habit('paused', status: 'succeeded', enabled: false),
        habit('unknown', status: null),
        habit('open'),
      ],
      todayStatus: serverStatus,
      loadedAt: loadedAt,
    );
    expect(plan.todo.map((i) => i.habit.id), ['open']);
    expect(
      {for (final i in plan.done) i.habit.id: i.state},
      {'done': TodayState.done, 'missed': TodayState.settled},
    );
    expect(
      {for (final i in plan.later) i.habit.id: i.state},
      {
        'rest': TodayState.rest,
        'paused': TodayState.paused,
        'unknown': TodayState.unknown,
      },
    );
    expect(plan.scheduled, 3);
  });

  test('an acknowledged action overrides the stale server status', () {
    final plan = buildTodayPlan(
      [habit('a'), habit('b')],
      todayStatus: (h) => h.id == 'a' ? 'skip' : h.status.todayStatus,
      loadedAt: loadedAt,
    );
    expect(plan.next!.habit.id, 'b');
    expect(plan.done.single.state, TodayState.skipped);
  });
}
