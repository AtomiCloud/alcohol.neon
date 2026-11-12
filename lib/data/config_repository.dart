import '../core/date_format.dart';
import '../core/problem.dart';
import '../generated/zinc/models/configuration_principal_res.dart';
import '../generated/zinc/models/configuration_res.dart';
import '../generated/zinc/models/create_configuration_req.dart';
import '../generated/zinc/models/update_configuration_req.dart';
import '../networking/api_client.dart';

/// A day zinc settled because a timezone change made it end already (an
/// eastward move past the end of a pending day). [status] is `missed`,
/// `frozen` or `vacation`.
class TimezoneSettledCheck {
  const TimezoneSettledCheck({
    required this.habitId,
    required this.date,
    required this.status,
  });

  final String habitId;
  final DateTime date;
  final String status;
}

/// `PUT /Configuration/{id}`: the flat principal plus `settledChecks`, the days
/// the timezone change settled. An older zinc omits `settledChecks` → empty.
class ConfigurationUpdate {
  const ConfigurationUpdate(this.principal, this.settledChecks);

  factory ConfigurationUpdate.fromJson(Map<String, Object?> json) {
    final raw = json['settledChecks'];
    final settled = <TimezoneSettledCheck>[];
    if (raw is List) {
      for (final item in raw.whereType<Map<String, Object?>>()) {
        final habitId = item['habitId'];
        final date = tryParseStandardDate(item['date'] as String?);
        final status = item['status'];
        if (habitId is String && date != null && status is String) {
          settled.add(
            TimezoneSettledCheck(habitId: habitId, date: date, status: status),
          );
        }
      }
    }
    return ConfigurationUpdate(
      ConfigurationPrincipalRes.fromJson(json),
      settled,
    );
  }

  final ConfigurationPrincipalRes principal;
  final List<TimezoneSettledCheck> settledChecks;
}

/// zinc `/Configuration` endpoints.
class ConfigRepository {
  final ApiClient _api;
  ConfigRepository(this._api);

  static const _base = '/api/v1.0/Configuration';

  /// The signed-in user's configuration (`GET /Configuration/me`). An [Err] with
  /// `problem.status == 404` means "not yet configured" (first sign-in).
  /// With no default charity, `principal.defaultCharityId` and `charity` are
  /// null.
  Future<Result<ConfigurationRes>> mine() {
    return _api.get(
      '$_base/me',
      (j) => ConfigurationRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Creates the user's configuration (`POST /Configuration`). A null
  /// [defaultCharityId] means none yet: a charity is only needed for a stake.
  Future<Result<ConfigurationPrincipalRes>> create({
    required String timezone,
    String? defaultCharityId,
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
  /// the PUT returns the *flat* principal fields directly, plus the days the
  /// timezone change settled ([ConfigurationUpdate]).
  ///
  /// zinc's `UpdateConfigurationReqValidator` requires `timezone` (NotNull,
  /// ≤64 chars). `defaultCharityId` is the whole new value: a GUID, or null
  /// for no default charity.
  Future<Result<ConfigurationUpdate>> update(
    String id,
    UpdateConfigurationReq req,
  ) {
    return _api.put(
      '$_base/$id',
      req.toJson(),
      (j) => ConfigurationUpdate.fromJson(j as Map<String, Object?>),
    );
  }
}
