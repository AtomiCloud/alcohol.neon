import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../core/problem.dart';
import '../data/cause_repository.dart';
import '../data/charity_repository.dart';
import '../data/config_repository.dart';
import '../data/execution_repository.dart';
import '../data/habit_repository.dart';
import '../data/payment_repository.dart';
import '../data/protection_repository.dart';
import '../data/user_repository.dart';
import '../data/vacation_repository.dart';
import '../generated/zinc/models/configuration_principal_res.dart';
import '../generated/zinc/models/payment_consent_res.dart';
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
  final CauseRepository causes;
  final HabitRepository habits;
  final ExecutionRepository executions;
  final PaymentRepository payments;
  final ProtectionRepository protections;
  final VacationRepository vacations;

  SessionController(AuthService auth) : this._(auth, auth.makeApiClient());

  SessionController._(this.auth, ApiClient api)
      : users = UserRepository(api),
        configs = ConfigRepository(api),
        charities = CharityRepository(api),
        causes = CauseRepository(api),
        habits = HabitRepository(api),
        executions = ExecutionRepository(api),
        payments = PaymentRepository(api),
        protections = ProtectionRepository(api),
        vacations = VacationRepository(api);

  SessionPhase _phase = SessionPhase.idle;
  Problem? _error;
  String? _userId;
  ConfigurationPrincipalRes? _config;
  PaymentConsentRes? _consent;

  SessionPhase get phase => _phase;
  Problem? get error => _error;

  /// zinc user id (== Logto `sub`). Cached for the `/{userId}/…` endpoints in later
  /// milestones (habits, payments).
  String? get userId => _userId;
  ConfigurationPrincipalRes? get config => _config;

  /// The user's cached payment consent (`GET /Payment/{userId}/consent`), loaded
  /// during bootstrap and refreshed via [refreshConsent]. `null` until first loaded
  /// (or if the load failed).
  PaymentConsentRes? get consent => _consent;

  /// Whether the user currently has an active payment consent on file. This is the
  /// single source of truth for gating staked habits — derived from the zinc
  /// `/consent` GET, **never** the Logto JWT claim (which can be stale).
  bool get hasPaymentConsent => _consent?.hasPaymentConsent ?? false;

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

    // Ensure the zinc user exists. We check with GET /User/Me/All first rather than
    // blindly POSTing: POST /User is create-only (INSERT on the JWT sub) and throws a
    // server-side UniqueConstraintException + error log on every returning sign-in.
    // So: 200 ⇒ already provisioned; 404 ⇒ first sign-in, create now.
    final me = await users.me();
    if (me case Err(:final problem)) {
      if (problem.status == 404) {
        final created =
            await users.create(idToken: idToken, accessToken: accessToken);
        // Tolerate a 409 in case of a concurrent first-sign-in race.
        if (created case Err(problem: final p)
            when p.status != 409 && !p.title.toLowerCase().contains('conflict')) {
          return _fail(p);
        }
      } else {
        return _fail(problem);
      }
    }

    final cfg = await configs.mine();
    switch (cfg) {
      case Ok(:final value):
        _config = value.principal;
        // Load payment consent up front so the habit editor can gate staked
        // habits synchronously (off `hasPaymentConsent`). Best-effort: a failure
        // here leaves consent unknown but must not block reaching the app — the
        // editor falls back to running the consent flow on demand.
        await _loadConsent();
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

  /// Best-effort load of the payment consent into the cache (no notify; the caller
  /// flips the phase). Tolerates failure — leaves the previous cache intact.
  Future<void> _loadConsent() async {
    final uid = _userId;
    if (uid == null) return;
    final res = await payments.consent(uid);
    if (res case Ok(:final value)) _consent = value;
  }

  /// Re-reads `GET /Payment/{userId}/consent` and refreshes the cached consent so
  /// dependent screens (habit editor gate, settings consent card) reflect a newly
  /// set-up or revoked payment method. Returns the result so the caller can surface
  /// a failure; on success it notifies listeners. Leaves the cache intact when the
  /// refresh fails. Truth is always this GET, never the Logto claim.
  Future<Result<PaymentConsentRes>> refreshConsent() async {
    final uid = _userId;
    if (uid == null) return const Err(Problem.unauthenticated);
    final res = await payments.consent(uid);
    switch (res) {
      case Ok(:final value):
        _consent = value;
        notifyListeners();
        return Ok(value);
      case Err(:final problem):
        return Err(problem);
    }
  }

  /// Called by onboarding once `POST /Configuration` succeeds.
  void onConfigured(ConfigurationPrincipalRes config) {
    _config = config;
    _setPhase(SessionPhase.ready);
  }

  /// Re-reads `GET /Configuration/me` and refreshes the cached principal so
  /// dependent screens (dashboard / habit defaults) see a new timezone or default
  /// charity after the settings screen saves. Returns the result so the caller can
  /// surface a failure; on success it notifies listeners. Leaves the cache intact
  /// (and does not flip the phase) when the refresh fails.
  Future<Result<ConfigurationPrincipalRes>> refreshConfig() async {
    final res = await configs.mine();
    switch (res) {
      case Ok(:final value):
        _config = value.principal;
        notifyListeners();
        return Ok(value.principal);
      case Err(:final problem):
        return Err(problem);
    }
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
