import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../core/launch_timeline.dart';
import '../../core/problem.dart';
import '../../data/execution_repository.dart';
import '../../data/habit_repository.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';
import '../../generated/zinc/models/habit_overview_response.dart';
import '../../services/live_activity_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../session/session_controller.dart';
import 'today_plan.dart';

enum DashboardPhase { loading, ready, error }

/// Drives the daily-loop dashboard: loads `GET /Habit/{userId}/overview` and runs
/// complete/skip. Actions show a per-habit busy state, then reconcile by refetching
/// the overview (so streaks, debt and the skip budget reflect the server).
class DashboardController extends ChangeNotifier {
  final String? userId;
  final HabitRepository _habits;
  final ExecutionRepository _executions;
  final SessionController _session;
  final int _generation;
  bool _disposed = false;

  bool get _current =>
      !_disposed &&
      _session.generation == _generation &&
      _session.userId == userId;

  DashboardController(SessionController session)
    : userId = session.userId,
      _habits = session.habits,
      _executions = session.executions,
      _session = session,
      _generation = session.generation {
    // Last launch's Today (same day): shown until the fresh overview lands.
    final cached = session.takeCachedOverview();
    if (cached != null) {
      _overview = cached;
      _phase = DashboardPhase.ready;
      fromCache = true;
    }
  }

  /// Whether [overview] is still the saved one from the last launch.
  bool fromCache = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Push the freshly-loaded schedule to the iOS widget, and cache the auth context
  /// (zinc base URL + a current access token + user id) into the shared App Group so
  /// the widget's "Complete" button can POST the completion directly. Best-effort.
  Future<void> _pushToWidget(TodayPlan plan) async {
    final token = await _session.auth.zincAccessToken();
    if (!_current) return;
    await _session.syncDevice(_generation, () async {
      if (!_current) return;
      await WidgetService.instance.sync(plan);
      if (!_current) return;
      await WidgetService.instance.cacheAuth(
        baseUrl: AppConfig.current.zincBaseUrl.toString(),
        token: token,
        userId: userId,
      );
    });
  }

  DashboardPhase _phase = DashboardPhase.loading;
  Problem? _error;
  Problem? _actionError;
  Problem? _refreshError;
  HabitOverviewResponse? _overview;
  DateTime _loadedAt = DateTime.now();
  int _loadRequest = 0;
  final Set<String> _busy = {}; // habit ids with an in-flight action
  final Map<String, (String?, String)> _settled = {};

  DashboardPhase get phase => _phase;
  Problem? get error => _error;

  /// Surfaces a transient failure from complete/skip (shown as a banner, then cleared).
  Problem? get actionError => _actionError;
  Problem? get refreshError => _refreshError;

  /// Acknowledged POSTs remain settled until an overview reconciles them.
  String? todayStatus(HabitOverviewHabitRes habit) {
    final saved = _settled[habit.id];
    return saved != null && saved.$1 == habit.status.today
        ? saved.$2
        : habit.status.todayStatus;
  }

  HabitOverviewResponse? get overview => _overview;
  List<HabitOverviewHabitRes> get habits => _overview?.habits ?? const [];

  /// Today's habits grouped for the Today layouts, with each open habit's
  /// deadline taken from when the overview was loaded.
  TodayPlan get plan => buildTodayPlan(
    habits,
    todayStatus: todayStatus,
    loadedAt: _loadedAt,
    order: _shownOrder,
  );

  /// Rows can be dragged into a new order only on a zinc that keeps one
  /// (`sortOrder` on every habit); older zinc has no order route.
  bool get canReorder =>
      habits.isNotEmpty &&
      habits.every((h) => h.id != null && h.sortOrder != null);

  // A reorder the server hasn't confirmed yet, as the full list of habit ids.
  // Kept until a load that started after the save lands.
  List<String>? _shownOrder;
  List<String>? _waitingOrder; // the newest drop while a PUT is in flight
  bool _savingOrder = false;
  int _orderSavedBeforeLoad = 0;

  /// Moves a section's habits into the order [sectionIds] (that section's
  /// habit ids, in their new order). The section's habits trade the places
  /// they already hold in the full order and no other habit moves; the full
  /// order is saved, one PUT at a time, and shown before it is saved.
  void reorder(List<String> sectionIds) {
    if (!_current || userId == null || !canReorder) return;
    final base =
        _shownOrder ??
        [
          for (final h in [...habits]..sort(userOrder(habits))) h.id!,
        ];
    final moving = sectionIds.toSet();
    final slots = sectionIds.iterator;
    final full = [
      for (final id in base)
        if (moving.contains(id) && slots.moveNext()) slots.current else id,
    ];
    if (listEquals(full, base)) return;
    _shownOrder = full;
    notifyListeners();
    if (_savingOrder) {
      _waitingOrder = full;
    } else {
      unawaited(_saveOrder(full));
    }
  }

