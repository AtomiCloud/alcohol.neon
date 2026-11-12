import '../core/problem.dart';
import '../networking/api_client.dart';

/// The Strava authorize URLs: [appUrl] (`strava://…`) opens the Strava app,
/// [url] (`https://www.strava.com/…`) is the browser fallback.
///
/// Hand-rolled (not `generated/zinc`) because pichu's checked-in OpenAPI spec
/// predates the Strava endpoints (zinc ≥ 1.39). Fold into the generated models
/// on the next `swagger_parser` regeneration.
class StravaConnectUrlRes {
  final String url;
  final String appUrl;

  const StravaConnectUrlRes({required this.url, required this.appUrl});

  factory StravaConnectUrlRes.fromJson(Map<String, Object?> json) =>
      StravaConnectUrlRes(
        url: json['url'] as String? ?? '',
        appUrl: json['appUrl'] as String? ?? '',
      );
}

class StravaConnectionRes {
  final bool connected;
  final DateTime? connectedAtUtc;

  const StravaConnectionRes({required this.connected, this.connectedAtUtc});

  factory StravaConnectionRes.fromJson(Map<String, Object?> json) =>
      StravaConnectionRes(
        connected: json['connected'] as bool? ?? false,
        connectedAtUtc: DateTime.tryParse(
          json['connectedAtUtc'] as String? ?? '',
        ),
      );
}

/// zinc `/Strava` endpoints. zinc answers 404 on every route when Strava is
/// disabled for the landscape.
class StravaRepository {
  final ApiClient _api;
  StravaRepository(this._api);

  static const _base = '/api/v1.0/Strava';

  /// The URLs that start Strava's OAuth (`GET /Strava/connect-url/{userId}`).
  Future<Result<StravaConnectUrlRes>> connectUrl(String userId) {
    return _api.get(
      '$_base/connect-url/$userId',
      (j) => StravaConnectUrlRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Whether the user has Strava connected (`GET /Strava/{userId}`).
  Future<Result<StravaConnectionRes>> status(String userId) {
    return _api.get(
      '$_base/$userId',
      (j) => StravaConnectionRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Revokes LazyTax in Strava, deletes the user's Strava data and puts their
  /// Strava habits back on manual check-in (`DELETE /Strava/{userId}`).
  Future<Result<void>> disconnect(String userId) {
    return _api.delete('$_base/$userId');
  }
}
