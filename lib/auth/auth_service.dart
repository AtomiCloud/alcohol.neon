import 'package:flutter/foundation.dart';
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

  AuthService(this.config) {
    _client = LogtoClient(
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
      _lastError = Problem.local(
        'Sign-in failed',
        detail: e.toString(),
        type: 'neon:auth',
      );
      _status = AuthStatus.failed;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    // Flip local state first so the shell swap (and the navigator pop it
    // triggers) never stalls behind the network — the Logto revocation is
    // best-effort cleanup and may hang on a dead connection.
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    try {
      await _client.signOut(config.redirectUri);
    } catch (_) {
      // Best-effort; we're already signed out locally.
    }
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
