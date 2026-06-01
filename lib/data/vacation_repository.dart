import '../core/problem.dart';
import '../generated/zinc/models/create_vacation_req.dart';
import '../generated/zinc/models/vacation_res.dart';
import '../networking/api_client.dart';

/// zinc `/Vacation` endpoints. All are scoped to a user (`/{userId}/…`) and
/// therefore authenticated (`requiresAuth` left at its default `true`).
class VacationRepository {
  final ApiClient _api;
  VacationRepository(this._api);

  static const _base = '/api/v1.0/Vacation';

  /// Schedules a vacation for the user (`POST /Vacation/{userId}`).
  Future<Result<VacationRes>> create(String userId, CreateVacationReq req) {
    return _api.post(
      '$_base/$userId',
      req.toJson(),
      (j) => VacationRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// The user's vacations, optionally filtered by `year` and paged
  /// (`GET /Vacation/{userId}`). Null query values are dropped by ApiClient.
  Future<Result<List<VacationRes>>> list(
    String userId, {
    int? year,
    int? limit,
    int? skip,
  }) {
    return _api.get(
      '$_base/$userId',
      (j) => (j as List<dynamic>)
          .map((e) => VacationRes.fromJson(e as Map<String, Object?>))
          .toList(),
      query: {'Year': year, 'Limit': limit, 'Skip': skip},
    );
  }

  /// Deletes a vacation (`DELETE /Vacation/{userId}/{id}`).
  Future<Result<void>> remove(String userId, String id) {
    return _api.delete('$_base/$userId/$id');
  }

  /// Ends an in-progress vacation today (`PATCH /Vacation/{userId}/{id}/end-today`).
  Future<Result<VacationRes>> endToday(String userId, String id) {
    return _api.patch(
      '$_base/$userId/$id/end-today',
      null,
      (j) => VacationRes.fromJson(j as Map<String, Object?>),
    );
  }
}
