import '../core/problem.dart';
import '../generated/zinc/models/charity_principal_res.dart';
import '../generated/zinc/models/charity_res.dart';
import '../networking/api_client.dart';

/// zinc `/Charity` endpoints. These are public (no auth required), so calls pass
/// `requiresAuth: false`.
class CharityRepository {
  final ApiClient _api;
  CharityRepository(this._api);

  static const _base = '/api/v1.0/Charity';

  /// Search charities. Note: the list endpoint returns the principals directly
  /// (`CharityPrincipalRes[]`), unwrapped — unlike the single-get which wraps in
  /// `CharityRes{principal}`.
  Future<Result<List<CharityPrincipalRes>>> list({
    String? name,
    String? country,
    String? causeKey,
    int? limit,
    int? skip,
  }) {
    return _api.get(
      _base,
      (j) => (j as List<dynamic>)
          .map((e) => CharityPrincipalRes.fromJson(e as Map<String, Object?>))
          .toList(),
      requiresAuth: false,
      query: {
        'Name': name,
        'Country': country,
        'CauseKey': causeKey,
        'Limit': limit,
        'Skip': skip,
      },
    );
  }

  /// The set of ISO 3166-1 alpha-2 country codes charities can be filtered by
  /// (`GET /Charity/supported-countries`). The endpoint returns a *bare* JSON
  /// string array (e.g. `["US","GB"]`) — not a wrapped object — so it decodes
  /// straight to `List<String>`.
  Future<Result<List<String>>> supportedCountries() {
    return _api.get(
      '$_base/supported-countries',
      (j) => (j as List<dynamic>).map((e) => e as String).toList(),
      requiresAuth: false,
    );
  }

  /// A single charity by id (`GET /Charity/{id}` → `CharityRes{principal}`).
  Future<Result<CharityRes>> byId(String id) {
    return _api.get(
      '$_base/$id',
      (j) => CharityRes.fromJson(j as Map<String, Object?>),
      requiresAuth: false,
    );
  }
}
