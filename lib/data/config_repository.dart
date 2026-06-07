import '../core/problem.dart';
import '../generated/zinc/models/configuration_principal_res.dart';
import '../generated/zinc/models/configuration_res.dart';
import '../generated/zinc/models/create_configuration_req.dart';
import '../generated/zinc/models/update_configuration_req.dart';
import '../networking/api_client.dart';

/// zinc `/Configuration` endpoints.
class ConfigRepository {
  final ApiClient _api;
  ConfigRepository(this._api);

  static const _base = '/api/v1.0/Configuration';

  /// The signed-in user's configuration (`GET /Configuration/me`). An [Err] with
  /// `problem.status == 404` means "not yet configured" → route to onboarding.
  Future<Result<ConfigurationRes>> mine() {
    return _api.get(
      '$_base/me',
      (j) => ConfigurationRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Creates the user's configuration (`POST /Configuration`).
  Future<Result<ConfigurationPrincipalRes>> create({
    required String timezone,
    required String defaultCharityId,
  }) {
    return _api.post(
      _base,
      CreateConfigurationReq(
        timezone: timezone,
        defaultCharityId: defaultCharityId,
      ).toJson(),
      (j) => ConfigurationPrincipalRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Updates the user's configuration (`PUT /Configuration/{id}`). Unlike
  /// `GET /Configuration/me` (which wraps as `ConfigurationRes{principal,charity}`),
  /// the PUT returns the *flat* [ConfigurationPrincipalRes] directly.
  ///
  /// zinc's `UpdateConfigurationReqValidator` requires both `timezone` (NotNull,
  /// ≤64 chars) and `defaultCharityId` (NotNull + valid GUID) — a null/empty
  /// charity id 422s.
  Future<Result<ConfigurationPrincipalRes>> update(
    String id,
    UpdateConfigurationReq req,
  ) {
    return _api.put(
      '$_base/$id',
      req.toJson(),
      (j) => ConfigurationPrincipalRes.fromJson(j as Map<String, Object?>),
    );
  }
}
