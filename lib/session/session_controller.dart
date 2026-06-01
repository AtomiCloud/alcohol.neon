import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../core/problem.dart';
import '../data/charity_repository.dart';
import '../data/config_repository.dart';
import '../data/user_repository.dart';
import '../generated/zinc/models/configuration_principal_res.dart';
import '../networking/api_client.dart';

/// Where the signed-in user is in the bootstrap → configured journey.
enum SessionPhase { idle, bootstrapping, needsOnboarding, ready, error }

/// Runs the post-sign-in bootstrap (plan §6A): provision the zinc user, then load
/// configuration — routing to onboarding when absent. Owns the zinc repositories so
/// features share one [ApiClient]. Provided after [AuthService] (see main.dart).
class SessionController extends ChangeNotifier {
  final AuthService auth;
  final UserRepository users;
  final ConfigRepository configs;
  final CharityRepository charities;

  SessionController(AuthService auth) : this._(auth, auth.makeApiClient());

  SessionController._(this.auth, ApiClient api)
      : users = UserRepository(api),
        configs = ConfigRepository(api),
        charities = CharityRepository(api);

  SessionPhase _phase = SessionPhase.idle;
  Problem? _error;
  String? _userId;
  ConfigurationPrincipalRes? _config;

  SessionPhase get phase => _phase;
  Problem? get error => _error;

  /// zinc user id (== Logto `sub`). Cached for the `/{userId}/…` endpoints in later
  /// milestones (habits, payments).
  String? get userId => _userId;
  ConfigurationPrincipalRes? get config => _config;

  /// Provision the user (idempotent) then resolve configuration. Safe to re-run
  /// (e.g. on retry, or re-entering the authed shell after a previous sign-in).
  Future<void> bootstrap() async {
    _error = null;
    _setPhase(SessionPhase.bootstrapping);

    final claims = await auth.claims();
    _userId = claims?.sub;

    // Fetch the access token first: if it's expired the SDK refreshes via the
    // refresh token, which also re-stores a fresh id_token. Reading idToken after
    // that means a mid-session expiry self-heals instead of sending a stale token
    // to POST /User (zinc validates the id_token's lifetime).
    final accessToken = await auth.zincAccessToken();
    final idToken = await auth.idToken();
    if (idToken == null || accessToken == null) {
      return _fail(Problem.local('Could not read sign-in tokens',
          type: 'neon:auth',
          detail: 'No id/access token available after sign-in. Try signing in again.'));
    }

    final created = await users.create(idToken: idToken, accessToken: accessToken);
    if (created case Err(:final problem)) return _fail(problem);

    final cfg = await configs.mine();
    switch (cfg) {
      case Ok(:final value):
        _config = value.principal;
        _setPhase(SessionPhase.ready);
      case Err(:final problem):
        // 404 ⇒ no configuration yet ⇒ onboard. Anything else is a real error.
        if (problem.status == 404) {
          _setPhase(SessionPhase.needsOnboarding);
        } else {
          _fail(problem);
        }
    }
  }

  /// Called by onboarding once `POST /Configuration` succeeds.
  void onConfigured(ConfigurationPrincipalRes config) {
    _config = config;
    _setPhase(SessionPhase.ready);
  }

  void _fail(Problem problem) {
    _error = problem;
    _setPhase(SessionPhase.error);
  }

  void _setPhase(SessionPhase phase) {
    _phase = phase;
    notifyListeners();
  }
}
