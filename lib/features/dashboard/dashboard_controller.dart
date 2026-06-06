import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/auth_service.dart';
import '../../config/app_config.dart';
import '../../core/problem.dart';
import '../../data/execution_repository.dart';
import '../../data/habit_repository.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';
import '../../generated/zinc/models/habit_overview_response.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../session/session_controller.dart';

enum DashboardPhase { loading, ready, error }

/// Drives the daily-loop dashboard: loads `GET /Habit/{userId}/overview` and runs
/// complete/skip. Actions show a per-habit busy state, then reconcile by refetching
/// the overview (so streaks, debt and the skip budget reflect the server).
class DashboardController extends ChangeNotifier {
  final String? userId;
  final HabitRepository _habits;
  final ExecutionRepository _executions;
  final AuthService _auth;

  DashboardController(SessionController session)
    : userId = session.userId,
      _habits = session.habits,
      _executions = session.executions,
      _auth = session.auth;

  /// Push the freshly-loaded schedule to the iOS widget, and cache the auth context
  /// (zinc base URL + a current access token + user id) into the shared App Group so
  /// the widget's "Complete" button can POST the completion directly. Best-effort.
  Future<void> _pushToWidget(HabitOverviewResponse overview) async {
    await WidgetService.instance.sync(overview);
    final token = await _auth.zincAccessToken();
    await WidgetService.instance.cacheAuth(
      baseUrl: AppConfig.current.zincBaseUrl.toString(),
      token: token,
      userId: userId,
    );
  }

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

  /// The monthly skip allowance from the overview (denominator for the buffers
  /// strip). 0 until the overview loads.
  int get totalSkip => _overview?.totalSkip ?? 0;

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
        unawaited(_syncReminders());
        // Push today's schedule + auth context to the iOS home-screen widget.
        unawaited(_pushToWidget(value));
      case Err(:final problem):
        _error = problem;
        _phase = DashboardPhase.error;
    }
    notifyListeners();
  }

  /// Reschedule local habit reminders from the freshly loaded overview. Prompts
  /// for permission once (iOS). Best-effort — failures don't affect the dashboard.
  Future<void> _syncReminders() async {
    try {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.syncHabits(habits);
    } catch (_) {
      // ignore — reminders are non-critical
    }
  }

  Future<void> complete(HabitOverviewHabitRes habit) =>
      _act(habit, skip: false);
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
    if (res case Ok(:final value)) {
      _overview = value;
      // Keep the home-screen widget + cached auth in sync after a complete/skip.
      unawaited(_pushToWidget(value));
    }
    // A refresh failure leaves the prior data on screen; the action itself succeeded.
  }
}
