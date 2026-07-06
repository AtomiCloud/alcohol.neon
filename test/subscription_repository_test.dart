import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/subscription_cta_res.dart';
import 'package:alcohol_neon/generated/zinc/models/web_handoff_req.dart';
import 'package:alcohol_neon/generated/zinc/models/web_handoff_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract for the subscription CTA + web-handoff
/// endpoints — camelCase keys, nullable strings, and the unknown-variant
/// forward-compat rule. Decodes via the same path ApiClient uses
/// (jsonDecode → model.fromJson).
void main() {
  test('SubscriptionCtaRes decodes variant + tier (camelCase)', () {
    final json =
        jsonDecode('{ "variant": "subscribe", "tier": "free" }')
            as Map<String, Object?>;

    final res = SubscriptionCtaRes.fromJson(json);
    expect(res.variant, 'subscribe');
    expect(res.tier, 'free');
  });

  test('SubscriptionCtaRes tolerates an unknown variant string', () {
    // New server-side variants must decode fine; the controller maps anything
    // it doesn't know to neutral.
    final json =
        jsonDecode('{ "variant": "upsell-v2", "tier": "pro" }')
            as Map<String, Object?>;

    final res = SubscriptionCtaRes.fromJson(json);
    expect(res.variant, 'upsell-v2');
  });

  test('WebHandoffRes decodes the magic-link payload', () {
    final json =
        jsonDecode('''
      {
        "url": "https://portal.example.com/auth/handoff?one_time_token=abc&login_hint=a%40b.co&redirect=%2Fbilling",
        "expiresInSeconds": 300
      }
    ''')
            as Map<String, Object?>;

    final res = WebHandoffRes.fromJson(json);
    expect(res.url, startsWith('https://portal.example.com/auth/handoff'));
    expect(res.expiresInSeconds, 300);
  });

  test('WebHandoffReq serializes platform + storefront (camelCase)', () {
    final req = WebHandoffReq(platform: 'ios', storefront: 'US');
    expect(req.toJson(), {'platform': 'ios', 'storefront': 'US'});
  });

  test('WebHandoffReq serializes a null storefront', () {
    final req = WebHandoffReq(platform: 'android', storefront: null);
    expect(req.toJson()['platform'], 'android');
    expect(req.toJson()['storefront'], isNull);
  });
}
