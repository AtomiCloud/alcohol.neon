import 'package:flutter/foundation.dart';

import '../../core/problem.dart';
import '../../data/execution_repository.dart';
import '../../data/habit_repository.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';
import '../../generated/zinc/models/habit_overview_response.dart';
import '../../session/session_controller.dart';

enum DashboardPhase { loading, ready, error }

/// Drives the daily-loop dashboard: loads `GET /Habit/{userId}/overview` and runs
/// complete/skip. Actions show a per-habit busy state, then reconcile by refetching
/// the overview (so streaks, debt and the skip budget reflect the server).
class DashboardController extends ChangeNotifier {
  final String? userId;
  final HabitRepository _habits;
  final ExecutionRepository _executions;

  DashboardController(SessionController session)
      : userId = session.userId,
        _habits = session.habits,
        _executions = session.executions;

  DashboardPhase _phase = DashboardPhase.loading;
  Problem? _error;
  Problem? _actionError;
  HabitOverviewResponse? _overview;
  final Set<String> _busy = {}; // habit ids with an in-flight action

  DashboardPhase get phase => _phase;
  Problem? get error => _error;

  /// Surfaces a transient failure from complete/skip (shown as a banner, then cleared).
  Problem? get actionError => _actionError;

  HabitOverviewResponse? get overview => _overview;
  List<HabitOverviewHabitRes> get habits => _overview?.habits ?? const [];
  String? get totalDebt => _overview?.totalDebt;

  int get skipsLeft {
    final o = _overview;
    if (o == null) return 0;
    final left = o.totalSkip - o.usedSkip;
    return left < 0 ? 0 : left;
  }

  bool isBusy(HabitOverviewHabitRes habit) =>
      habit.id != null && _busy.contains(habit.id);

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  /// Full load — flips to the loading state (initial open / pull-to-refresh / retry).
  Future<void> load() async {
    final uid = userId;
    if (uid == null) {
      _error = Problem.local('Not signed in', status: 401, type: 'neon:auth');
      _phase = DashboardPhase.error;
      notifyListeners();
      return;
    }
    _phase = DashboardPhase.loading;
    _error = null;
    notifyListeners();

    final res = await _habits.overview(uid);
    switch (res) {
      case Ok(:final value):
        _overview = value;
        _phase = DashboardPhase.ready;
      case Err(:final problem):
        _error = problem;
        _phase = DashboardPhase.error;
    }
    notifyListeners();
  }

  Future<void> complete(HabitOverviewHabitRes habit) => _act(habit, skip: false);
  Future<void> skip(HabitOverviewHabitRes habit) => _act(habit, skip: true);

  Future<void> _act(HabitOverviewHabitRes habit, {required bool skip}) async {
    final uid = userId;
    final versionId = habit.version.id;
    final habitId = habit.id;
    if (uid == null || versionId == null || habitId == null) return;
    if (_busy.contains(habitId)) return;
    if (skip && skipsLeft <= 0) return;

    _busy.add(habitId);
    _actionError = null;
    notifyListeners();

    final res = skip
        ? await _executions.skip(uid, versionId)
        : await _executions.complete(uid, versionId);
    switch (res) {
      case Ok():
        await _refresh(); // reconcile streaks / debt / skip budget
      case Err(:final problem):
        _actionError = problem;
    }
    _busy.remove(habitId);
    notifyListeners();
  }

  /// Quiet refetch that updates data without flipping back to the loading state.
  Future<void> _refresh() async {
    final uid = userId;
    if (uid == null) return;
    final res = await _habits.overview(uid);
    if (res case Ok(:final value)) _overview = value;
    // A refresh failure leaves the prior data on screen; the action itself succeeded.
  }
}