  Future<void> _saveOrder(List<String> order) async {
    _savingOrder = true;
    final res = await _habits.reorder(userId!, order);
    if (!_current) return;
    _savingOrder = false;
    switch (res) {
      case Ok():
        final waiting = _waitingOrder;
        _waitingOrder = null;
        if (waiting != null) return _saveOrder(waiting);
        _orderSavedBeforeLoad = _loadRequest;
        await load(quiet: true); // saves the cache, syncs widgets and reminders
      case Err(:final problem):
        _shownOrder = null;
        _waitingOrder = null;
        _actionError = Problem.local(
          "Couldn't save the new order. Try again.",
          status: problem.status,
          type: problem.type,
        );
        notifyListeners();
        // A 400 means our list was stale (say, a habit deleted elsewhere).
        if (problem.status == 400) await load(quiet: true);
    }
  }

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
  Future<void> load({bool quiet = false}) async {
    if (!_current) return;
    final uid = userId;
    if (uid == null) {
      _error = Problem.local('Not signed in', status: 401, type: 'neon:auth');
      _phase = DashboardPhase.error;
      notifyListeners();
      return;
    }
    if (!quiet) _phase = DashboardPhase.loading;
    _error = null;
    notifyListeners();

    final request = ++_loadRequest;
    final res =
        await (_session.takeOverviewPrefetch() ?? _habits.overview(uid));
    if (!_current || request != _loadRequest) return;
    switch (res) {
      case Ok(:final value):
        _overview = value;
        // A load from after the last save carries the saved order.
        if (!_savingOrder &&
            _waitingOrder == null &&
            request > _orderSavedBeforeLoad) {
          _shownOrder = null;
        }
        fromCache = false;
        _loadedAt = DateTime.now();
        unawaited(_session.cache.saveOverview(uid, value));
        LaunchTimeline.mark('today-refreshed');
        _settled.clear();
        _refreshError = null;
        _phase = DashboardPhase.ready;
        unawaited(_syncReminders());
        // Push today's schedule + auth context to the iOS home-screen widget.
        unawaited(_pushToWidget(plan));
        unawaited(_syncLiveActivity());
      case Err(:final problem):
        if (_overview != null) {
          _refreshError = problem;
          _phase = DashboardPhase.ready;
        } else {
          _error = problem;
          _phase = DashboardPhase.error;
        }
    }
    notifyListeners();
  }

  /// Reschedule local habit reminders from the freshly loaded overview — only
  /// for checks still open today (acknowledged complete/skips included via
  /// [todayStatus]). Prompts for permission once (iOS). Best-effort — failures
  /// don't affect the dashboard.
  Future<void> _syncReminders() async {
    await _session.syncDevice(_generation, () async {
      if (!_current) return;
      await NotificationService.instance.syncHabits(
        habits,
        isCurrent: () => _current,
        todayStatus: todayStatus,
      );
    });
  }

  /// Show the next open habit as a Live Activity (iOS), or end it when none is
  /// left. Best-effort, like the widget push.
  Future<void> _syncLiveActivity() async {
    final plan = this.plan;
    await _session.syncDevice(_generation, () async {
      if (!_current) return;
      await LiveActivityService.instance.show(plan);
    });
  }

  Future<void> complete(HabitOverviewHabitRes habit) =>
      _act(habit, skip: false);
  Future<void> skip(HabitOverviewHabitRes habit) => _act(habit, skip: true);

  Future<void> _act(HabitOverviewHabitRes habit, {required bool skip}) async {
    final uid = userId;
    final versionId = habit.version.id;
    final habitId = habit.id;
    if (!_current || uid == null || versionId == null || habitId == null) {
      return;
    }
    if (_busy.contains(habitId)) return;
    if (_settled.containsKey(habitId)) return;
    if (skip && skipsLeft <= 0) return;

    _busy.add(habitId);
    _actionError = null;
    notifyListeners();

    final res = skip
        ? await _executions.skip(uid, versionId)
        : await _executions.complete(uid, versionId);
    if (!_current) return;
    switch (res) {
      case Ok():
        _settled[habitId] = (habit.status.today, skip ? 'skip' : 'succeeded');
        _busy.remove(habitId);
        notifyListeners();
        await load(quiet: true); // reconcile streaks / debt / skip budget
        // A successful reload re-plans reminders itself; if it failed, re-plan
        // from the acknowledged action so today's reminder still goes away.
        if (_current && _refreshError != null) unawaited(_syncReminders());
      case Err(:final problem):
        _actionError = problem;
    }
    if (!_current) return;
    _busy.remove(habitId);
    notifyListeners();
  }
}
