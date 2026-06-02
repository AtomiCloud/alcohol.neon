import 'package:flutter/foundation.dart';

import '../../core/date_format.dart';
import '../../core/problem.dart';
import '../../data/vacation_repository.dart';
import '../../generated/zinc/models/create_vacation_req.dart';
import '../../generated/zinc/models/vacation_res.dart';
import '../../session/session_controller.dart';

enum VacationPhase { loading, ready, error }

/// Lifecycle status of a vacation window, derived from its `dd-MM-yyyy` dates
/// evaluated in the window's own timezone (mirrors zinc's `VacationService`, which
/// converts UtcNow into the vacation's tz before comparing to start/end).
enum VacationStatus { upcoming, active, ended }

/// A vacation row decorated with its computed status (so the view stays dumb).
class VacationItem {
  final VacationRes res;
  final VacationStatus status;
  const VacationItem(this.res, this.status);

  String get id => res.id;
  bool get isActive => status == VacationStatus.active;
}

/// Drives the vacation list + create flow against `/Vacation/{userId}`. All
/// fallible calls return `Result<T>`; the controller switches `Ok`/`Err` and never
/// lets a throw reach the widgets.
class VacationController extends ChangeNotifier {
  final String? userId;
  final VacationRepository _vacations;

  VacationController(SessionController session)
      : userId = session.userId,
        _vacations = session.vacations;

  VacationPhase _phase = VacationPhase.loading;
  Problem? _error;
  Problem? _actionError;
  List<VacationItem> _items = const [];
  final Set<String> _busy = {}; // vacation ids with an in-flight delete/end-today

  VacationPhase get phase => _phase;
  Problem? get error => _error;

  /// Transient failure from delete/end-today (shown as a banner, then cleared).
  Problem? get actionError => _actionError;

  List<VacationItem> get items => _items;

  bool isBusy(String id) => _busy.contains(id);

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  /// Full load — flips to loading (initial open / pull-to-refresh / retry).
  Future<void> load() async {
    final uid = userId;
    if (uid == null) {
      _error = const Problem(
          type: 'neon:auth', title: 'Not signed in', status: 401);
      _phase = VacationPhase.error;
      notifyListeners();
      return;
    }
    _phase = VacationPhase.loading;
    _error = null;
    notifyListeners();

    final res = await _vacations.list(uid);
    switch (res) {
      case Ok(:final value):
        _items = _decorate(value);
        _phase = VacationPhase.ready;
      case Err(:final problem):
        _error = problem;
        _phase = VacationPhase.error;
    }
    notifyListeners();
  }

  /// Quiet refetch that updates the list without flipping to the loading state
  /// (used after delete / end-today, including the 404 self-heal path).
  Future<void> _refresh() async {
    final uid = userId;
    if (uid == null) return;
    final res = await _vacations.list(uid);
    if (res case Ok(:final value)) _items = _decorate(value);
  }

  /// Deletes a window. zinc only allows deleting one that hasn't started; a 404
  /// means it's already gone — treat that as success and just refresh the list
  /// rather than surface a hard error.
  Future<void> remove(String id) async {
    final uid = userId;
    if (uid == null || _busy.contains(id)) return;
    _busy.add(id);
    _actionError = null;
    notifyListeners();

    final res = await _vacations.remove(uid, id);
    switch (res) {
      case Ok():
        await _refresh();
      case Err(:final problem):
        if (problem.status == 404) {
          await _refresh();
        } else {
          _actionError = problem;
        }
    }
    _busy.remove(id);
    notifyListeners();
  }

  /// Ends an active window today. A 404 means it's gone — refresh instead of error.
  Future<void> endToday(String id) async {
    final uid = userId;
    if (uid == null || _busy.contains(id)) return;
    _busy.add(id);
    _actionError = null;
    notifyListeners();

    final res = await _vacations.endToday(uid, id);
    switch (res) {
      case Ok():
        await _refresh();
      case Err(:final problem):
        if (problem.status == 404) {
          await _refresh();
        } else {
          _actionError = problem;
        }
    }
    _busy.remove(id);
    notifyListeners();
  }

  /// Creates a vacation window. Dates are formatted to zinc's `dd-MM-yyyy` here so
  /// the format never leaks into the view. Returns the `Result` so the create
  /// screen can surface tier/validation problems; on success refreshes the list.
  Future<Result<VacationRes>> create({
    required DateTime start,
    required DateTime end,
    required String timezone,
  }) async {
    final uid = userId;
    if (uid == null) return const Err(Problem.unauthenticated);
    final req = CreateVacationReq(
      startDate: formatStandardDate(start),
      endDate: formatStandardDate(end),
      timezone: timezone,
    );
    final res = await _vacations.create(uid, req);
    if (res case Ok()) {
      await _refresh();
      notifyListeners(); // refresh updates _items silently; notify so the list rebuilds
    }
    return res;
  }

  List<VacationItem> _decorate(List<VacationRes> list) {
    final decorated =
        list.map((v) => VacationItem(v, vacationStatusFor(v))).toList();
    // No reliable persisted timestamp (createdAt is response-time UtcNow), so sort
    // by start date with active/upcoming first, ended last, then by start ascending.
    decorated.sort((a, b) {
      int rank(VacationStatus s) => switch (s) {
            VacationStatus.active => 0,
            VacationStatus.upcoming => 1,
            VacationStatus.ended => 2,
          };
      final byRank = rank(a.status).compareTo(rank(b.status));
      if (byRank != 0) return byRank;
      final sa = tryParseStandardDate(a.res.startDate);
      final sb = tryParseStandardDate(b.res.startDate);
      if (sa == null || sb == null) return 0;
      return sa.compareTo(sb);
    });
    return decorated;
  }

}

/// upcoming/active/ended for a window, computed against "today" (date-only). zinc
/// evaluates this in the vacation's own timezone; we don't ship a tz database, so
/// we approximate "today" from the device clock — adequate for day-granularity
/// start/end. Dates are parsed from zinc's `dd-MM-yyyy`. An unparseable/missing
/// start defaults to `upcoming`. [now] is injectable for tests.
VacationStatus vacationStatusFor(VacationRes v, {DateTime? now}) {
  final start = tryParseStandardDate(v.startDate);
  final end = tryParseStandardDate(v.endDate);
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  if (start == null) return VacationStatus.upcoming;
  if (today.isBefore(start)) return VacationStatus.upcoming;
  if (end != null && today.isAfter(end)) return VacationStatus.ended;
  return VacationStatus.active;
}
