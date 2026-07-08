// AuthService.signIn error classification: a dismissed login sheet
// (PlatformException CANCELED from flutter_web_auth_2, rethrown unwrapped by
// logto_dart_sdk) is benign; anything else is a real failure.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airwallex_payment_flutter/types/environment.dart';
import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/config/app_config.dart';
import 'package:alcohol_neon/config/landscape.dart';
import 'package:logto_dart_sdk/logto_dart_sdk.dart';

/// What flutter_web_auth_2 throws when the user closes the system login sheet
/// (ASWebAuthenticationSession on iOS / Custom Tab on Android).
final _cancel = PlatformException(
  code: 'CANCELED',
  message: 'User canceled login',
);

/// Stands in for the real Logto SDK client: [signIn] throws [signInError] if
/// set (else "succeeds"), blocks on [signInGate] when set, and — like the real
/// SDK — throws `isLoadingError` on a re-entrant call. No method touches
/// platform channels.
class _FakeLogtoClient extends LogtoClient {
  _FakeLogtoClient({required super.config, this.signInError});

  Object? signInError;
  Completer<void>? signInGate;
  bool _authed = false;
  bool _signingIn = false;

  @override
  Future<bool> get isAuthenticated async => _authed;

  @override
  Future<void> signIn(
    String redirectUri, {
    InteractionMode? interactionMode,
    String? loginHint,
    String? directSignIn,
    FirstScreen? firstScreen,
    List<IdentifierType>? identifiers,
    Map<String, String>? extraParams,
  }) async {
    if (_signingIn) {
      // Mirrors logto_client.dart:202-205.
      throw LogtoAuthException(
        LogtoAuthExceptions.isLoadingError,
        'Already signing in...',
      );
    }
    final error = signInError;
    if (error != null) throw error;
    _signingIn = true;
    try {
      final gate = signInGate;
      if (gate != null) await gate.future;
      _authed = true;
    } finally {
      _signingIn = false;
    }
  }
}

void main() {
  final config = AppConfig(
    landscape: Landscape.lapras,
    zincBaseUrl: Uri.parse('https://zinc.example.com'),
    logtoEndpoint: 'https://logto.example.com',
    logtoAppId: 'test-app-id',
    zincResource: '',
    airwallexEnv: Environment.demo,
  );

  _FakeLogtoClient makeClient({Object? signInError}) => _FakeLogtoClient(
    config: LogtoConfig(
      endpoint: config.logtoEndpoint,
      appId: config.logtoAppId,
    ),
    signInError: signInError,
  );

  test(
    'cancelling the login sheet is benign: unauthenticated, no error',
    () async {
      final auth = AuthService(
        config,
        client: makeClient(signInError: _cancel),
      );
      await auth.signIn();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.lastError, isNull);
    },
  );

  test('a real exception still fails with a Problem', () async {
    final auth = AuthService(
      config,
      client: makeClient(
        signInError: LogtoAuthException(
          LogtoAuthExceptions.callbackUriValidationError,
          'invalid redirect uri',
        ),
      ),
    );
    await auth.signIn();
    expect(auth.status, AuthStatus.failed);
    expect(auth.lastError, isNotNull);
    expect(auth.lastError!.title, 'Sign-in failed');
  });

  test(
    'cancelling clears the error left by an earlier failed attempt',
    () async {
      final client = makeClient(signInError: Exception('boom'));
      final auth = AuthService(config, client: client);
      await auth.signIn();
      expect(auth.status, AuthStatus.failed);
      expect(auth.lastError, isNotNull);

      client.signInError = _cancel;
      await auth.signIn();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.lastError, isNull);
    },
  );

  test('a double-tap while a sign-in is in flight changes nothing', () async {
    final client = makeClient()..signInGate = Completer<void>();
    final auth = AuthService(config, client: client);
    await pumpEventQueue(); // let _bootstrap settle on unauthenticated

    final first = auth.signIn(); // in flight, blocked on the gate
    final before = auth.status;
    var notified = 0;
    auth.addListener(() => notified++);

    await auth.signIn(); // second tap → SDK throws isLoadingError
    expect(auth.status, before); // no flicker, and…
    expect(auth.status, isNot(AuthStatus.failed)); // …no full-screen error
    expect(auth.lastError, isNull);
    expect(notified, 0); // early return doesn't notify

    client.signInGate!.complete(); // first attempt finishes normally
    await first;
    expect(auth.status, AuthStatus.authenticated);
  });

  test('successful sign-in authenticates', () async {
    final auth = AuthService(config, client: makeClient());
    await auth.signIn();
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.lastError, isNull);
  });

  test('isUserCancellation only matches cancel PlatformExceptions', () {
    expect(AuthService.isUserCancellation(_cancel), isTrue);
    expect(
      AuthService.isUserCancellation(PlatformException(code: 'USER_CANCELED')),
      isTrue,
    );
    expect(
      AuthService.isUserCancellation(PlatformException(code: 'OTHER')),
      isFalse,
    );
    expect(AuthService.isUserCancellation(Exception('boom')), isFalse);
  });

  test('isAlreadySigningIn only matches the SDK isLoadingError', () {
    expect(
      AuthService.isAlreadySigningIn(
        LogtoAuthException(
          LogtoAuthExceptions.isLoadingError,
          'Already signing in...',
        ),
      ),
      isTrue,
    );
    expect(
      AuthService.isAlreadySigningIn(
        LogtoAuthException(LogtoAuthExceptions.authenticationError, 'nope'),
      ),
      isFalse,
    );
    expect(AuthService.isAlreadySigningIn(_cancel), isFalse);
  });
}
