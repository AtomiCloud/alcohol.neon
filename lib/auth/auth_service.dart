import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:logto_dart_sdk/logto_dart_sdk.dart';

import '../config/app_config.dart';
import '../core/problem.dart';
import '../networking/api_client.dart';

enum AuthStatus { loading, authenticated, unauthenticated, failed }

/// App-owned view of the signed-in user's claims (keeps the SDK type out of views).
class UserClaims {
  final String? sub;
  final String? name;
  final String? email;
  const UserClaims({this.sub, this.name, this.email});
}

/// Wraps the Logto Dart SDK. The SDK persists/refreshes tokens (flutter_secure_storage)
/// and signs in via flutter_web_auth_2 (ASWebAuthenticationSession on iOS / Custom Tabs
/// on Android), so we don't manage storage or presentation.
class AuthService extends ChangeNotifier {
  final AppConfig config;
  late final LogtoClient _client;

  AuthStatus _status = AuthStatus.loading;
  Problem? _lastError;

  AuthStatus get status => _status;
  Problem? get lastError => _lastError;

  /// [client] lets tests inject a fake SDK client; production uses the real one.
  AuthService(this.config, {LogtoClient? client}) {
    _client =
        client ??
        LogtoClient(
          config: LogtoConfig(
            endpoint: config.logtoEndpoint,
            appId: config.logtoAppId,
            scopes: config.scopes,
            resources: config.apiResources,
          ),
          httpClient: http.Client(),
        );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _status = (await _client.isAuthenticated)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> signIn() async {
    try {
      await _client.signIn(config.redirectUri);
      _status = (await _client.isAuthenticated)
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } catch (e) {
      if (isAlreadySigningIn(e)) {
        // A second tap while the login sheet is already up — the first
        // attempt is still in flight and owns the state; change nothing.
        return;
      }
      if (isUserCancellation(e)) {
        // The user closed the login sheet — benign, not a failure.
        _lastError = null;
        _status = AuthStatus.unauthenticated;
      } else {
        _lastError = Problem.local(
          'Sign-in failed',
          detail: e.toString(),
          type: 'neon:auth',
        );
        _status = AuthStatus.failed;
      }
    }
    notifyListeners();
  }

  /// Whether [e] is the user dismissing the system login sheet
  /// (ASWebAuthenticationSession on iOS / Custom Tab on Android).
  /// flutter_web_auth_2 surfaces that as `PlatformException(code: 'CANCELED')`
  /// and logto_dart_sdk rethrows it unwrapped (its `signIn` only has a
  /// `finally`), so this is exactly what reaches us. `USER_CANCELED` covers
  /// flutter_web_auth_2 variants that renamed the code.
  @visibleForTesting
  static bool isUserCancellation(Object e) =>
      e is PlatformException &&
      (e.code == 'CANCELED' || e.code == 'USER_CANCELED');

  /// Whether [e] is the SDK refusing a second `signIn` while one is already
  /// in flight (logto_dart_sdk `signIn` throws `isLoadingError` while
  /// `_loading` — logto_client.dart:202-205). The in-flight attempt owns the
  /// state, so the caller should change nothing.
  @visibleForTesting
  static bool isAlreadySigningIn(Object e) =>
      e is LogtoAuthException && e.code == LogtoAuthExceptions.isLoadingError;

  Future<void> signOut() async {
    try {
      await _client.signOut(config.redirectUri);
    } catch (_) {
      // Best-effort; we sign out locally regardless.
    }
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// ID-token claims (available offline once signed in).
  Future<UserClaims?> claims() async {
    final c = await _client.idTokenClaims;
    if (c == null) return null;
    return UserClaims(sub: c.subject, name: c.name, email: c.email);
  }

  /// The raw OIDC id_token (JWT). Sent to `POST /User` so zinc can provision the
  /// user from Logto on first sign-in. Null if unauthenticated.
  Future<String?> idToken() => _client.idToken;

  /// A zinc-scoped access token for the Bearer header. Null if unauthenticated or no
  /// resource is configured.
  Future<String?> zincAccessToken() async {
    if (config.zincResource.isEmpty) return null;
    if (!await _client.isAuthenticated) return null;
    final token = await _client.getAccessToken(resource: config.zincResource);
    return token?.token;
  }

  /// An ApiClient pre-wired with this user's token provider.
  ApiClient makeApiClient() =>
      ApiClient(baseUrl: config.zincBaseUrl, tokenProvider: zincAccessToken);
}
