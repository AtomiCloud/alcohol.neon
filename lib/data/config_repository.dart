import '../core/problem.dart';
import '../generated/zinc/models/configuration_principal_res.dart';
import '../generated/zinc/models/configuration_res.dart';
import '../generated/zinc/models/create_configuration_req.dart';
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
      CreateConfigurationReq(timezone: timezone, defaultCharityId: defaultCharityId)
          .toJson(),
      (j) => ConfigurationPrincipalRes.fromJson(j as Map<String, Object?>),
    );
  }
}
