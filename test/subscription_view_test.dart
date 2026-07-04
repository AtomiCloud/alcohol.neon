import 'dart:convert';

import 'package:alcohol_neon/data/subscription_repository.dart';
import 'package:alcohol_neon/features/subscription/subscription_controller.dart';
import 'package:alcohol_neon/features/subscription/subscription_view.dart';
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:alcohol_neon/services/storefront_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The compliance-critical render rule: a neutral CTA shows plan info ONLY —
/// no action button and no steering / price-comparison copy (in-app "cheaper
/// on the web" text is a violation in restricted storefronts).
class _FakeStorefront implements StorefrontService {
  @override
  Future<StorefrontInfo> resolve() async =>
      const StorefrontInfo(platform: 'ios', countryCode: 'SG');
}

SubscriptionController _controller(String variant, String tier) {
  final repo = SubscriptionRepository(
    ApiClient(
      baseUrl: Uri.parse('https://zinc.test'),
      tokenProvider: () async => 'token',
      client: MockClient(
        (req) async => http.Response(
          jsonEncode({'variant': variant, 'tier': tier}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ),
  );
  return SubscriptionController(
    repository: repo,
    storefront: _FakeStorefront(),
    userId: 'user-1',
    launcher: (_) async => true,
  );
}

Future<void> _pump(WidgetTester tester, SubscriptionController c) async {
  await c.load();
  await tester.pumpWidget(MaterialApp(home: SubscriptionView(controller: c)));
  await tester.pump();
}

void main() {
  testWidgets('neutral renders no button and no steering copy', (tester) async {
    final c = _controller('neutral', 'free');
    await _pump(tester, c);

    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    // No steering or price-comparison language anywhere on screen.
    for (final banned in ['subscribe', 'web', 'browser', 'cheap', 'price']) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.toLowerCase().contains(banned) ?? false),
        ),
        findsNothing,
        reason: 'neutral screen must not mention "$banned"',
      );
    }
    // Plan info is still shown.
    expect(find.text('Free plan'), findsOneWidget);
    c.dispose();
  });

  testWidgets('manage renders the portal button', (tester) async {
    final c = _controller('manage', 'pro');
    await _pump(tester, c);

    expect(find.text('Manage subscription'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    c.dispose();
  });

  testWidgets('subscribe renders the web subscribe button', (tester) async {
    final c = _controller('subscribe', 'free');
    await _pump(tester, c);

    expect(find.text('Subscribe on the web'), findsOneWidget);
    c.dispose();
  });

  testWidgets('unknown variant renders like neutral', (tester) async {
    final c = _controller('upsell-v2', 'free');
    await _pump(tester, c);

    expect(find.byType(FilledButton), findsNothing);
    c.dispose();
  });
}
