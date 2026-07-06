import '../core/problem.dart';
import '../generated/zinc/models/subscription_cta_res.dart';
import '../generated/zinc/models/web_handoff_req.dart';
import '../generated/zinc/models/web_handoff_res.dart';
import '../networking/api_client.dart';

/// zinc subscription CTA + web-handoff endpoints. The CTA tells the app which
/// subscription action it may show for this platform+storefront (steering
/// rules); the handoff mints a one-time-token magic link into the web billing
/// portal for the signed-in user.
class SubscriptionRepository {
  final ApiClient _api;
  SubscriptionRepository(this._api);

  static const _subscription = '/api/v1.0/Subscription';
  static const _auth = '/api/v1.0/Auth';

  /// Which CTA variant to show (`GET /Subscription/{userId}/cta`). Variants:
  /// manage / subscribe / neutral — treat anything unknown as neutral.
  Future<Result<SubscriptionCtaRes>> cta(
    String userId, {
    required String platform,
    String? storefront,
  }) {
    return _api.get(
      '$_subscription/$userId/cta',
      (j) => SubscriptionCtaRes.fromJson(j as Map<String, Object?>),
      query: {'platform': platform, 'storefront': storefront},
    );
  }

  /// Mints the magic-link URL into the web billing portal for the caller
  /// (`POST /Auth/web-handoff`). The server only ever mints for the token's
  /// own subject; restricted storefronts get a 403 Problem.
  Future<Result<WebHandoffRes>> webHandoff({
    required String platform,
    String? storefront,
  }) {
    return _api.post(
      '$_auth/web-handoff',
      WebHandoffReq(platform: platform, storefront: storefront).toJson(),
      (j) => WebHandoffRes.fromJson(j as Map<String, Object?>),
    );
  }
}
