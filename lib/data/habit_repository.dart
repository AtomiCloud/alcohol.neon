import '../core/problem.dart';
import '../generated/zinc/models/create_habit_req.dart';
import '../generated/zinc/models/habit_overview_habit_res.dart';
import '../generated/zinc/models/habit_overview_response.dart';
import '../generated/zinc/models/habit_version_res.dart';
import '../generated/zinc/models/reorder_habits_req.dart';
import '../generated/zinc/models/reorder_habits_res.dart';
import '../generated/zinc/models/update_habit_req.dart';
import '../networking/api_client.dart';

/// zinc `/Habit` endpoints. All paths are scoped to a user
/// (`/Habit/{userId}/...`) and therefore authenticated (default
/// `requiresAuth: true`).
class HabitRepository {
  final ApiClient _api;
  HabitRepository(this._api);

  static const _base = '/api/v1.0/Habit';

  /// zinc's largest overview page. Without a limit zinc sends only 20 habits.
  static const _overviewPage = 100;

  /// Today's habits overview for the user (`GET /Habit/{userId}/overview`) —
  /// every habit card plus skip budget / debt totals. Pages through zinc 100
  /// habits at a time until a page comes back short; any failed page fails the
  /// whole call, so Today never shows a partial list.
  Future<Result<HabitOverviewResponse>> overview(String userId) async {
    HabitOverviewResponse? first;
    final habits = <HabitOverviewHabitRes>[];
    final seen = <String?>{};
    for (var skip = 0; ; skip += _overviewPage) {
      final res = await _api.get(
        '$_base/$userId/overview',
        (j) => HabitOverviewResponse.fromJson(j as Map<String, Object?>),
        query: {'Limit': _overviewPage, 'Skip': skip},
      );
      final HabitOverviewResponse page;
      switch (res) {
        case Ok(:final value):
          page = value;
        case Err():
          return res;
      }
      first ??= page;
      final items = page.habits ?? const [];
      // A repeated id is dropped; a page with nothing new also ends the loop,
      // so a server that ignores Skip can't loop forever.
      final fresh = items.where((h) => seen.add(h.id)).toList();
      habits.addAll(fresh);
      if (items.length < _overviewPage || fresh.isEmpty) break;
    }
    // Totals are per user, so the first page's are the same as every page's.
    return Ok(
      HabitOverviewResponse(
        habits: habits,
        totalDebt: first.totalDebt,
        usedSkip: first.usedSkip,
        totalSkip: first.totalSkip,
      ),
    );
  }

  /// The user's habits (`GET /Habit/{userId}`), each as its active version.
  Future<Result<List<HabitVersionRes>>> list(
    String userId, {
    String? task,
    bool? enabled,
    int? limit,
    int? skip,
  }) {
    return _api.get(
      '$_base/$userId',
      (j) => (j as List<dynamic>)
          .map((e) => HabitVersionRes.fromJson(e as Map<String, Object?>))
          .toList(),
      query: {'Task': task, 'Enabled': enabled, 'Limit': limit, 'Skip': skip},
    );
  }

  /// A single habit by id (`GET /Habit/{userId}/{id}`).
  Future<Result<HabitVersionRes>> byId(String userId, String id) {
    return _api.get(
      '$_base/$userId/$id',
      (j) => HabitVersionRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Creates a habit (`POST /Habit/{userId}`).
  Future<Result<HabitVersionRes>> create(String userId, CreateHabitReq req) {
    return _api.post(
      '$_base/$userId',
      req.toJson(),
      (j) => HabitVersionRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Updates a habit, producing a new version (`PUT /Habit/{userId}/{id}`).
  Future<Result<HabitVersionRes>> update(
    String userId,
    String id,
    UpdateHabitReq req,
  ) {
    return _api.put(
      '$_base/$userId/$id',
      req.toJson(),
      (j) => HabitVersionRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Saves the user's habit order (`PUT /Habit/{userId}/order`): the listed
  /// habits first, then any left out in their current order. Returns the full
  /// order zinc saved.
  Future<Result<ReorderHabitsRes>> reorder(
    String userId,
    List<String> habitIds,
  ) {
    return _api.put(
      '$_base/$userId/order',
      ReorderHabitsReq(habitIds: habitIds).toJson(),
      (j) => ReorderHabitsRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Deletes a habit (`DELETE /Habit/{userId}/{id}`).
  Future<Result<void>> remove(String userId, String id) {
    return _api.delete('$_base/$userId/$id');
  }
}
