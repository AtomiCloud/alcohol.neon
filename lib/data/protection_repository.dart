import '../core/problem.dart';
import '../generated/zinc/models/protection_balance_res.dart';
import '../networking/api_client.dart';

/// zinc `/Protection` endpoints. Protection is a per-user streak-shield balance;
/// the only client-facing read is the balance (the weekly award is a server cron).
class ProtectionRepository {
  final ApiClient _api;
  ProtectionRepository(this._api);

  static const _base = '/api/v1.0/Protection';

  /// The user's current protection balance (`GET /Protection/{userId}`).
  Future<Result<ProtectionBalanceRes>> balance(String userId) {
    return _api.get(
      '$_base/$userId',
      (j) => ProtectionBalanceRes.fromJson(j as Map<String, Object?>),
    );
  }
}
