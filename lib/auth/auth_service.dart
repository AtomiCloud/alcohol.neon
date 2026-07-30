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
    try {
      _status = (await _client.isAuthenticated)
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } on LogtoAuthException {
      // A dead stored session must never strand the app on the splash. The iOS
      // Keychain outlives an uninstall, so a revoked/expired refresh token can
      // greet a fresh install here (Logto answers the refresh with 400 and the
      // SDK throws). Publish signed-out FIRST — the token cleanup below hits
      // the network and must never hold up the UI (same ordering as signOut).
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      try {
        await _client.signOut(config.redirectUri);
      } catch (_) {
        // Best-effort: revoking an already-dead session may itself fail.
      }
      return;
    } catch (e) {
      // Unexpected failure (offline launch, decoding, …): the stored session
      // may be perfectly valid, so keep it and surface a retryable failure
      // instead of wiping the Keychain.
      _lastError = Problem.local(
        'Could not restore your session',
        detail: e.toString(),
        type: 'neon:auth',
      );
      _status = AuthStatus.failed;
    }
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
  /// Gated on local [_status]: signOut() flips it before the (best-effort)
  /// revocation, and no caller may keep minting tokens once we're signed out.
  Future<String?> idToken() async {
    if (_status != AuthStatus.authenticated) return null;
    return _client.idToken;
  }

  /// A zinc-scoped access token for the Bearer header. Null if unauthenticated or no
  /// resource is configured. Gated on local [_status] like [idToken].
  ///
  /// This is where a dead stored session actually surfaces: `isAuthenticated`
  /// is a pure storage check (a stale id_token still counts), so the first
  /// hard proof is the SDK's refresh attempt here — Logto answers 400 and
  /// `getAccessToken` throws. Unhandled, that throw killed the session
  /// bootstrap mid-flight and froze the app on the loader.
  Future<String?> zincAccessToken() async {
    if (_status != AuthStatus.authenticated) return null;
    if (config.zincResource.isEmpty) return null;
    try {
      if (!await _client.isAuthenticated) return null;
      final token = await _client.getAccessToken(resource: config.zincResource);
      return token?.token;
    } catch (e) {
      if (_isDeadSessionError(e)) {
        // The session is dead (revoked/expired grant). Flip to signed-out
        // FIRST (UI must never wait on network cleanup), then clear the stale
        // keychain tokens best-effort. RootView swaps to SignInView on the
        // notify, so the user lands on sign-in instead of a frozen loader.
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        try {
          await _client.signOut(config.redirectUri);
        } catch (_) {
          // Best-effort: revoking an already-dead session may itself fail.
        }
        return null;
      }
      // Transient failure (offline, 5xx, …): keep the session, let the caller
      // surface a retryable error.
      return null;
    }
  }

  /// Whether [e] proves the stored session is dead (vs a transient failure).
  ///
  /// Two shapes, both from the SDK's refresh path: `LogtoAuthException` with
  /// `authenticationError` (refresh token missing), and the SDK's
  /// `HttpRequestException` carrying the token endpoint's 400/401
  /// (invalid_grant — revoked or expired). The latter type isn't exported by
  /// logto_dart_sdk, so it's matched structurally instead of by import.
  static bool _isDeadSessionError(Object e) {
    if (e is LogtoAuthException) {
      return e.code == LogtoAuthExceptions.authenticationError;
    }
    if (e.runtimeType.toString() == 'HttpRequestException') {
      try {
        final status = (e as dynamic).statusCode as int;
        return status == 400 || status == 401;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// An ApiClient pre-wired with this user's token provider.
  ApiClient makeApiClient() =>
      ApiClient(baseUrl: config.zincBaseUrl, tokenProvider: zincAccessToken);
}
