import '../core/problem.dart';
import '../generated/zinc/models/cause_principal_res.dart';
import '../generated/zinc/models/cause_res.dart';
import '../networking/api_client.dart';

/// zinc `/Causes` endpoints. These are public (no auth required), so calls pass
/// `requiresAuth: false`.
class CauseRepository {
  final ApiClient _api;
  CauseRepository(this._api);

  static const _base = '/api/v1.0/Causes';

  /// Search causes. The list endpoint returns the principals directly
  /// (`CausePrincipalRes[]`), unwrapped — unlike the single-get which wraps in
  /// `CauseRes{principal}`.
  Future<Result<List<CausePrincipalRes>>> list({
    String? key,
    String? name,
    int? limit,
    int? skip,
  }) {
    return _api.get(
      _base,
      (j) => (j as List<dynamic>)
          .map((e) => CausePrincipalRes.fromJson(e as Map<String, Object?>))
          .toList(),
      requiresAuth: false,
      query: {'Key': key, 'Name': name, 'Limit': limit, 'Skip': skip},
    );
  }

  /// A single cause by id (`GET /Causes/{id}` → `CauseRes{principal}`).
  Future<Result<CauseRes>> byId(String id) {
    return _api.get(
      '$_base/$id',
      (j) => CauseRes.fromJson(j as Map<String, Object?>),
      requiresAuth: false,
    );
  }
}
