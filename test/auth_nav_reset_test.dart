// Regression tests for the session-end navigator reset. RootView swaps its
// child when auth status leaves `authenticated`, but that swap happens
// underneath any routes pushed on the root navigator (profile, editors, …) —
// the app must pop back to the first route so the signed-out shell is visible.
import 'dart:convert';

import 'package:airwallex_payment_flutter/types/environment.dart';
import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/config/app_config.dart';
import 'package:alcohol_neon/config/landscape.dart';
import 'package:alcohol_neon/features/auth/sign_in_view.dart';
import 'package:alcohol_neon/features/profile/profile_view.dart';
import 'package:alcohol_neon/main.dart' show AlcoholNeonApp;
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logto_dart_sdk/logto_dart_sdk.dart';
import 'package:provider/provider.dart';

final _config = AppConfig(
  landscape: Landscape.pichu,
  zincBaseUrl: Uri.parse('https://zinc.test'),
  logtoEndpoint: 'https://logto.test',
  logtoAppId: 'app',
  zincResource: '',
  airwallexEnv: Environment.demo,
  nfcTagBaseUrl: Uri.parse('https://t.lazytax.club/t/'),
);

/// Inert Logto client so AuthService never constructs the real SDK client
/// (whose bootstrap reads flutter_secure_storage over a platform channel).
class _InertLogtoClient extends LogtoClient {
  _InertLogtoClient()
    : super(
        config: LogtoConfig(
          endpoint: _config.logtoEndpoint,
          appId: _config.logtoAppId,
        ),
        httpClient: http.Client(),
      );

  @override
  Future<bool> get isAuthenticated async => false;
}

/// AuthService whose status is driven by the test; the injected inert client
/// keeps the SDK (and its platform channels) out of the picture entirely.
class _FakeAuthService extends AuthService {
  _FakeAuthService({http.Client? zincClient})
    : _zincClient = zincClient,
      super(_config, client: _InertLogtoClient());

  final http.Client? _zincClient;
  AuthStatus _testStatus = AuthStatus.authenticated;

  @override
  AuthStatus get status => _testStatus;

  void setStatus(AuthStatus status) {
    _testStatus = status;
    notifyListeners();
  }

  @override
  Future<void> signOut() async => setStatus(AuthStatus.unauthenticated);

  @override
  Future<UserClaims?> claims() async => const UserClaims(
    sub: 'user-1',
    name: 'Testy',
    email: 'testy@example.com',
  );

  @override
  ApiClient makeApiClient() => ApiClient(
    baseUrl: _config.zincBaseUrl,
    tokenProvider: () async => 'token',
    client: _zincClient ?? MockClient((_) async => http.Response('', 404)),
  );
}

/// Mirrors main()'s provider wiring around [AlcoholNeonApp].
Future<void> _pumpApp(WidgetTester tester, _FakeAuthService auth) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProxyProvider<AuthService, SessionController>(
          create: (ctx) => SessionController(ctx.read<AuthService>()),
          update: (ctx, a, previous) => previous ?? SessionController(a),
        ),
      ],
      child: const AlcoholNeonApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pushPlaceholder(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(
    MaterialPageRoute(
      builder: (_) => const Scaffold(body: Text('Pushed screen')),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Pushed screen'), findsOneWidget);
}

void main() {
  testWidgets('sign-out pops pushed routes so SignInView is visible', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await _pumpApp(tester, auth);
    await _pushPlaceholder(tester);

    await auth.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Pushed screen'), findsNothing);
    expect(find.byType(SignInView), findsOneWidget);
  });

  testWidgets('auth failure also pops pushed routes back to the shell', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await _pumpApp(tester, auth);
    await _pushPlaceholder(tester);

    auth.setStatus(AuthStatus.failed);
    await tester.pumpAndSettle();

    expect(find.text('Pushed screen'), findsNothing);
    // RootView's failed branch (_AuthFailedView) with its retry affordance.
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('successful delete lands on SignInView with confirmation', (
    tester,
  ) async {
    final client = MockClient((req) async {
      if (req.method == 'GET' && req.url.path == '/api/v1.0/User/Me/All') {
        return http.Response(
          jsonEncode({
            'principal': {
              'id': 'user-1',
              'username': 'testy',
              'email': 'testy@example.com',
              'emailVerified': true,
              'active': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.method == 'DELETE' && req.url.path == '/api/v1.0/User/Me') {
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    final auth = _FakeAuthService(zincClient: client);
    await _pumpApp(tester, auth);

    // Push Profile on the root navigator, as the dashboard's person icon does.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute(builder: (_) => const ProfileView()));
    await tester.pumpAndSettle();

    final deleteButton = find.widgetWithText(OutlinedButton, 'Delete account');
    await tester.scrollUntilVisible(
      deleteButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Confirm in the irreversible-delete dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileView), findsNothing);
    expect(find.byType(SignInView), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });
}
