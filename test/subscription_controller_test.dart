import 'dart:convert';

import 'package:alcohol_neon/core/problem.dart';
import 'package:alcohol_neon/data/subscription_repository.dart';
import 'package:alcohol_neon/features/subscription/subscription_controller.dart';
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:alcohol_neon/services/storefront_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// SubscriptionController behaviour: variant mapping (unknown -> neutral),
/// storefront passthrough, and the openPortal guard rails (https-only, errors
/// surface as Problems, browser never launched on a bad link).
class _FakeStorefront implements StorefrontService {
  final StorefrontInfo info;
  _FakeStorefront(this.info);

  @override
  Future<StorefrontInfo> resolve() async => info;
}

void main() {
  SubscriptionRepository repo(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return SubscriptionRepository(
      ApiClient(
        baseUrl: Uri.parse('https://zinc.test'),
        tokenProvider: () async => 'token',
        client: MockClient(handler),
      ),
    );
  }

  SubscriptionController controller(
    SubscriptionRepository repository, {
    StorefrontInfo? storefront,
    Future<bool> Function(Uri)? launcher,
  }) {
    return SubscriptionController(
      repository: repository,
      storefront: _FakeStorefront(
        storefront ?? const StorefrontInfo(platform: 'ios', countryCode: 'US'),
      ),
      userId: 'user-1',
      launcher: launcher ?? (_) async => true,
    );
  }

  test('load passes platform + storefront and maps the variant', () async {
    Uri? seen;
    final c = controller(
      repo((req) async {
        seen = req.url;
        return http.Response(
          jsonEncode({'variant': 'subscribe', 'tier': 'free'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await c.load();

    expect(seen!.path, '/api/v1.0/Subscription/user-1/cta');
    expect(seen!.queryParameters['platform'], 'ios');
    expect(seen!.queryParameters['storefront'], 'US');
    expect(c.loading, isFalse);
    expect(c.variant, SubscriptionCtaVariant.subscribe);
    expect(c.tier, 'free');
  });

  test('load omits an unknown storefront from the query', () async {
    Uri? seen;
    final c = controller(
      repo((req) async {
        seen = req.url;
        return http.Response(
          jsonEncode({'variant': 'neutral', 'tier': 'free'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      storefront: const StorefrontInfo(platform: 'android'),
    );

    await c.load();

    expect(seen!.queryParameters.containsKey('storefront'), isFalse);
    expect(c.variant, SubscriptionCtaVariant.neutral);
  });

  test('unknown server variant maps to neutral (never steer)', () async {
    final c = controller(
      repo(
        (req) async => http.Response(
          jsonEncode({'variant': 'upsell-v2', 'tier': 'free'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await c.load();

    expect(c.variant, SubscriptionCtaVariant.neutral);
  });

  test('load failure surfaces the Problem', () async {
    final c = controller(repo((req) async => http.Response('boom', 500)));

    await c.load();

    expect(c.loading, isFalse);
    expect(c.error, isA<Problem>());
  });

  test('openPortal launches the https magic link externally', () async {
    final launched = <Uri>[];
    final c = controller(
      repo((req) async {
        expect(req.url.path, '/api/v1.0/Auth/web-handoff');
        final body = jsonDecode(req.body) as Map<String, Object?>;
        expect(body['platform'], 'ios');
        expect(body['storefront'], 'US');
        return http.Response(
          jsonEncode({
            'url': 'https://portal.test/auth/handoff?one_time_token=abc',
            'expiresInSeconds': 300,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await c.openPortal();

    expect(launched, hasLength(1));
    expect(launched.single.scheme, 'https');
    expect(c.openError, isNull);
    expect(c.opening, isFalse);
  });

  test('openPortal refuses a non-https url and never launches', () async {
    final launched = <Uri>[];
    final c = controller(
      repo(
        (req) async => http.Response(
          jsonEncode({'url': 'javascript:alert(1)', 'expiresInSeconds': 300}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await c.openPortal();

    expect(launched, isEmpty);
    expect(c.openError, isA<Problem>());
  });

  test('openPortal surfaces a 403 handoff-not-available Problem', () async {
    final c = controller(
      repo(
        (req) async => http.Response(
          jsonEncode({
            'title': 'Handoff Not Available',
            'status': 403,
            'type': 'handoff_not_available',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await c.openPortal();

    expect(c.openError, isA<Problem>());
    expect(c.openError!.status, 403);
  });

  test('openPortal reports a launcher failure', () async {
    final c = controller(
      repo(
        (req) async => http.Response(
          jsonEncode({
            'url': 'https://portal.test/auth/handoff?one_time_token=abc',
            'expiresInSeconds': 300,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      launcher: (_) async => false,
    );

    await c.openPortal();

    expect(c.openError, isA<Problem>());
  });
}
