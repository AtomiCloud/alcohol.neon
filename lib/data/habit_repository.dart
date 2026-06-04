import '../core/problem.dart';
import '../generated/zinc/models/create_habit_req.dart';
import '../generated/zinc/models/habit_overview_response.dart';
import '../generated/zinc/models/habit_version_res.dart';
import '../generated/zinc/models/update_habit_req.dart';
import '../networking/api_client.dart';

/// zinc `/Habit` endpoints. All paths are scoped to a user
/// (`/Habit/{userId}/...`) and therefore authenticated (default
/// `requiresAuth: true`).
class HabitRepository {
  final ApiClient _api;
  HabitRepository(this._api);

  static const _base = '/api/v1.0/Habit';

  /// Today's habits overview for the user (`GET /Habit/{userId}/overview`) —
  /// the habit cards plus skip budget / debt totals.
  Future<Result<HabitOverviewResponse>> overview(
    String userId, {
    int? limit,
    int? skip,
  }) {
    return _api.get(
      '$_base/$userId/overview',
      (j) => HabitOverviewResponse.fromJson(j as Map<String, Object?>),
      query: {'Limit': limit, 'Skip': skip},
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
      query: {
        'Task': task,
        'Enabled': enabled,
        'Limit': limit,
        'Skip': skip,
      },
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

  /// Deletes a habit (`DELETE /Habit/{userId}/{id}`).
  Future<Result<void>> remove(String userId, String id) {
    return _api.delete('$_base/$userId/$id');
  }
}
