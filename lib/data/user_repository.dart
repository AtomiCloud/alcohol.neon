import '../core/problem.dart';
import '../generated/zinc/models/create_user_req.dart';
import '../generated/zinc/models/user_principal_res.dart';
import '../generated/zinc/models/user_res.dart';
import '../networking/api_client.dart';

/// zinc `/User` endpoints. zinc's API version is `1.0` (path `/api/v1.0/...`),
/// mirroring alcohol.argon's generated client.
class UserRepository {
  final ApiClient _api;
  UserRepository(this._api);

  static const _base = '/api/v1.0/User';

  /// Idempotently provisions the zinc user from Logto tokens — run once after the
  /// first sign-in. zinc verifies the tokens and creates/returns the user.
  Future<Result<UserPrincipalRes>> create({
    required String idToken,
    required String accessToken,
  }) {
    return _api.post(
      _base,
      CreateUserReq(idToken: idToken, accessToken: accessToken).toJson(),
      (j) => UserPrincipalRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// The signed-in user's full profile (`GET /User/Me/All`).
  Future<Result<UserRes>> me() {
    return _api.get(
      '$_base/Me/All',
      (j) => UserRes.fromJson(j as Map<String, Object?>),
    );
  }
}
