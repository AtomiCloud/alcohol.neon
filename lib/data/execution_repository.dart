import '../core/problem.dart';
import '../generated/zinc/models/complete_habit_req.dart';
import '../generated/zinc/models/habit_execution_res.dart';
import '../generated/zinc/models/skip_habit_req.dart';
import '../networking/api_client.dart';

/// zinc `/Habit/{userId}` execution endpoints — completing, skipping, and
/// listing a user's habit executions. All authenticated (paths under
/// `/{userId}/`).
class ExecutionRepository {
  final ApiClient _api;
  ExecutionRepository(this._api);

  static const _base = '/api/v1.0/Habit';

  /// Marks a habit version complete for the user
  /// (`POST /Habit/{userId}/{habitVersionId}/executions`).
  Future<Result<HabitExecutionRes>> complete(
    String userId,
    String habitVersionId, {
    CompleteHabitReq? req,
  }) {
    return _api.post(
      '$_base/$userId/$habitVersionId/executions',
      req?.toJson(),
      (j) => HabitExecutionRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Skips a habit version for the user
  /// (`POST /Habit/{userId}/{habitVersionId}/executions/skip`).
  Future<Result<HabitExecutionRes>> skip(
    String userId,
    String habitVersionId, {
    SkipHabitReq? req,
  }) {
    return _api.post(
      '$_base/$userId/$habitVersionId/executions/skip',
      req?.toJson(),
      (j) => HabitExecutionRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Lists the user's executions (`GET /Habit/{userId}/executions`), optionally
  /// filtered by [date] (`yyyy-MM-dd`) and paged via [limit]/[skip].
  Future<Result<List<HabitExecutionRes>>> onDate(
    String userId, {
    String? date,
    int? limit,
    int? skip,
  }) {
    return _api.get(
      '$_base/$userId/executions',
      (j) => (j as List<dynamic>)
          .map((e) => HabitExecutionRes.fromJson(e as Map<String, Object?>))
          .toList(),
      query: {'Date': date, 'Limit': limit, 'Skip': skip},
    );
  }
}
